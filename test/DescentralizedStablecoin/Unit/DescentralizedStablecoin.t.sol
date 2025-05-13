// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DescentralizedStablecoin} from "../../../src/DescentralizedStablecoin.sol";
import {Test} from "forge-std/Test.sol";

contract DescebtralizedStablecoinTest is Test {
  DescentralizedStablecoin public dsc;
  address public owner = makeAddr("owner");
  address public zeroAddress = address(0);

  function setUp() public {
    vm.prank(owner);
    dsc = new DescentralizedStablecoin();
  }

  function testOwnerIsDeployer() public view {
    assertEq(dsc.owner(), owner, "Owner is not the deployer");
  }

  function testName() public view {
    assertEq(dsc.name(), "DescentralizedStablecoin");
  }

  function testSymbol() public view {
    assertEq(dsc.symbol(), "DSC");
  }

  function testDecimals() public view {
    assertEq(dsc.decimals(), 18);
  }

  function testMint() public {
    uint256 mintAmount = 1000 ether;

    vm.prank(owner);
    dsc.mint(owner, mintAmount);
    assertEq(dsc.balanceOf(owner), mintAmount);
  }

  function testBurn() public {
    uint256 mintAmount = 1000 ether;
    uint256 burnAmount = 500 ether;

    vm.startPrank(owner);
    dsc.mint(owner, mintAmount);
    assertEq(dsc.balanceOf(owner), mintAmount);

    dsc.burn(burnAmount);
    assertEq(dsc.balanceOf(owner), mintAmount - burnAmount);
    vm.stopPrank();
  }

  function testMintFailWithZeroAddress() public {
    uint256 mintAmount = 1000 ether;

    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(DescentralizedStablecoin.InvalidAddressOrAmount.selector, address(0), mintAmount));
    dsc.mint(zeroAddress, mintAmount);
    vm.stopPrank();
  }

  function testMintFailWithZeroAmount() public {
    uint256 minAmount = 0 ether;

    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(DescentralizedStablecoin.InvalidAddressOrAmount.selector, owner, minAmount));
    dsc.mint(owner, minAmount);
    vm.stopPrank();
  }

  function testBurnFailWithZeroBalance() public {
    uint256 balanceBefore = dsc.balanceOf(owner);
    uint256 burnAmount = 1000 ether;

    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(DescentralizedStablecoin.InvalidBalanceOrAmount.selector, balanceBefore, burnAmount));
    dsc.burn(burnAmount);
    vm.stopPrank();
  }

  function testBurnFailWithZeroAmount() public {
    uint256 burnAmount = 0;
    uint256 mintAmount = 1000 ether;

    vm.startPrank(owner);
    dsc.mint(owner, mintAmount);
    assertEq(dsc.balanceOf(owner), mintAmount);

    vm.expectRevert(abi.encodeWithSelector(DescentralizedStablecoin.InvalidBalanceOrAmount.selector, mintAmount, burnAmount));
    dsc.burn(burnAmount);
    vm.stopPrank();
  }
}
