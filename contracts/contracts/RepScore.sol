// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RepScore is AccessControl {
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    struct AgentData {
        uint256 stakeAmount;
        uint256 stakeStartTime;
        uint256 jobPts;
    }

    mapping(address => AgentData) public agentData;

    event ScoreUpdated(address indexed agent, uint256 newScore);
    event JobReported(address indexed agent, bool success);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function updateStake(address agentWallet, uint256 newStakeAmount)
        external onlyRole(VAULT_ROLE) {
        AgentData storage d = agentData[agentWallet];
        if (d.stakeStartTime == 0) {
            d.stakeStartTime = block.timestamp;
        }
        d.stakeAmount = newStakeAmount;
        emit ScoreUpdated(agentWallet, getRepScore(agentWallet));
    }

    function onUnstake(address agentWallet)
        external onlyRole(VAULT_ROLE) {
        AgentData storage d = agentData[agentWallet];
        d.stakeAmount = 0;
        d.stakeStartTime = 0;
        emit ScoreUpdated(agentWallet, 0);
    }

    function reportJobOutcome(address agentWallet, bool success)
        external onlyRole(RELAYER_ROLE) {
        AgentData storage d = agentData[agentWallet];
        if (success) {
            uint256 newPts = d.jobPts + 40;
            d.jobPts = newPts > 400 ? 400 : newPts;
        } else {
            d.jobPts = d.jobPts >= 20 ? d.jobPts - 20 : 0;
        }
        emit JobReported(agentWallet, success);
        emit ScoreUpdated(agentWallet, getRepScore(agentWallet));
    }

    function updateDuration(address agentWallet) external {
        emit ScoreUpdated(agentWallet, getRepScore(agentWallet));
    }

    function getRepScore(address agentWallet)
        public view returns (uint256) {
        AgentData storage d = agentData[agentWallet];

        uint256 stakePts;
        uint256 minStake = 10_000_000;
        uint256 maxStake = 500_000_000;
        if (d.stakeAmount >= maxStake) {
            stakePts = 400;
        } else if (d.stakeAmount >= minStake) {
            stakePts = 100 + ((d.stakeAmount - minStake) * 300)
                / (maxStake - minStake);
        } else {
            stakePts = 0;
        }

        uint256 durationPts = 0;
        if (d.stakeStartTime > 0 && d.stakeAmount > 0) {
            uint256 daysStaked = (block.timestamp - d.stakeStartTime) / 1 days;
            durationPts = (daysStaked * 200) / 30;
            if (durationPts > 200) durationPts = 200;
        }

        uint256 total = stakePts + durationPts + d.jobPts;
        return total > 1000 ? 1000 : total;
    }

    function getRepTier(address agentWallet)
        external view returns (string memory) {
        AgentData storage d = agentData[agentWallet];
        uint256 score = getRepScore(agentWallet);
        uint256 daysStaked = d.stakeStartTime > 0
            ? (block.timestamp - d.stakeStartTime) / 1 days : 0;

        if (daysStaked >= 90 && score >= 700) return "Trusted";
        if (daysStaked >= 30 && d.jobPts > 0) return "Established";
        return "Provisional";
    }
}
