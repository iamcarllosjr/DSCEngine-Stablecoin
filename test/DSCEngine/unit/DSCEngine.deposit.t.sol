// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../../../src/DSCEngine.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {ERC20Mock} from "../../Mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineTestDeposit is BaseTest {
  function setUp() public virtual override {
    BaseTest.setUp();
  }

  function test_Deposit_Collateral() public mintAndApproveERC20 {
    vm.startPrank(user);
    // Deposit WETH as collateral
    dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
    vm.stopPrank();
  }

  function test_Deposit_Collateral_And_Mint_Dsc() public mintAndApproveERC20 {
    vm.startPrank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);
    vm.stopPrank();

    (uint256 totalDscMinted, ) = dscEngine.getAccountInformation(user);
    console.log("totalDscMinted: ", totalDscMinted);
    // $150 collateral value
    // 75.000000000000000000 dsc minted
  }

  function test_Revert_When_Token_Is_Not_Allowed() public {
    ERC20Mock notAllowedTokenMock = new ERC20Mock(0);

    vm.startPrank(user);
    // Mint WETH to the user
    ERC20Mock(notAllowedTokenMock).mint(user, 10e18);
    // Approve the DSCEngine to spend WETH
    ERC20Mock(notAllowedTokenMock).approve(address(dscEngine), 10e18);

    vm.expectRevert(abi.encodeWithSelector(DSCEngine.NotAllowedTokenAddress.selector, address(notAllowedTokenMock)));
    dscEngine.depositCollateral(address(notAllowedTokenMock), 10e18);
    vm.stopPrank();
  }

  function test_Revert_When_Amount_Is_Zero() public mintAndApproveERC20 {
    uint256 amountToDeposit = 0;

    vm.startPrank(user);
    // Deposit WETH as collateral with 0 amount
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.AmountShouldBeMoreThanZero.selector, amountToDeposit));
    dscEngine.depositCollateral(weth, amountToDeposit);
    vm.stopPrank();
  }

  function test_Revert_If_Dont_Have_Enough_Collateral() public {
    vm.startPrank(user);
    // Mint WETH to the user
    // ERC20Mock(weth).mint(user, 10e18);
    // Approve the DSCEngine to spend WETH
    ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
    // Deposit WETH as collateral
    vm.expectRevert();
    dscEngine.depositCollateral(weth, 10e18);
    vm.stopPrank();
  }
}
