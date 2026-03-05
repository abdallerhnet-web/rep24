// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IRepBadge {
    function hasBadge(address agentAddress) external view returns (bool);
    function burn(address agentAddress) external;
}

interface IRepVault {
    function slash(address agentAddress, address proposer, uint256 slashPercent) external;
}

contract SlashingGovernor is AccessControl, ReentrancyGuard {

    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant PASS_THRESHOLD_PERCENTAGE = 60;
    uint256 public constant SLASH_PENALTY = 20;

    IRepBadge public immutable repBadge;
    IRepVault public immutable repVault;

    uint256 public proposalCount;
    uint256 public totalBadgeHolders;

    struct Proposal {
        uint256 id;
        address target;
        bytes32 evidenceHash;
        address proposer;
        uint256 votingDeadline;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 voterCount;
        bool executed;
        bool passed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed proposalId, address indexed target, bytes32 evidenceHash, address indexed proposer, uint256 votingDeadline);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 yesVotes, uint256 noVotes);
    event ProposalPassed(uint256 indexed proposalId);
    event ProposalFailed(uint256 indexed proposalId);
    event SlashExecuted(uint256 indexed proposalId, address indexed target, address indexed proposer);

    constructor(address _repBadge, address _repVault) {
        repBadge = IRepBadge(_repBadge);
        repVault = IRepVault(_repVault);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function proposeSlash(address target, bytes32 evidenceHash)
        external returns (uint256) {
        require(repBadge.hasBadge(msg.sender), "SlashingGovernor: Proposer must hold a RepBadge");
        require(repBadge.hasBadge(target), "SlashingGovernor: Target must hold a RepBadge");
        require(target != msg.sender, "SlashingGovernor: Cannot slash yourself");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage p = proposals[proposalId];
        p.id = proposalId;
        p.target = target;
        p.evidenceHash = evidenceHash;
        p.proposer = msg.sender;
        p.votingDeadline = block.timestamp + VOTING_DURATION;

        emit ProposalCreated(proposalId, target, evidenceHash, msg.sender, p.votingDeadline);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external nonReentrant {
        require(repBadge.hasBadge(msg.sender), "SlashingGovernor: Voter must hold a RepBadge");
        require(block.timestamp < proposals[proposalId].votingDeadline, "SlashingGovernor: Voting period ended");
        require(!proposals[proposalId].executed, "SlashingGovernor: Proposal already executed");
        require(!hasVoted[proposalId][msg.sender], "SlashingGovernor: Already voted");

        Proposal storage p = proposals[proposalId];
        hasVoted[proposalId][msg.sender] = true;
        p.voterCount++;

        if (support) { p.yesVotes++; } else { p.noVotes++; }

        emit VoteCast(proposalId, msg.sender, support, p.yesVotes, p.noVotes);
    }

    function executeSlash(uint256 proposalId) external nonReentrant {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.votingDeadline, "SlashingGovernor: Voting not ended");
        require(!p.executed, "SlashingGovernor: Already executed");
        require(proposalId > 0 && proposalId <= proposalCount, "SlashingGovernor: Invalid proposal");

        uint256 requiredQuorum = (totalBadgeHolders * QUORUM_PERCENTAGE) / 100;
        require(p.voterCount >= requiredQuorum, "SlashingGovernor: Quorum not met");

        uint256 totalVotes = p.yesVotes + p.noVotes;
        uint256 requiredYes = (totalVotes * PASS_THRESHOLD_PERCENTAGE) / 100;

        p.executed = true;

        if (p.yesVotes > requiredYes) {
            p.passed = true;
            repVault.slash(p.target, p.proposer, SLASH_PENALTY);
            repBadge.burn(p.target);
            emit ProposalPassed(proposalId);
            emit SlashExecuted(proposalId, p.target, p.proposer);
        } else {
            p.passed = false;
            emit ProposalFailed(proposalId);
        }
    }

    function getProposal(uint256 proposalId) public view returns (Proposal memory) {
        require(proposalId > 0 && proposalId <= proposalCount, "SlashingGovernor: Invalid proposal ID");
        return proposals[proposalId];
    }

    function incrementBadgeHolders() external onlyRole(DEFAULT_ADMIN_ROLE) {
        totalBadgeHolders++;
    }

    function decrementBadgeHolders() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalBadgeHolders > 0, "SlashingGovernor: Cannot go below zero");
        totalBadgeHolders--;
    }
}
