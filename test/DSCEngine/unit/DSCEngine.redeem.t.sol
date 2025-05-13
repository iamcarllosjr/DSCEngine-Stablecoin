// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../../../src/DSCEngine.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {ERC20Mock} from "../../Mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineRedeemTest is BaseTest {
  function setUp() public virtual override {
    BaseTest.setUp();
  }

  function test_Redeem_Collateral() public mintAndApproveERC20 depositCollateral {
    uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(user, weth);
    console.log("Collateral deposited: ", collateralDeposited);

    vm.startPrank(user);
    dscEngine.redeemCollateral(weth, collateralDeposited);
    vm.stopPrank();

    uint256 expectCollateral = dscEngine.getCollateralBalanceOfUser(user, weth);
    assertEq(expectCollateral, 0, "Collateral value is not correct");
    console.log("Collateral value after redeem: ", expectCollateral);
  }

  function test_Revert_With_Zero_Amount() public mintAndApproveERC20 depositCollateral {
    uint256 amountToRedeem = 0;

    vm.startPrank(user);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.AmountShouldBeMoreThanZero.selector, amountToRedeem));
    dscEngine.redeemCollateral(weth, amountToRedeem);
    vm.stopPrank();
  }

  function test_Revert_If_Dont_Have_Enough_Collateral() public mintAndApproveERC20 depositCollateral {
    uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(user, weth);
    console.log("Collateral deposited :", collateralDeposited);

    uint256 amount = 2 ether;

    vm.startPrank(user);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.InsufficientCollateral.selector, amount, collateralDeposited));
    dscEngine.redeemCollateral(weth, amount);
    vm.stopPrank();
  }

  function test_Redeem_Collateral_For_Dsc() public mintAndApproveERC20 {
    vm.startPrank(user);
    // Deposit collateral and mint DSC
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    // Calculate the amount of collateral to redeem
    uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(user, weth);
    console.log("Collateral deposited: ", collateralDeposited);

    // Check the amount of DSC minted
    uint256 dscMinted = dscEngine.dscMinted(user);
    console.log("DSC minted: ", dscMinted);
    // 75.000000000000000000

    uint256 totalSupplyOfCollateralInDscEngine = ERC20Mock(weth).balanceOf(address(dscEngine));
    console.log("Total supply of weth in dscEngine: ", totalSupplyOfCollateralInDscEngine);
    // .075000000000000000

    (, uint256 collateralValue) = dscEngine.getAccountInformation(user);
    console.log("Collateral value in USD: ", collateralValue);

    // approve DSCEngine to spend the dsc
    dsc.approve(address(dscEngine), dscMinted);

    // Redeem collateral for DSC
    dscEngine.redeemCollateralForDsc(weth, collateralDeposited);
    vm.stopPrank();

    uint256 userBalanceOfDsc = dsc.balanceOf(user);
    console.log("User balance of DSC: ", userBalanceOfDsc);
    assertEq(userBalanceOfDsc, 0);

    uint256 dscEngineBalanceOfWeth = ERC20Mock(weth).balanceOf(address(dscEngine));
    console.log("DSCEngine balance of WETH: ", dscEngineBalanceOfWeth);
    assertEq(dscEngineBalanceOfWeth, 0);
  }

  function test_Redeem_After_Mint_DSC() public mintAndApproveERC20 {
    // Deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    // Calculate the amount of collateral to redeem
    uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(user, weth);
    console.log("Collateral deposited: ", collateralDeposited);

    // Check the amount of DSC minted
    uint256 dscMinted = dscEngine.dscMinted(user);
    console.log("DSC minted: ", dscMinted);

    // Check balance of user
    uint256 userBalanceOfDscBeforeRedeem = dsc.balanceOf(user);
    console.log("User balance of DSC Before Redeem: ", userBalanceOfDscBeforeRedeem);
    uint256 protocolBalanceAfterDepositCollateral = ERC20Mock(weth).balanceOf(address(dscEngine));
    console.log("Protocol balance of WETH After Deposit Collateral: ", protocolBalanceAfterDepositCollateral);

    // Burn DSC first
    vm.startPrank(user);
    dsc.approve(address(dscEngine), dscMinted);
    dscEngine.burnDsc(dscMinted);
    vm.stopPrank();

    // Redeem collateral for DSC
    vm.prank(user);
    dscEngine.redeemCollateral(weth, collateralDeposited);
    uint256 userBalanceOfDscAfterRedeem = dsc.balanceOf(user);
    console.log("User balance of DSC After Redeem: ", userBalanceOfDscAfterRedeem);
    uint256 protocolBalanceAfterRedeemCollateral = ERC20Mock(weth).balanceOf(address(dscEngine));
    console.log("Protocol balance of WETH After Redeem Collateral: ", protocolBalanceAfterRedeemCollateral);

    assertEq(userBalanceOfDscAfterRedeem, 0, "User balance of DSC is not correct");
  }

  function test_Revert_Redeem_Collateral_If_You_Havent_Burned_DSC_First() public mintAndApproveERC20 {
    // Deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    // Calculate the amount of collateral to redeem
    uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(user, weth);
    console.log("Collateral deposited: ", collateralDeposited);

    // Check the amount of DSC minted
    uint256 dscMinted = dscEngine.dscMinted(user);
    console.log("DSC minted: ", dscMinted);

    // Check balance of user
    uint256 userBalanceOfDscBeforeRedeem = dsc.balanceOf(user);
    console.log("User balance of DSC Before Redeem: ", userBalanceOfDscBeforeRedeem);
    uint256 protocolBalanceAfterDepositCollateral = ERC20Mock(weth).balanceOf(address(dscEngine));
    console.log("Protocol balance of WETH After Deposit Collateral: ", protocolBalanceAfterDepositCollateral);

    // Redeem collateral for DSC
    vm.prank(user);
    // revert with HealthFactorIsBroken()
    vm.expectRevert();
    dscEngine.redeemCollateral(weth, collateralDeposited);
  }
}
