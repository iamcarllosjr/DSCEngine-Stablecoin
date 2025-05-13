// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../../../src/DSCEngine.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {ERC20Mock} from "../../Mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../Mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineLiquidateTest is BaseTest {
  address liquidator = makeAddr("liquidator");
  uint256 amountCollateral = 0.075 ether;

  function setUp() public virtual override {
    BaseTest.setUp();
  }

  function test_Liquidate() public mintAndApproveERC20 {
    vm.startPrank(liquidator);
    // Mint tokens to the liquidator for the liquidation
    ERC20Mock(weth).mint(liquidator, amountCollateral);
    uint256 liquidatorBalance = ERC20Mock(weth).balanceOf(liquidator);
    console.log("Liquidator WETH balance: ", ERC20Mock(weth).balanceOf(liquidator));
    ERC20Mock(weth).approve(address(dscEngine), liquidatorBalance);

    // Liquidator deposit collateral and mint DSC
    // This is to make sure the liquidator has enough DSC to cover the liquidation
    dscEngine.depositCollateralAndMintDsc(weth, liquidatorBalance);
    uint256 liquidatorDscBalance = dscEngine.dscMinted(liquidator);
    console.log("Liquidator DSC balance: ", liquidatorDscBalance);

    // Approve the dscEngine to spend the liquidator's DSC (Burn)
    dsc.approve(address(dscEngine), liquidatorDscBalance);
    vm.stopPrank();

    // User deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, amountCollateral);

    uint256 userBalance = dscEngine.dscMinted(user);
    console.log("User DSC balance: ", userBalance);

    // User HF
    uint256 healthFactorBeforeUpdatePrice = dscEngine.getHealthFactor(user);
    console.log("User health factor before update price: ", healthFactorBeforeUpdatePrice);

    // Update the price of the collateral to make the user "undercollateralized"
    int256 ethUsdUpdatedPrice = 1000e8; // 1 ETH = $1000
    MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

    // New user HF
    uint256 healthFactorAfterUpdatePrice = dscEngine.getHealthFactor(user);
    console.log("User health factor after update price: ", healthFactorAfterUpdatePrice);

    // Call the liquidate function
    vm.prank(liquidator);
    dscEngine.liquidate(weth, user, userBalance);

    // Check the liquidator's balance after liquidation
    uint256 liquidatorBalanceAfter = ERC20Mock(weth).balanceOf(liquidator);
    console.log("Liquidator WETH balance after liquidation: ", liquidatorBalanceAfter);
    // Check the user's balance after liquidation
    uint256 userBalanceAfter = dscEngine.dscMinted(user);
    console.log("User DSC balance after liquidation: ", userBalanceAfter);
    // Check the user's collateral balance after liquidation
    uint256 userCollateralBalanceAfter = ERC20Mock(weth).balanceOf(user);
    console.log("User WETH balance after liquidation: ", userCollateralBalanceAfter);
    // Check the liquidator's DSC balance after liquidation
    uint256 liquidatorDscBalanceAfter = dscEngine.dscMinted(liquidator);
    console.log("Liquidator DSC balance after liquidation: ", liquidatorDscBalanceAfter);
  }

  function test_Revert_Liquidate_With_Zero_Amount() public mintAndApproveERC20 {
    uint256 debtToLiquidate = 0;

    // 1. Deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    // 1. Liquidate the user
    vm.startPrank(liquidator);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.AmountShouldBeMoreThanZero.selector, debtToLiquidate));
    dscEngine.liquidate(weth, user, debtToLiquidate);
    vm.stopPrank();
  }

  function test_Revert_When_User_Cannot_Be_Liquidate() public mintAndApproveERC20 {
    // 1. Deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    uint256 totalDscMinted = dscEngine.dscMinted(user);
    console.log("DSC minted: ", totalDscMinted);

    uint256 healthFactor = dscEngine.getHealthFactor(user);
    console.log("Health factor: ", healthFactor);

    // 1. Liquidate the user
    vm.startPrank(liquidator);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.UserCannotBeLiquidated.selector, user, healthFactor));
    dscEngine.liquidate(weth, user, totalDscMinted);
    vm.stopPrank();
  }
}
