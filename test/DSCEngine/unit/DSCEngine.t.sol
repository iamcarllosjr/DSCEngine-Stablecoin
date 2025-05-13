// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {HelperConfig} from "../../../script/HelperConfig.s.sol";

import {DSCEngine} from "../../../src/DSCEngine.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {ERC20Mock} from "../../Mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineTest is BaseTest {
  function setUp() public virtual override {
    BaseTest.setUp();
  }

  function testRevertMismatchInConstructor() public {
    address[] memory tokenAddresses = new address[](1);
    tokenAddresses[0] = address(weth);

    address[] memory priceFeeds = new address[](2);
    priceFeeds[0] = address(ethUsdPriceFeed);
    priceFeeds[1] = address(wbtcPriceFeed);

    // Deploy the DSCEngine with invalid parameters
    // Usging abi.encodeWithSelector because the revert expect a parameter
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.MismatchArraysLength.selector, tokenAddresses, priceFeeds));
    new DSCEngine(tokenAddresses, priceFeeds);
  }

  // function testRevertAddressZeroInConstructor() public {
  //   address[] memory tokenAddresses = new address[](1);
  //   tokenAddresses[0] = address(0);

  //   address[] memory priceFeeds = new address[](1);
  //   priceFeeds[0] = address(ethUsdPriceFeed);

  //   // Deploy the DSCEngine with invalid parameters
  //   // Usging abi.encodeWithSelector because the revert expect a parameter
  //   vm.expectRevert(abi.encodeWithSelector(DSCEngine.ZeroAddressNotAllowed.selector, tokenAddresses[0]));
  //   new DSCEngine(tokenAddresses, priceFeeds);
  // }

  function testGetUsdValue() public view {
    uint256 ethAmount = 15e18;
    // Assumptions $2000/ETH
    // 15e18 * 2000 = 30,000e18
    uint256 expectedUsd = 30_000e18;
    uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);
    assertEq(actualUsd, expectedUsd, "USD value is not correct");
  }

  function testGetTokenAmountFromUsd() public {
    uint256 usdAmount = 100 ether;
    // Assumptions $2000/ETH
    // We have $100/ETH
    // 100 / 2000 = 0.05 ETH
    uint256 expectedTokenAmount = 0.05 ether; // 100 / 2000
    uint256 actualTokenAmount = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
    assertEq(actualTokenAmount, expectedTokenAmount, "Token amount is not correct");
  }

  function testGetAccountInformation() public mintAndApproveERC20 depositCollateral {
    (uint256 dscMinted, uint256 collateralValue) = dscEngine.getAccountInformation(user);

    // Because just deposit collateral, and not mint Dsc
    uint256 expectTotalDscMinted = 0;

    // Calling GetTokenamOUntfromusd() to convert the token value in USD to total token
    uint256 expectDepositAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValue);

    assertEq(dscMinted, expectTotalDscMinted, "DSC minted is not correct");
    assertEq(AMOUNT_COLLATERAL, expectDepositAmount, "Collateral value is not correct");
    // collateralValue = 20_000.000000000000000000 because user has deposited 10 WETH * $2000
    // expectDepositAmount = 10.000000000000000000 ($20_000 / $2000)
  }

  function testGetAllowedToken() public {
    vm.startPrank(user);
    bool isAllowed = dscEngine.getAllowedTokenAddress(weth);
    vm.stopPrank();

    assertTrue(isAllowed, "Address token not allowed");
  }
}
