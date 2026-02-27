// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {CornToken} from "./CornToken.sol";
import {CornDex} from "./CornDex.sol";
import {PriceCalculator} from "./helpers/PriceCalculator.sol";
import {
    InsufficientCollateral,
    InsufficientDebt,
    HealthFactorOk,
    GracePeriodActive,
    NotAtRisk,
    ZeroAmount,
    TransferFailed
} from "./helpers/Errors.sol";
import {
    CollateralDeposited,
    CollateralWithdrawn,
    CornBorrowed,
    CornRepaid,
    AtRiskStatusChanged,
    Liquidated
} from "./helpers/Events.sol";

/// @title Lending — ETH-collateralized CORN borrowing with 24-hour liquidation grace period
/// @notice Users deposit ETH as collateral and borrow CORN tokens.
///         If a user's health factor drops below 1.0, a 24-hour "Safety Net" begins
///         before any liquidation is allowed — protecting homeowners from flash crashes.
contract Lending is ReentrancyGuard {
    // ─── Constants ────────────────────────────────────────────────────────────────
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0 in 18 decimals
    uint256 public constant GRACE_PERIOD = 24 hours;
    uint256 public constant LIQUIDATION_THRESHOLD = 80; // 80% LTV
    uint256 public constant LIQUIDATION_BONUS = 5; // 5% bonus for liquidator

    // ─── State ────────────────────────────────────────────────────────────────────
    CornToken public immutable cornToken;
    CornDex public immutable cornDex;

    struct UserAccount {
        uint256 ethCollateral; // ETH deposited (in wei)
        uint256 cornDebt; // CORN borrowed (18 decimals)
        uint256 atRiskSince; // Timestamp when health factor first dropped below 1.0 (0 = not at risk)
    }

    mapping(address => UserAccount) public accounts;

    constructor(address _cornToken, address _cornDex) {
        cornToken = CornToken(_cornToken);
        cornDex = CornDex(_cornDex);
    }

    // ─── Core Functions ───────────────────────────────────────────────────────────

    /// @notice Deposit ETH as collateral.
    ///         If the user was flagged at-risk and adding collateral restores
    ///         the health factor above 1.0, the grace period clock resets.
    function depositCollateral() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        UserAccount storage account = accounts[msg.sender];
        account.ethCollateral += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);

        _tryResetRisk(msg.sender, account);
    }

    /// @notice Withdraw ETH collateral (must maintain healthy position).
    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserAccount storage account = accounts[msg.sender];
        
        amount = amount > account.ethCollateral ? account.ethCollateral : amount;

        account.ethCollateral -= amount;

        if (account.cornDebt > 0) {
            uint256 hf = _calculateHealthFactor(account.ethCollateral, account.cornDebt);
            if (hf < MIN_HEALTH_FACTOR) revert InsufficientCollateral();
        }

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /// @notice Borrow CORN against deposited ETH collateral.
    function borrowCorn(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserAccount storage account = accounts[msg.sender];

        uint256 newDebt = account.cornDebt + amount;
        uint256 hf = _calculateHealthFactor(account.ethCollateral, newDebt);
        if (hf < MIN_HEALTH_FACTOR) revert InsufficientCollateral();

        account.cornDebt = newDebt;
        cornToken.mint(msg.sender, amount);

        emit CornBorrowed(msg.sender, amount);
    }

    /// @notice Repay CORN debt.
    ///         If the user was flagged at-risk and repaying restores
    ///         the health factor above 1.0, the grace period clock resets.
    function repayCorn(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        UserAccount storage account = accounts[msg.sender];

        amount = amount > account.cornDebt ? account.cornDebt : amount;

        account.cornDebt -= amount;
        cornToken.burn(msg.sender, amount);

        emit CornRepaid(msg.sender, amount);

        _tryResetRisk(msg.sender, account);
    }

    // ─── Risk Flagging ─────────────────────────────────────────────────────────

    /// @notice Flag a user as at-risk. Anyone can call this (keepers, bots, users).
    ///         Records the timestamp when health factor first dropped below 1.0,
    ///         starting the 24-hour grace period clock.
    function flagAtRisk(address user) external {
        UserAccount storage account = accounts[user];
        if (account.cornDebt == 0) revert HealthFactorOk();

        uint256 hf = _calculateHealthFactor(account.ethCollateral, account.cornDebt);
        if (hf >= MIN_HEALTH_FACTOR) revert HealthFactorOk();

        if (account.atRiskSince == 0) {
            account.atRiskSince = block.timestamp;
            emit AtRiskStatusChanged(user, true, block.timestamp);
        }
    }

    // ─── Liquidation ──────────────────────────────────────────────────────────────

    /// @notice Liquidate an undercollateralized position after the 24-hour grace period.
    /// @dev Reverts if the grace period hasn't been started (call flagAtRisk first)
    ///      or if it hasn't expired yet.
    function liquidate(address user, uint256 debtToRepay) external nonReentrant {
        UserAccount storage account = accounts[user];
        if (debtToRepay == 0) revert ZeroAmount();

        debtToRepay = debtToRepay > account.cornDebt ? account.cornDebt : debtToRepay;

        uint256 hf = _calculateHealthFactor(account.ethCollateral, account.cornDebt);
        if (hf >= MIN_HEALTH_FACTOR) revert HealthFactorOk();

        // Enforce the 24-hour Safety Net
        if (account.atRiskSince == 0) revert NotAtRisk();

        uint256 elapsed = block.timestamp - account.atRiskSince;
        if (elapsed < GRACE_PERIOD) {
            revert GracePeriodActive(GRACE_PERIOD - elapsed);
        }

        // Grace period expired — proceed with liquidation
        uint256 collateralToSeize =
            PriceCalculator.calculateCollateralToSeize(debtToRepay, cornDex.ethPriceInCorn(), LIQUIDATION_BONUS);

        if (collateralToSeize > account.ethCollateral) {
            collateralToSeize = account.ethCollateral;
        }

        // Transfer CORN from liquidator to protocol and burn
        if (!cornToken.transferFrom(msg.sender, address(this), debtToRepay)) revert TransferFailed();
        cornToken.burn(address(this), debtToRepay);

        account.cornDebt -= debtToRepay;
        account.ethCollateral -= collateralToSeize;

        // Reset risk status
        if (account.cornDebt == 0 || _calculateHealthFactor(account.ethCollateral, account.cornDebt) >= MIN_HEALTH_FACTOR) {
            account.atRiskSince = 0;
            emit AtRiskStatusChanged(user, false, block.timestamp);
        }

        (bool success,) = msg.sender.call{value: collateralToSeize}("");
        if (!success) revert TransferFailed();

        emit Liquidated(user, msg.sender, debtToRepay, collateralToSeize);
    }

    // ─── View Functions ───────────────────────────────────────────────────────────

    /// @notice Calculate the health factor for a user.
    /// @return healthFactor The ratio of collateral value to debt value (18 decimals).
    ///         A value >= 1e18 means the position is healthy.
    function getHealthFactor(address user) external view returns (uint256 healthFactor) {
        UserAccount storage account = accounts[user];
        if (account.cornDebt == 0) return type(uint256).max;
        return _calculateHealthFactor(account.ethCollateral, account.cornDebt);
    }

    /// @notice Get the risk status for a user.
    /// @return atRisk Whether the user is currently at risk
    /// @return atRiskSince Timestamp when risk began (0 if not at risk)
    /// @return graceRemaining Seconds remaining in grace period (0 if expired or not at risk)
    function getRiskStatus(address user)
        external
        view
        returns (bool atRisk, uint256 atRiskSince, uint256 graceRemaining)
    {
        UserAccount storage account = accounts[user];

        if (account.cornDebt == 0) return (false, 0, 0);

        uint256 hf = _calculateHealthFactor(account.ethCollateral, account.cornDebt);
        atRisk = hf < MIN_HEALTH_FACTOR;

        if (!atRisk) return (false, 0, 0);

        atRiskSince = account.atRiskSince;
        if (atRiskSince == 0) {
            graceRemaining = GRACE_PERIOD;
        } else {
            uint256 elapsed = block.timestamp - atRiskSince;
            graceRemaining = elapsed >= GRACE_PERIOD ? 0 : GRACE_PERIOD - elapsed;
        }
    }

    /// @notice Get collateral value in CORN for a user.
    function getCollateralValueInCorn(address user) external view returns (uint256) {
        return PriceCalculator.ethToCornValue(accounts[user].ethCollateral, cornDex.ethPriceInCorn());
    }

    // ─── Internal ─────────────────────────────────────────────────────────────────

    function _calculateHealthFactor(uint256 ethCollateral, uint256 cornDebt) internal view returns (uint256) {
        uint256 collateralValueInCorn = PriceCalculator.ethToCornValue(ethCollateral, cornDex.ethPriceInCorn());
        return PriceCalculator.calculateHealthFactor(collateralValueInCorn, cornDebt, LIQUIDATION_THRESHOLD);
    }

    /// @notice Reset risk flag if the user's position has recovered.
    ///         Only called after operations that can improve health (deposit, repay).
    ///         Skips entirely if the user was never flagged, avoiding unnecessary oracle calls.
    function _tryResetRisk(address user, UserAccount storage account) internal {
        if (account.atRiskSince == 0) return;

        bool healthy = account.cornDebt == 0
            || _calculateHealthFactor(account.ethCollateral, account.cornDebt) >= MIN_HEALTH_FACTOR;

        if (healthy) {
            account.atRiskSince = 0;
            emit AtRiskStatusChanged(user, false, block.timestamp);
        }
    }
}
