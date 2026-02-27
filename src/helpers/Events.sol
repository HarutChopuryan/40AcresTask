// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// ─── Lending ─────────────────────────────────────────────────────────────────
event CollateralDeposited(address indexed user, uint256 amount);
event CollateralWithdrawn(address indexed user, uint256 amount);
event CornBorrowed(address indexed user, uint256 amount);
event CornRepaid(address indexed user, uint256 amount);
event AtRiskStatusChanged(address indexed user, bool atRisk, uint256 timestamp);
event Liquidated(address indexed user, address indexed liquidator, uint256 debtRepaid, uint256 collateralSeized);

// ─── Price / Oracle ──────────────────────────────────────────────────────────
event PriceUpdated(uint256 oldPrice, uint256 newPrice);
event PriceCrashed(address indexed caller, uint256 dropPercent, uint256 oldPrice, uint256 newPrice);
event PricePumped(address indexed caller, uint256 risePercent, uint256 oldPrice, uint256 newPrice);
event PriceSetExact(address indexed caller, uint256 newPrice);

// ─── Token ───────────────────────────────────────────────────────────────────
event CornMinted(address indexed to, uint256 amount);
event CornBurned(address indexed from, uint256 amount);

// ─── Liquidator ──────────────────────────────────────────────────────────────
event LiquidationAttempted(address indexed target, bool success, string reason);
event LiquidationProceedsReceived(uint256 amount);
