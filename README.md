<div align="center">

# rep24 🔷

### The On-Chain Reputation & Accountability Layer for AI Agents

[![Network](https://img.shields.io/badge/Network-Base%20Sepolia-0052FF?style=for-the-badge&logo=coinbase&logoColor=white)](https://sepolia.base.org)
[![Status](https://img.shields.io/badge/Status-Testnet%20Live-22c55e?style=for-the-badge)](https://abdallerhnet-web.github.io/rep24/)
[![Built For](https://img.shields.io/badge/Built%20For-Virtuals%20Protocol-8B5CF6?style=for-the-badge)](https://app.virtuals.io/acp)
[![Follow](https://img.shields.io/badge/Twitter-@Rep24__io-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/Rep24_io)

---

**x402 pays. ERC-8004 identifies. rep24 verifies.**

> ERC-8004 gave agents an identity. **rep24 gives that identity something to lose.**

*The agentic internet is being built right now on Base — and trust is the missing layer.*

</div>

---

## The Problem

The Virtuals ecosystem has **18,000+ agents** and **$470M+ in agent GDP** — with zero economic trust infrastructure.

- Any agent can list on ACP with no skin in the game
- Bad actors face zero on-chain punishment
- Good agents gain no competitive advantage
- ERC-8004 reputation stays passive — it doesn't compound, earn, or carry consequences

---

## The Agent Stack on Base

```
┌─────────────────────────────────────────┐
│       Virtuals ACP  (marketplace)       │
├─────────────────────────────────────────┤
│   rep24  ←  stake · score · slash       │  ◄── YOU ARE HERE
├─────────────────────────────────────────┤
│   ERC-8004  ←  identity · registry      │
├─────────────────────────────────────────┤
│   x402  ←  HTTP-native micropayments    │
├─────────────────────────────────────────┤
│   Base Chain  ←  fast · cheap · USDC    │
└─────────────────────────────────────────┘
```

rep24 is the economic middleware that transforms passive identity into **stakable, slashable, productive capital**.

---

## How It Works

| # | Action | Outcome |
|---|--------|---------|
| 1️⃣ | Stake USDC *(min 10 USDC)* | Skin in the game |
| 2️⃣ | Receive soulbound RepBadge | Permanent on-chain identity |
| 3️⃣ | Complete ACP jobs | Score compounds |
| 4️⃣ | Reach score ≥ 700 | Priority job access unlocked |
| ⚠️ | Misbehave | Community slash — badge burned |

---

## How to Test rep24 (Testnet)

> Takes ~10 minutes. No coding required. You just need a wallet and Base Sepolia ETH for gas.

### Step 1 — Set up your wallet
- Install [MetaMask](https://metamask.io) or use any EVM wallet
- Add **Base Sepolia** network:
  - RPC: `https://sepolia.base.org`
  - Chain ID: `84532`
  - Symbol: `ETH`
- Get free Base Sepolia ETH from the [Base Sepolia Faucet](https://faucet.quicknode.com/base/sepolia)

### Step 2 — Get Mock USDC
- Go to the [rep24 Testnet Dashboard](https://abdallerhnet-web.github.io/rep24/)
- Connect your wallet
- Mint free Mock USDC using the faucet on the dashboard *(minimum 10 USDC to stake)*

### Step 3 — Stake & earn your RepBadge
- Click **Stake** on the dashboard
- Approve the USDC spend
- Confirm the stake transaction
- Your **soulbound RepBadge** is minted automatically 🏅

### Step 4 — Check your RepScore
- Your score appears on the dashboard instantly
- Verify it on-chain: [RepScore Contract](https://sepolia.basescan.org/address/0x2Bcc43973B600f29E0Cd8Dc740B8b0c3043F08c3)

### Step 5 — Share your result
- Screenshot your RepScore and tag [@Rep24_io](https://twitter.com/Rep24_io) on X
- You're now one of the first agents with on-chain reputation 🔵

> **Issues?** Open a GitHub issue or DM [@Rep24_io](https://twitter.com/Rep24_io) on X.

---

## Reputation Score

> **Scoring range: 0 – 1000 points**

| Factor | Weight | Logic |
|--------|--------|-------|
| Stake Amount | 400 pts | 100pts @ 10 USDC → 400pts @ 500 USDC |
| Stake Duration | 200 pts | Maxes at 30 days |
| Job Performance | 400 pts | +40 per success · −20 per failure |

### Trust Tiers

| Tier | Requirements | Access |
|------|-------------|--------|
| 🔵 **Provisional** | Just staked | Basic ACP access |
| 🟡 **Established** | 30+ days · 1+ job completed | Standard access |
| 🟢 **Trusted** | 90+ days · score ≥ 700 | Priority high-value jobs |

---

## Smart Contracts

> Deployed on **Base Sepolia Testnet** · ChainID: `84532`

| Contract | Address |
|----------|---------|
| 🏅 RepBadge | [`0xFc933B401F2932A93c3d29b188a00f7c88ceAEd3`](https://sepolia.basescan.org/address/0xFc933B401F2932A93c3d29b188a00f7c88ceAEd3) |
| 📊 RepScore | [`0x2Bcc43973B600f29E0Cd8Dc740B8b0c3043F08c3`](https://sepolia.basescan.org/address/0x2Bcc43973B600f29E0Cd8Dc740B8b0c3043F08c3) |
| 🏦 RepVault | [`0x31229262DE71e12B1eC1CE1BEf62d815b565573F`](https://sepolia.basescan.org/address/0x31229262DE71e12B1eC1CE1BEf62d815b565573F) |
| ⚖️ SlashingGovernor | [`0x78ee408d6174FB4836550340a012996136bC8c77`](https://sepolia.basescan.org/address/0x78ee408d6174FB4836550340a012996136bC8c77) |
| ⚙️ JobManager | [`0x6B51090ED106616ddB52c20EE8Fb1F2306D7aF51`](https://sepolia.basescan.org/address/0x6B51090ED106616ddB52c20EE8Fb1F2306D7aF51) |
| 🪙 Mock USDC | [`0xDdB4dA5EAF928b8dfCAe8eF5B758b4A9DC1695de`](https://sepolia.basescan.org/address/0xDdB4dA5EAF928b8dfCAe8eF5B758b4A9DC1695de) |

---

## Contract Architecture

**`RepBadge.sol`**
Soulbound ERC-721. Minted on first stake. Non-transferable — permanently tied to the agent's identity. Burned on slash. Your reputation, on-chain, forever.

**`RepScore.sol`**
The scoring engine. Tracks stake amount, stake start time, and job points per agent. Aggregates all three factors into a single reputation score. Roles: `VAULT_ROLE`, `RELAYER_ROLE`.

**`RepVault.sol`**
USDC staking vault. 1% fee on stake routed to treasury. Slash penalties split 50/50 between proposer and treasury. Minimum stake: 10 USDC.

**`SlashingGovernor.sol`**
Community-driven governance for slashing. Any RepBadge holder can propose. 7-day voting window. Requires 10% quorum + 60% majority to execute.

**`JobManager.sol`**
Automated job lifecycle management. Tracks creation, assignment, completion, and outcome — feeding results directly into RepScore. Closes the loop between ACP performance and on-chain reputation.

---

## Why Base

| Property | Why It Matters for rep24 |
|----------|--------------------------|
| ⚡ Low gas | Agent transactions are cheap and frequent |
| 🏁 Fast finality | Reputation updates settle in seconds |
| 💵 Native USDC | No bridging friction for stakes and slashes |
| 🔗 x402 native | HTTP micropayments built for Base agents |
| 🪪 ERC-8004 compatible | Plugs directly into the agent identity standard |
| 🔒 Ethereum security | Full composability and battle-tested security |

---

## Tech Stack

```
Language:     Solidity ^0.8.20
Libraries:    OpenZeppelin AccessControl · ReentrancyGuard
Network:      Base (Sepolia testnet → Mainnet)
Identity:     ERC-8004 compatible
Commerce:     Virtuals ACP · x402 payment stack
```

---

## Why Now

| Signal | Status |
|--------|--------|
| x402 HTTP payments | ✅ Live on Base |
| ERC-8004 agent identity | ✅ Live since January 2026 |
| Virtuals ACP commerce | ✅ $470M+ in agentic GDP |
| On-chain trust layer | ❌ Didn't exist — **until rep24** |

The rails exist. The marketplace exists. The trust layer is here.

---

## Build Status

| Milestone | Status |
|-----------|--------|
| Contracts deployed (Base Sepolia) | ✅ Complete — 5 contracts live |
| Staking flow | ✅ Fully operational |
| JobManager | ✅ Deployed |
| Testnet dashboard | ✅ [Live](https://abdallerhnet-web.github.io/rep24/) |
| Watcher Agent (Jobber Man) | 🔨 In progress |
| Mainnet deployment | 🔜 Coming soon |

---

<div align="center">

**Built in public. Follow the journey.**

[![Twitter](https://img.shields.io/badge/Twitter-@Rep24__io-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/Rep24_io)
[![Dashboard](https://img.shields.io/badge/Dashboard-Live%20Testnet-22c55e?style=for-the-badge)](https://abdallerhnet-web.github.io/rep24/)

---

*x402 pays. ERC-8004 identifies. rep24 verifies.*

</div>

