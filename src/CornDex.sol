// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ZeroPrice} from "./helpers/Errors.sol";
import {PriceUpdated} from "./helpers/Events.sol";
import {PriceCalculator} from "./helpers/PriceCalculator.sol";

/// @title CornDex — ETH/CORN Price Oracle
/// @notice Provides the ETH price denominated in CORN tokens (18 decimals).
///         For example, if 1 ETH = 2000 CORN, then ethPriceInCorn = 2000e18.
contract CornDex is Ownable {
    uint256 public ethPriceInCorn;

    constructor(uint256 initialPrice, address owner) Ownable(owner) {
        if (initialPrice == 0) revert ZeroPrice();
        ethPriceInCorn = initialPrice;
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert ZeroPrice();
        uint256 oldPrice = ethPriceInCorn;
        ethPriceInCorn = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    /// @notice Returns how much CORN a given amount of ETH is worth.
    function ethToCornValue(uint256 ethAmount) external view returns (uint256) {
        return PriceCalculator.ethToCornValue(ethAmount, ethPriceInCorn);
    }
}
