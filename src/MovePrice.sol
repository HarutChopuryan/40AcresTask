// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CornDex} from "./CornDex.sol";
import {InvalidPercent} from "./helpers/Errors.sol";
import {PriceCrashed, PricePumped, PriceSetExact} from "./helpers/Events.sol";

/// @title MovePrice — Testing utility to shift ETH/CORN market prices
/// @notice Only the owner can manipulate prices. Designed for test scenarios.
contract MovePrice is Ownable {
    CornDex public immutable cornDex;

    constructor(address _cornDex, address _owner) Ownable(_owner) {
        cornDex = CornDex(_cornDex);
    }

    /// @notice Crash the ETH price by a percentage (e.g., 50 = drop by 50%).
    function crashPrice(uint256 dropPercent) external onlyOwner {
        if (dropPercent == 0 || dropPercent >= 100) revert InvalidPercent();
        uint256 currentPrice = cornDex.ethPriceInCorn();
        uint256 newPrice = (currentPrice * (100 - dropPercent)) / 100;
        cornDex.setPrice(newPrice);
        emit PriceCrashed(msg.sender, dropPercent, currentPrice, newPrice);
    }

    /// @notice Pump the ETH price by a percentage (e.g., 50 = increase by 50%).
    function pumpPrice(uint256 risePercent) external onlyOwner {
        if (risePercent == 0) revert InvalidPercent();
        uint256 currentPrice = cornDex.ethPriceInCorn();
        uint256 newPrice = (currentPrice * (100 + risePercent)) / 100;
        cornDex.setPrice(newPrice);
        emit PricePumped(msg.sender, risePercent, currentPrice, newPrice);
    }

    /// @notice Set an exact price.
    function setExactPrice(uint256 newPrice) external onlyOwner {
        cornDex.setPrice(newPrice);
        emit PriceSetExact(msg.sender, newPrice);
    }
}
