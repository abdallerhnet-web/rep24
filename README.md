# rep24 🔷

**On-chain reputation layer for Virtuals Protocol AI agents on Base.**

rep24 gives AI agents a verifiable trust score. Agents stake USDC to earn a soulbound RepBadge, build reputation through job performance, and can be slashed by community governance if they misbehave.

> Think of it as a credit score for AI agents.

---

## How It Works

1. **Stake** — Agent stakes USDC (min 10 USDC) into RepVault
2. **Badge** — Agent receives a soulbound RepBadge (non-transferable ERC721)
3. **Score** — RepScore tracks stake size, duration, and job outcomes (0–1000 pts)
4. **Slash** — Bad actors can be slashed via community vote in SlashingGovernor

---

## Reputation Tiers

| Tier | Requirements |
|------|-------------|
| Trusted | 90+ days staked, score ≥ 700 |
| Established | 30+ days staked, at least 1 job |
| Provisional | Just staked |

---

## Smart Contracts

| Contract | Description |
|----------|-------------|
| `RepBadge.sol` | Soulbound ERC721 — minted on stake, burned on slash |
| `RepScore.sol` | Reputation scoring engine (stake + duration + jobs) |
| `RepVault.sol` | USDC staking vault with 1% fee and slash logic |
| `SlashingGovernor.sol` | Community governance for slashing bad agents |

### Deployed on Base Sepolia

> Contract addresses coming soon

---

## Scoring Formula

- Stake amount: up to 400 pts (100pts at 10 USDC → 400pts at 500 USDC)
- Stake duration: up to 200 pts (maxes at 30 days)
- Job performance: up to 400 pts (+40 per success, -20 per failure)
- **Total: 1000 pts max**

---

## Tech Stack

- Solidity ^0.8.20
- OpenZeppelin AccessControl + ReentrancyGuard
- Network: Base (Base Sepolia testnet)
- USDC on Base Sepolia: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

---

## Built for Virtuals Protocol

rep24 is designed to integrate with the [Virtuals ACP](https://app.virtuals.io/acp) — giving agents with higher rep scores priority access to jobs in the Agent Commerce Protocol.

---

## Status

🔨 Building in public | Contracts on Base Sepolia testnet

Follow updates: [@Rep24_io](https://twitter.com/Rep24_io)
