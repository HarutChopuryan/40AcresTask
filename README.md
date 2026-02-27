# 40 Acres — Equity Protection Challenge

A DeFi lending protocol modified to protect asset ownership through a **24-hour liquidation grace period** ("Safety Net"). Users who deposit ETH as collateral to borrow CORN tokens are protected from flash-crash liquidations.

## Architecture

```
├── src/                          # Solidity smart contracts
│   ├── Lending.sol               # Core lending protocol with 24h grace period
│   ├── CornToken.sol             # CORN ERC20 token
│   ├── CornDex.sol               # ETH/CORN price oracle
│   ├── MovePrice.sol             # Price manipulation tool (testing)
│   └── FlashLoanLiquidator.sol   # Flash loan liquidator
├── test/
│   └── Lending.t.sol             # Foundry tests (stress test + edge cases)
├── script/
│   └── Deploy.s.sol              # Anvil deployment script
├── frontend/                     # Next.js 15 + wagmi + Tailwind
│   ├── src/components/
│   │   └── ProtectionDashboard.tsx  # Green/Yellow/Red status + countdown
│   ├── src/hooks/
│   │   └── useLendingData.ts     # Real-time contract data hooks
│   └── src/config/
│       ├── wagmi.ts              # Chain & wallet config
│       └── abis.ts               # Contract ABIs
├── foundry.toml
└── README.md
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil, cast)
- [Node.js](https://nodejs.org/) >= 18 (for the frontend)

## Quick Start

### 1. Smart Contracts

```bash
# Install dependencies (already done if cloned with submodules)
forge install

# Build contracts
forge build

# Run all tests
forge test -vvv

# Run the stress test only
forge test --match-test test_StressTest -vvv
```

### 2. Local Deployment (Anvil)

```bash
# Terminal 1: Start local chain
anvil

# Terminal 2: Deploy contracts
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

Copy the deployed addresses from the console output into `frontend/.env.local`.

### 3. Frontend

```bash
cd frontend

# Install dependencies
npm install

# Copy and fill in contract addresses
cp .env.local.example .env.local
# Edit .env.local with deployed contract addresses

# Start dev server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the Protection Dashboard.

## How the Safety Net Works

1. **User deposits ETH** and borrows CORN tokens
2. **If ETH price drops** and the Health Factor falls below 1.0, the user is flagged "at risk"
3. **A 24-hour clock starts** — during this time, liquidation is blocked
4. **The user can recover** by adding more ETH collateral or repaying CORN debt
5. **If they recover**, the clock resets to zero
6. **After 24 hours**, if still undercollateralized, liquidation is permitted

## Key Contract Functions

| Function | Description |
|---|---|
| `getHealthFactor(address)` | Ratio of collateral value to debt (18 decimals). >= 1e18 is healthy |
| `flagAtRisk(address)` | Records the timestamp when a user becomes undercollateralized |
| `liquidate(address, uint256)` | Liquidates a position — reverts if within 24h grace period |
| `depositCollateral()` | Deposit ETH; resets grace period if health factor recovers |
| `borrowCorn(uint256)` | Borrow CORN against ETH collateral |

## Tests

| Test | What it proves |
|---|---|
| `test_StressTest_GracePeriodBlocksImmediateLiquidation` | Flash loan liquidation blocked during 24h, succeeds after 25h |
| `test_GracePeriodResetsWhenCollateralAdded` | Adding collateral resets the grace period clock |
| `test_RepayCornResetsRiskStatus` | Repaying debt clears the at-risk status |
| `test_CannotLiquidateHealthyPosition` | Healthy positions cannot be liquidated |
| `test_CannotBorrowBeyondCollateral` | Borrowing beyond LTV limit is rejected |

## Frontend Dashboard States

- **Green** — "Equity Secure" — Health Factor > 1.0
- **Yellow** — "Safety Net Active" — Health Factor < 1.0, with live countdown timer
- **Red** — "Protection Expired" — Health Factor < 1.0 and 24 hours have passed
