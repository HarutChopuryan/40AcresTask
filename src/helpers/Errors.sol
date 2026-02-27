// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// ─── Lending ─────────────────────────────────────────────────────────────────
error InsufficientCollateral();
error HealthFactorOk();
error GracePeriodActive(uint256 timeRemaining);
error NotAtRisk();

// ─── Shared ──────────────────────────────────────────────────────────────────
error ZeroAmount();
error TransferFailed();

// ─── Price / Oracle ──────────────────────────────────────────────────────────
error ZeroPrice();
error InvalidPercent();
