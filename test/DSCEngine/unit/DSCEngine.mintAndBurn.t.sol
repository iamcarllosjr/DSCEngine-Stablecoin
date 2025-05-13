// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DescentralizedStablecoin} from "../../../src/DescentralizedStablecoin.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {ERC20Mock} from "../../Mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineMintAndBurnTest is BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function test_Mint_Dsc() public mintAndApproveERC20 depositCollateral {
    // 1. Deposit collateral and calculate the expected amount of DSC to mint
    uint256 expectMint = dscEngine.getMaxDscToMint(user);
    console.log("Max DSC to mint: ", expectMint);

    vm.startPrank(user);
    dscEngine.mintDsc(expectMint);
    vm.stopPrank();

    uint256 dscMinted = dscEngine.dscMinted(user);
    console.log("DSC minted: ", dscMinted);

    assertEq(dscMinted, expectMint, "DSC minted is not correct");
    // 75.000000000000000000 dsc minted
  }

  function test_Get_Max_Dsc_To_Mint() public mintAndApproveERC20 depositCollateral {
    vm.startPrank(user);
    uint256 dscToMint = dscEngine.getMaxDscToMint(user);
    vm.stopPrank();

    console.log("Max DSC to mint: ", dscToMint);
    // 175.000000000000000000
  }

  function test_Revert_Mint_With_Zero_Amount() public mintAndApproveERC20 depositCollateral {
    vm.startPrank(user);
    // 2. Try to mint 0
    uint256 amountToMint = 0;
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.AmountShouldBeMoreThanZero.selector, amountToMint));
    dscEngine.mintDsc(amountToMint);
    vm.stopPrank();
  }

  function test_Revert_Mint_More_Dsc_Than_Collateral() public mintAndApproveERC20 depositCollateral {
    // 1. Deposit collateral and calculate the expected amount of DSC to mint
    uint256 expectMint = dscEngine.getMaxDscToMint(user);
    console.log("Max DSC to mint: ", expectMint);

    vm.startPrank(user);
    // 2. Try to mint more DSC than the maximum allowed
    uint256 amountToMint = expectMint + 1;
    vm.expectRevert();
    // (abi.encodeWithSelector(DSCEngine.HealthFactorIsBroken.selector, healthFactor));
    dscEngine.mintDsc(amountToMint);
    vm.stopPrank();
  }

  function testBurnDsc() public mintAndApproveERC20 depositCollateral {
    // Pegar o maxToDscToMint
    uint256 dscToMint = dscEngine.getMaxDscToMint(user);
    console.log("Max DSC to mint: ", dscToMint);

    // Mint DSC
    vm.startPrank(user);
    dscEngine.mintDsc(dscToMint);

    // approve DSCEngine spend the dsc
    dsc.approve(address(dscEngine), dscToMint);

    // Burn DSC
    dscEngine.burnDsc(dscToMint);
    vm.stopPrank();

    uint256 userBalanceOfDsc = dsc.balanceOf(user);
    console.log("User balance of DSC: ", userBalanceOfDsc);
    assertEq(userBalanceOfDsc, 0);
  }

  // revert when not approved
  function test_Revert_Burn_Dsc_Not_Approved() public mintAndApproveERC20 depositCollateral {
    // Pegar o maxToDscToMint
    uint256 dscToMint = dscEngine.getMaxDscToMint(user);
    console.log("Max DSC to mint: ", dscToMint);

    // Mint DSC
    vm.startPrank(user);
    dscEngine.mintDsc(dscToMint);

    // Burn DSC
    vm.expectRevert();
    dscEngine.burnDsc(dscToMint);
    vm.stopPrank();
  }
}
