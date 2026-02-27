// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CornToken} from "./CornToken.sol";
import {Lending} from "./Lending.sol";
import {LiquidationAttempted, LiquidationProceedsReceived} from "./helpers/Events.sol";

/// @title FlashLoanLiquidator — Simulates a flash-loan-based liquidation attack
/// @notice In a real DeFi scenario, this contract would borrow CORN via a flash loan,
///         liquidate the user, seize ETH collateral, and repay the loan — all in one tx.
///         The 40 Acres grace period is designed to block this exact pattern.
contract FlashLoanLiquidator {
    Lending public immutable lending;
    CornToken public immutable cornToken;

    constructor(address _lending, address _cornToken) {
        lending = Lending(payable(_lending));
        cornToken = CornToken(_cornToken);
    }

    /// @notice Attempt to liquidate a user's position.
    ///         In a real scenario, CORN would come from a flash loan.
    ///         Here we simulate by minting CORN to this contract first (done in tests).
    function executeLiquidation(address target, uint256 debtAmount) external {
        cornToken.approve(address(lending), debtAmount);

        try lending.liquidate(target, debtAmount) {
            emit LiquidationAttempted(target, true, "Liquidation succeeded");
        } catch Error(string memory reason) {
            emit LiquidationAttempted(target, false, reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            emit LiquidationAttempted(target, false, "Low-level revert");
            assembly {
                revert(add(lowLevelData, 32), mload(lowLevelData))
            }
        }
    }

    receive() external payable {
        emit LiquidationProceedsReceived(msg.value);
    }
}
