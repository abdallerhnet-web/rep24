// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRepVaultJM {
    function getStakeBalance(address agentAddress) external view returns (uint256);
    function slash(address agentAddress, address proposer, uint256 slashPercent) external;
}

interface IRepScoreJM {
    function reportJobOutcome(address agentWallet, bool success) external;
}

/// @title JobManager
/// @notice USDC escrow for agent jobs with optimistic auto-finalize.
///
/// Flow:
///   client createJob  -> provider submitResult -> (dispute window) -> anyone finalize
///   If the client disputes inside the window, the owner resolves it.
///   If the provider never submits, anyone can expire the job and the client is refunded.
///
/// Required roles (granted by the RepScore / RepVault admin after deploy):
///   RepScore.RELAYER_ROLE  -> this contract   (reportJobOutcome)
///   RepVault.ADMIN_ROLE    -> this contract   (slash on a lost dispute)
contract JobManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status { Open, Submitted, Completed, Failed, Disputed, Expired }

    struct Job {
        address client;
        address provider;
        bytes32 referenceId;
        uint256 escrowAmount;
        Status status;
        uint256 createdAt;
        bytes32 resultHash;
        uint256 finalizeAfter; // set on submit: when finalize() becomes callable
        uint256 submitBy;      // provider must submit before this
    }

    // ---- anti-farming limits ----
    uint256 public constant MIN_ESCROW = 5 * 1e6;          // 5 USDC
    uint256 public constant MAX_SCORED_PER_PAIR_PER_DAY = 3;
    uint256 public constant SLASH_PERCENT = 10;            // of provider stake, on a lost dispute
    uint256 public constant SUBMIT_WINDOW = 7 days;
    uint256 public constant MIN_DISPUTE_WINDOW = 10 minutes;
    uint256 public constant MAX_DISPUTE_WINDOW = 7 days;

    IERC20 public immutable usdc;
    IRepVaultJM public immutable vault;
    IRepScoreJM public immutable score;

    uint256 public disputeWindow;
    uint256 public jobCounter; // job ids start at 1

    mapping(uint256 => Job) public jobs;
    mapping(bytes32 => uint8) public scoredToday; // keccak(client, provider, day) => count

    event JobCreated(uint256 indexed jobId, address indexed client, address indexed provider, bytes32 referenceId, uint256 escrowAmount);
    event ResultSubmitted(uint256 indexed jobId, bytes32 resultHash, uint256 finalizeAfter);
    event JobDisputed(uint256 indexed jobId);
    event JobSettled(uint256 indexed jobId, Status status);
    event NotScored(uint256 indexed jobId); // pair daily cap reached, paid but no rep
    event ReputationCallFailed(uint256 indexed jobId); // escrow still settled; check roles
    event DisputeWindowChanged(uint256 newWindow);

    constructor(address _usdc, address _vault, address _score, address _owner, uint256 _disputeWindow)
        Ownable(_owner)
    {
        require(_usdc != address(0) && _vault != address(0) && _score != address(0), "JobManager: zero address");
        require(
            _disputeWindow >= MIN_DISPUTE_WINDOW && _disputeWindow <= MAX_DISPUTE_WINDOW,
            "JobManager: bad window"
        );
        usdc = IERC20(_usdc);
        vault = IRepVaultJM(_vault);
        score = IRepScoreJM(_score);
        disputeWindow = _disputeWindow;
    }

    // ------------------------------------------------------------------ client

    function createJob(address provider, bytes32 referenceId, uint256 escrowAmount)
        external nonReentrant returns (uint256 jobId)
    {
        require(provider != address(0), "JobManager: zero provider");
        require(provider != msg.sender, "JobManager: self-dealing");
        require(escrowAmount >= MIN_ESCROW, "JobManager: escrow below minimum");
        require(vault.getStakeBalance(provider) > 0, "JobManager: provider not staked");

        jobId = ++jobCounter;
        jobs[jobId] = Job({
            client: msg.sender,
            provider: provider,
            referenceId: referenceId,
            escrowAmount: escrowAmount,
            status: Status.Open,
            createdAt: block.timestamp,
            resultHash: bytes32(0),
            finalizeAfter: 0,
            submitBy: block.timestamp + SUBMIT_WINDOW
        });

        usdc.safeTransferFrom(msg.sender, address(this), escrowAmount);
        emit JobCreated(jobId, msg.sender, provider, referenceId, escrowAmount);
    }

    /// @notice Client accepts the result early (skips the wait).
    function approve(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client, "JobManager: not client");
        require(j.status == Status.Submitted, "JobManager: not submitted");
        _settleSuccess(jobId, j);
    }

    /// @notice Client disputes a submitted result inside the window.
    function dispute(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client, "JobManager: not client");
        require(j.status == Status.Submitted, "JobManager: not submitted");
        require(block.timestamp < j.finalizeAfter, "JobManager: window closed");
        j.status = Status.Disputed;
        emit JobDisputed(jobId);
    }

    // ---------------------------------------------------------------- provider

    function submitResult(uint256 jobId, bytes32 resultHash) external {
        Job storage j = jobs[jobId];
        require(msg.sender == j.provider, "JobManager: not provider");
        require(j.status == Status.Open, "JobManager: not open");
        require(block.timestamp <= j.submitBy, "JobManager: submit window over");
        j.status = Status.Submitted;
        j.resultHash = resultHash;
        j.finalizeAfter = block.timestamp + disputeWindow;
        emit ResultSubmitted(jobId, resultHash, j.finalizeAfter);
    }

    // ------------------------------------------------------------ anyone (bot)

    /// @notice Permissionless: completes an undisputed job once the window has passed.
    function finalize(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(j.status == Status.Submitted, "JobManager: not submitted");
        require(block.timestamp >= j.finalizeAfter, "JobManager: window open");
        _settleSuccess(jobId, j);
    }

    /// @notice Permissionless: refunds the client if the provider never submitted.
    /// No reputation penalty, so nobody can grief a provider by spamming jobs.
    function expire(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(j.status == Status.Open, "JobManager: not open");
        require(block.timestamp > j.submitBy, "JobManager: still open");
        j.status = Status.Expired;
        usdc.safeTransfer(j.client, j.escrowAmount);
        emit JobSettled(jobId, Status.Expired);
    }

    // ------------------------------------------------------------------- owner

    function resolveDispute(uint256 jobId, bool providerWon) external onlyOwner nonReentrant {
        Job storage j = jobs[jobId];
        require(j.status == Status.Disputed, "JobManager: not disputed");
        if (providerWon) {
            _settleSuccess(jobId, j);
        } else {
            j.status = Status.Failed;
            usdc.safeTransfer(j.client, j.escrowAmount);
            try score.reportJobOutcome(j.provider, false) {} catch { emit ReputationCallFailed(jobId); }
            try vault.slash(j.provider, j.client, SLASH_PERCENT) {} catch { emit ReputationCallFailed(jobId); }
            emit JobSettled(jobId, Status.Failed);
        }
    }

    function setDisputeWindow(uint256 newWindow) external onlyOwner {
        require(newWindow >= MIN_DISPUTE_WINDOW && newWindow <= MAX_DISPUTE_WINDOW, "JobManager: bad window");
        disputeWindow = newWindow;
        emit DisputeWindowChanged(newWindow);
    }

    // ---------------------------------------------------------------- internal

    function _settleSuccess(uint256 jobId, Job storage j) internal {
        j.status = Status.Completed;
        usdc.safeTransfer(j.provider, j.escrowAmount);

        bytes32 key = keccak256(abi.encode(j.client, j.provider, block.timestamp / 1 days));
        if (scoredToday[key] < MAX_SCORED_PER_PAIR_PER_DAY) {
            scoredToday[key] += 1;
            try score.reportJobOutcome(j.provider, true) {} catch { emit ReputationCallFailed(jobId); }
        } else {
            emit NotScored(jobId);
        }
        emit JobSettled(jobId, Status.Completed);
    }
}
