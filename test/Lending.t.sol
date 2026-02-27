// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CornToken} from "../src/CornToken.sol";
import {CornDex} from "../src/CornDex.sol";
import {Lending} from "../src/Lending.sol";
import {MovePrice} from "../src/MovePrice.sol";
import {FlashLoanLiquidator} from "../src/FlashLoanLiquidator.sol";
import {
    InsufficientCollateral,
    InsufficientDebt,
    HealthFactorOk,
    GracePeriodActive,
    NotAtRisk,
    ZeroAmount,
    TransferFailed,
    ZeroPrice,
    InvalidPercent
} from "../src/helpers/Errors.sol";

/// @dev Helper contract that rejects ETH transfers, used to test TransferFailed reverts.
contract ETHRejecter {
    Lending public lending;

    constructor(address _lending) {
        lending = Lending(payable(_lending));
    }

    function depositAndWithdraw(uint256 withdrawAmount) external payable {
        lending.depositCollateral{value: msg.value}();
        lending.withdrawCollateral(withdrawAmount);
    }

    function attemptLiquidation(address target, uint256 debtAmount, address cornTokenAddr) external {
        CornToken(cornTokenAddr).approve(address(lending), debtAmount);
        lending.liquidate(target, debtAmount);
    }

    // No receive() or fallback() — ETH transfers will fail
}

contract LendingTest is Test {
    CornToken cornToken;
    CornDex cornDex;
    Lending lending;
    MovePrice movePrice;
    FlashLoanLiquidator liquidator;

    address owner = makeAddr("owner");
    address homeowner = makeAddr("homeowner");
    address attacker = makeAddr("attacker");
    address nobody = makeAddr("nobody");

    uint256 constant INITIAL_ETH_PRICE = 2000e18; // 1 ETH = 2000 CORN
    uint256 constant COLLATERAL_AMOUNT = 10 ether;
    uint256 constant BORROW_AMOUNT = 15_000e18; // Borrow 15,000 CORN (safe at 2000 CORN/ETH with 80% LTV)

    function setUp() public {
        vm.startPrank(owner);

        cornToken = new CornToken(owner);
        cornDex = new CornDex(INITIAL_ETH_PRICE, owner);
        lending = new Lending(address(cornToken), address(cornDex));
        movePrice = new MovePrice(address(cornDex), owner);
        liquidator = new FlashLoanLiquidator(address(lending), address(cornToken));

        cornDex.transferOwnership(address(movePrice));
        cornToken.transferOwnership(address(lending));

        vm.stopPrank();

        vm.deal(homeowner, 100 ether);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  BASIC FUNCTIONALITY
    // ═══════════════════════════════════════════════════════════════════════════

    function test_DepositCollateral() public {
        vm.prank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();

        (uint256 ethCollateral,,) = lending.accounts(homeowner);
        assertEq(ethCollateral, COLLATERAL_AMOUNT);
    }

    function test_BorrowCorn() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        (, uint256 cornDebt,) = lending.accounts(homeowner);
        assertEq(cornDebt, BORROW_AMOUNT);
        assertEq(cornToken.balanceOf(homeowner), BORROW_AMOUNT);
    }

    function test_HealthFactorAboveOne() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        uint256 hf = lending.getHealthFactor(homeowner);
        assertGt(hf, 1e18, "Health factor should be above 1.0");
    }

    function test_NoDebtReturnsMaxHealthFactor() public {
        vm.prank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();

        uint256 hf = lending.getHealthFactor(homeowner);
        assertEq(hf, type(uint256).max, "No debt should return max health factor");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  40 ACRES SAFETY NET
    // ═══════════════════════════════════════════════════════════════════════════

    function test_StressTest_GracePeriodBlocksImmediateLiquidation() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        uint256 hfBefore = lending.getHealthFactor(homeowner);
        assertGt(hfBefore, 1e18);

        vm.prank(owner);
        movePrice.crashPrice(60);

        uint256 hfAfter = lending.getHealthFactor(homeowner);
        assertLt(hfAfter, 1e18, "Health factor should be below 1.0 after crash");

        lending.flagAtRisk(homeowner);

        vm.prank(address(lending));
        cornToken.mint(address(liquidator), BORROW_AMOUNT);

        vm.expectRevert();
        vm.prank(attacker);
        liquidator.executeLiquidation(homeowner, BORROW_AMOUNT);

        vm.warp(block.timestamp + 25 hours);

        vm.prank(attacker);
        liquidator.executeLiquidation(homeowner, BORROW_AMOUNT);

        (, uint256 debtAfter,) = lending.accounts(homeowner);
        assertEq(debtAfter, 0, "Debt should be fully repaid after liquidation");
    }

    function test_GracePeriodResetsWhenCollateralAdded() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        movePrice.crashPrice(60);

        lending.flagAtRisk(homeowner);

        (bool atRisk, uint256 atRiskSince,) = lending.getRiskStatus(homeowner);
        assertTrue(atRisk);
        assertGt(atRiskSince, 0);

        vm.warp(block.timestamp + 12 hours);

        vm.prank(homeowner);
        lending.depositCollateral{value: 20 ether}();

        uint256 hf = lending.getHealthFactor(homeowner);
        assertGt(hf, 1e18, "Health factor should recover after adding collateral");

        (atRisk, atRiskSince,) = lending.getRiskStatus(homeowner);
        assertFalse(atRisk);
        assertEq(atRiskSince, 0);
    }

    function test_RepayCornResetsRiskStatus() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        movePrice.crashPrice(60);

        (bool atRisk,,) = lending.getRiskStatus(homeowner);
        assertTrue(atRisk);

        vm.startPrank(homeowner);
        cornToken.approve(address(lending), BORROW_AMOUNT);
        lending.repayCorn(BORROW_AMOUNT);
        vm.stopPrank();

        (atRisk,,) = lending.getRiskStatus(homeowner);
        assertFalse(atRisk, "Should not be at risk after full repayment");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: depositCollateral
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_DepositCollateral_ZeroAmount() public {
        vm.prank(homeowner);
        vm.expectRevert(ZeroAmount.selector);
        lending.depositCollateral{value: 0}();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: withdrawCollateral
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_WithdrawCollateral_ZeroAmount() public {
        vm.prank(homeowner);
        vm.expectRevert(ZeroAmount.selector);
        lending.withdrawCollateral(0);
    }

    function test_RevertWhen_WithdrawCollateral_WouldBreakHealthFactor() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);

        vm.expectRevert(InsufficientCollateral.selector);
        lending.withdrawCollateral(9 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawCollateral_TransferFails() public {
        ETHRejecter rejecter = new ETHRejecter(address(lending));

        vm.expectRevert(TransferFailed.selector);
        rejecter.depositAndWithdraw{value: 1 ether}(1 ether);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: borrowCorn
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_BorrowCorn_ZeroAmount() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();

        vm.expectRevert(ZeroAmount.selector);
        lending.borrowCorn(0);
        vm.stopPrank();
    }

    function test_RevertWhen_BorrowCorn_ExceedsCollateral() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: 1 ether}();

        // 1 ETH = 2000 CORN, 80% LTV = 1600 CORN max
        vm.expectRevert(InsufficientCollateral.selector);
        lending.borrowCorn(1601e18);
        vm.stopPrank();
    }

    function test_RevertWhen_BorrowCorn_NoCollateral() public {
        vm.prank(homeowner);
        vm.expectRevert(InsufficientCollateral.selector);
        lending.borrowCorn(1e18);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: repayCorn
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_RepayCorn_ZeroAmount() public {
        vm.prank(homeowner);
        vm.expectRevert(ZeroAmount.selector);
        lending.repayCorn(0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: flagAtRisk
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_FlagAtRisk_NoDebt() public {
        vm.prank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();

        vm.expectRevert(HealthFactorOk.selector);
        lending.flagAtRisk(homeowner);
    }

    function test_RevertWhen_FlagAtRisk_HealthyPosition() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.expectRevert(HealthFactorOk.selector);
        lending.flagAtRisk(homeowner);
    }

    function test_RevertWhen_FlagAtRisk_NonExistentUser() public {
        vm.expectRevert(HealthFactorOk.selector);
        lending.flagAtRisk(nobody);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: liquidate
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_Liquidate_ZeroAmount() public {
        vm.prank(attacker);
        vm.expectRevert(ZeroAmount.selector);
        lending.liquidate(homeowner, 0);
    }

    function test_RevertWhen_Liquidate_HealthyPosition() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(address(lending));
        cornToken.mint(attacker, BORROW_AMOUNT);

        vm.startPrank(attacker);
        cornToken.approve(address(lending), BORROW_AMOUNT);
        vm.expectRevert(HealthFactorOk.selector);
        lending.liquidate(homeowner, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_Liquidate_NotFlagged() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        movePrice.crashPrice(60);

        // User is undercollateralized but NOT flagged yet
        vm.prank(address(lending));
        cornToken.mint(attacker, BORROW_AMOUNT);

        vm.startPrank(attacker);
        cornToken.approve(address(lending), BORROW_AMOUNT);
        vm.expectRevert(NotAtRisk.selector);
        lending.liquidate(homeowner, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_Liquidate_GracePeriodActive() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        movePrice.crashPrice(60);

        lending.flagAtRisk(homeowner);

        vm.warp(block.timestamp + 12 hours);

        vm.prank(address(lending));
        cornToken.mint(attacker, BORROW_AMOUNT);

        vm.startPrank(attacker);
        cornToken.approve(address(lending), BORROW_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(GracePeriodActive.selector, 12 hours));
        lending.liquidate(homeowner, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function test_RevertWhen_Liquidate_NoApproval() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        movePrice.crashPrice(60);
        lending.flagAtRisk(homeowner);
        vm.warp(block.timestamp + 25 hours);

        vm.prank(address(lending));
        cornToken.mint(attacker, BORROW_AMOUNT);

        // Attacker has CORN but did NOT approve the Lending contract
        vm.prank(attacker);
        vm.expectRevert();
        lending.liquidate(homeowner, BORROW_AMOUNT);
    }

    function test_RevertWhen_Liquidate_TransferFails_ETHReject() public {
        vm.startPrank(homeowner);
        lending.depositCollateral{value: COLLATERAL_AMOUNT}();
        lending.borrowCorn(BORROW_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        movePrice.crashPrice(60);
        lending.flagAtRisk(homeowner);
        vm.warp(block.timestamp + 25 hours);

        // ETHRejecter will receive CORN and attempt liquidation,
        // but can't receive the seized ETH
        ETHRejecter rejecter = new ETHRejecter(address(lending));
        vm.prank(address(lending));
        cornToken.mint(address(rejecter), BORROW_AMOUNT);

        vm.prank(address(rejecter));
        vm.expectRevert(TransferFailed.selector);
        rejecter.attemptLiquidation(homeowner, BORROW_AMOUNT, address(cornToken));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: Plain ETH send (no receive function)
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_PlainETHSent() public {
        vm.deal(nobody, 1 ether);
        vm.prank(nobody);
        (bool success,) = address(lending).call{value: 1 ether}("");
        assertFalse(success, "Plain ETH transfer should fail");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: CornDex
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_CornDex_ConstructorZeroPrice() public {
        vm.expectRevert(ZeroPrice.selector);
        new CornDex(0, owner);
    }

    function test_RevertWhen_CornDex_SetPriceZero() public {
        CornDex dex = new CornDex(1000e18, address(this));
        vm.expectRevert(ZeroPrice.selector);
        dex.setPrice(0);
    }

    function test_RevertWhen_CornDex_SetPriceNotOwner() public {
        CornDex dex = new CornDex(1000e18, owner);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        dex.setPrice(500e18);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  REVERT: MovePrice
    // ═══════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_CrashPrice_ZeroPercent() public {
        vm.prank(owner);
        vm.expectRevert(InvalidPercent.selector);
        movePrice.crashPrice(0);
    }

    function test_RevertWhen_CrashPrice_HundredPercent() public {
        vm.prank(owner);
        vm.expectRevert(InvalidPercent.selector);
        movePrice.crashPrice(100);
    }

    function test_RevertWhen_CrashPrice_OverHundredPercent() public {
        vm.prank(owner);
        vm.expectRevert(InvalidPercent.selector);
        movePrice.crashPrice(150);
    }

    function test_RevertWhen_CrashPrice_NotOwner() public {
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        movePrice.crashPrice(50);
    }

    function test_RevertWhen_PumpPrice_ZeroPercent() public {
        vm.prank(owner);
        vm.expectRevert(InvalidPercent.selector);
        movePrice.pumpPrice(0);
    }

    function test_RevertWhen_PumpPrice_NotOwner() public {
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        movePrice.pumpPrice(50);
    }

    function test_RevertWhen_SetExactPrice_NotOwner() public {
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        movePrice.setExactPrice(1000e18);
    }
}
