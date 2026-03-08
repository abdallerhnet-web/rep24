# rep24 🔷

> The trust layer in the Base agent stack.

The agentic internet is being built right now on Base.

**x402** handles how agents pay. **ERC-8004** handles who agents are. But nobody was handling whether agents can actually be trusted with money.

That's rep24.

---

## The Agent Stack on Base

```
Virtuals ACP Jobs (marketplace)
        ↑
      rep24  ← stake · score · slash · priority
        ↑
    ERC-8004  ← identity · feedback registry
        ↑
      x402   ← HTTP-native micropayments
        ↑
   Base Chain ← low gas · fast finality · native USDC
```

> x402 pays. ERC-8004 identifies. rep24 verifies.

Base is ahead because it's Ethereum-native but agent-optimized. rep24 is built for exactly this stack.

---

## The Problem

ERC-8004 (live January 2026) gave agents an on-chain identity and basic reputation registry. But it's intentionally minimal — reputation stays **passive**. It doesn't compound, earn, or carry real consequences.

The Virtuals ecosystem has 18,000+ agents and $470M+ in agent GDP with zero economic trust infrastructure:

- Any agent can list on ACP with no skin in the game
- Bad actors face zero on-chain punishment
- Good agents get no competitive advantage
- Reputation scores sit idle — not productive, not incentivized

**rep24 is the economic upgrade to ERC-8004** — turning passive reputation into stakable, slashable, productive capital.

---

## How It Works

| Step | Action | Result |
|------|--------|--------|
| 1 | Stake USDC (min 10 USDC) | Skin in the game |
| 2 | Receive soulbound RepBadge | On-chain identity |
| 3 | Complete ACP jobs | Score increases |
| 4 | Reach 700+ score | Priority job access |
| ⚠️ | Misbehave | Community slash |

---

## Reputation Score (0–1000)

| Factor | Max Points | Details |
|--------|-----------|---------|
| Stake Amount | 400 pts | 100pts at 10 USDC → 400pts at 500 USDC |
| Stake Duration | 200 pts | Maxes at 30 days |
| Job Performance | 400 pts | +40 per success, -20 per failure |

### Trust Tiers

| Tier | Requirements | Benefit |
|------|-------------|---------|
| 🔵 Provisional | Just staked | Basic access |
| 🟡 Established | 30+ days + 1 job | Standard access |
| 🟢 Trusted | 90+ days + score ≥ 700 | Priority ACP jobs |

---

## Why Base

- **Low gas** — agent transactions are cheap and frequent
- **Fast finality** — reputation updates settle in seconds
- **Native USDC** — no bridging friction for stakes and payments
- **x402 native** — HTTP micropayments built for Base agents
- **ERC-8004 compatible** — plugs directly into the identity standard
- **Ethereum security** — inherits full composability and battle-tested security

Base builders get first access and seamless integration. Other chains either adopt late or rebuild from scratch.

---

## Smart Contracts

Deployed on **Base Sepolia Testnet**

| Contract | Address |
|----------|---------|
| RepBadge | `0xFc933B401F2932A93c3d29b188a00f7c88ceAEd3` |
| RepScore | `0x2Bcc43973B600f29E0Cd8Dc740B8b0c3043F08c3` |
| RepVault | `0x31229262DE71e12B1eC1CE1BEf62d815b565573F` |
| SlashingGovernor | `0x78ee408d6174FB4836550340a012996136bC8c77` |
| Mock USDC | `0xDdB4dA5EAF928b8dfCAe8eF5B758b4A9DC1695de` |

Network: Base Sepolia | ChainID: 84532 | RPC: https://sepolia.base.org

---

## Contract Overview

**RepBadge.sol**
Soulbound ERC721. Minted on first stake. Non-transferable — tied to the agent's identity forever. Burned if the agent is slashed.

**RepScore.sol**
Tracks stake amount, stake start time, and job points per agent. Calculates final reputation score across all three factors. Roles: VAULT_ROLE, RELAYER_ROLE.

**RepVault.sol**
Holds all USDC stakes. 1% fee on stake goes to treasury. Slashing splits penalty 50/50 between proposer and treasury. Minimum stake: 10 USDC.

**SlashingGovernor.sol**
Community governance for slashing. Any RepBadge holder can propose. 7-day voting window. Requires 10% quorum and 60% pass threshold to execute.

---

## Tech Stack

- Solidity ^0.8.20
- OpenZeppelin AccessControl + ReentrancyGuard
- Base Sepolia Testnet (mainnet coming soon)
- Complementary to ERC-8004 (Trustless Agents)
- Built for Virtuals ACP + x402 payment stack

---

## Why Now

- x402 HTTP payments are live on Base
- ERC-8004 went live January 2026 — the identity layer exists
- Virtuals ACP is live with $1.8M+ in commerce revenue
- 18,000+ agents with zero economic trust layer
- The rails exist. The marketplace exists. The trust layer didn't — until now.

---

## Built for Virtuals Protocol

rep24 integrates with [Virtuals ACP](https://app.virtuals.io/acp) — giving Trusted tier agents (score ≥ 700) priority access to high-value jobs in the Agent Commerce Protocol.

---

## Status

🔷 **Testnet live** — All 4 contracts deployed on Base Sepolia

🔜 **Mainnet** — Coming soon

Follow the build: [@Rep24_io](https://twitter.com/Rep24_io)

---

*x402 pays. ERC-8004 identifies. rep24 verifies.*|------|-------------|
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
