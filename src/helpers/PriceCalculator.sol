// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title PriceCalculator — Isolated price math for ETH/CORN lending
/// @notice Pure functions with 18-decimal precision. No external dependencies.
library PriceCalculator {
    uint256 internal constant PRECISION = 1e18;

    /// @notice Convert an ETH amount to its CORN value given the current price.
    /// @param ethAmount Amount of ETH in wei (18 decimals)
    /// @param ethPriceInCorn Price of 1 ETH in CORN (18 decimals)
    /// @return cornValue The equivalent CORN value (18 decimals)
    /// @dev Integer division truncates. Dust-level ETH amounts (single-wei positions)
    ///      may round down to zero, causing calculateHealthFactor to return
    ///      type(uint256).max for those positions. Economically negligible in practice.
    function ethToCornValue(uint256 ethAmount, uint256 ethPriceInCorn) internal pure returns (uint256 cornValue) {
        cornValue = (ethAmount * ethPriceInCorn) / PRECISION;
    }

    /// @notice Convert a CORN debt amount to ETH value given the current price.
    /// @param cornAmount Amount of CORN (18 decimals)
    /// @param ethPriceInCorn Price of 1 ETH in CORN (18 decimals)
    /// @return ethValue The equivalent ETH value in wei (18 decimals)
    function cornToEthValue(uint256 cornAmount, uint256 ethPriceInCorn) internal pure returns (uint256 ethValue) {
        ethValue = (cornAmount * PRECISION) / ethPriceInCorn;
    }

    /// @notice Calculate health factor: (collateral * threshold) / debt.
    /// @param collateralValueInCorn Collateral value in CORN (18 decimals)
    /// @param cornDebt Outstanding debt in CORN (18 decimals)
    /// @param liquidationThreshold Percentage of collateral that counts (e.g. 80)
    /// @return healthFactor 18-decimal ratio; >= 1e18 means healthy
    function calculateHealthFactor(
        uint256 collateralValueInCorn,
        uint256 cornDebt,
        uint256 liquidationThreshold
    ) internal pure returns (uint256 healthFactor) {
        if (cornDebt == 0) return type(uint256).max;
        uint256 adjustedCollateral = (collateralValueInCorn * liquidationThreshold) / 100;
        healthFactor = (adjustedCollateral * PRECISION) / cornDebt;
    }


}
