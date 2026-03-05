// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRepBadge {
    function mint(address agentAddress) external;
    function hasBadge(address agentAddress) external view returns (bool);
}

interface IRepScore {
    function updateStake(address agentWallet, uint256 newStakeAmount) external;
    function onUnstake(address agentWallet) external;
}

contract RepVault is AccessControl, ReentrancyGuard {
    IERC20 public immutable usdc;
    address public immutable repBadge;
    address public immutable repScore;
    address public immutable treasury;

    uint256 public constant MIN_STAKE_AMOUNT = 10 * 1e6;
    uint256 public constant FEE_PERCENT = 1;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => uint256) public stakeBalances;

    event Staked(address indexed agentAddress, uint256 amount, uint256 newBalance);
    event Unstaked(address indexed agentAddress, uint256 amount);

    constructor(
        address _usdc,
        address _repBadge,
        address _repScore,
        address _treasury
    ) {
        usdc = IERC20(_usdc);
        repBadge = _repBadge;
        repScore = _repScore;
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function stake(address agentAddress, uint256 amount)
        external nonReentrant {
        require(amount >= MIN_STAKE_AMOUNT, "RepVault: Minimum stake amount not met");
        require(agentAddress != address(0), "RepVault: invalid agent address");

        uint256 feeAmount = (amount * FEE_PERCENT) / 100;
        uint256 stakeAmount = amount - feeAmount;

        require(
            usdc.transferFrom(msg.sender, address(this), amount),
            "RepVault: Failed to transfer USDC to vault"
        );
        require(
            usdc.transfer(treasury, feeAmount),
            "RepVault: Failed to transfer fee to treasury"
        );

        if (stakeBalances[agentAddress] == 0) {
            if (!IRepBadge(repBadge).hasBadge(agentAddress)) {
                IRepBadge(repBadge).mint(agentAddress);
            }
        }

        stakeBalances[agentAddress] += stakeAmount;
        IRepScore(repScore).updateStake(agentAddress, stakeBalances[agentAddress]);

        emit Staked(agentAddress, stakeAmount, stakeBalances[agentAddress]);
    }

    function unstake(address agentAddress, uint256 amount)
        external nonReentrant {
        require(stakeBalances[agentAddress] >= amount, "RepVault: Insufficient stake balance");

        stakeBalances[agentAddress] -= amount;

        if (stakeBalances[agentAddress] == 0) {
            IRepScore(repScore).onUnstake(agentAddress);
        }

        require(usdc.transfer(msg.sender, amount), "RepVault: Failed to transfer USDC back");

        emit Unstaked(agentAddress, amount);
    }

    function getStakeBalance(address agentAddress) external view returns (uint256) {
        return stakeBalances[agentAddress];
    }

    function slash(address agentAddress, address proposer, uint256 slashPercent)
        external onlyRole(ADMIN_ROLE) nonReentrant {
        require(slashPercent <= 100, "RepVault: Slash percentage cannot exceed 100");

        uint256 slashAmount = (stakeBalances[agentAddress] * slashPercent) / 100;
        require(slashAmount > 0, "RepVault: Slash amount must be greater than zero");

        stakeBalances[agentAddress] -= slashAmount;

        uint256 toProposer = slashAmount / 2;
        uint256 toTreasury = slashAmount - toProposer;

        require(usdc.transfer(proposer, toProposer), "RepVault: Failed to transfer to proposer");
        require(usdc.transfer(treasury, toTreasury), "RepVault: Failed to transfer to treasury");

        if (stakeBalances[agentAddress] == 0) {
            IRepScore(repScore).onUnstake(agentAddress);
        }
    }

    function emergencyWithdrawExcessUSDC(uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount <= usdc.balanceOf(address(this)), "RepVault: Not enough USDC");
        require(usdc.transfer(msg.sender, amount), "RepVault: Failed to withdraw");
    }
}
