// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {BaseTest} from "../../../BaseTest.t.sol";

import {Handler} from "./Handler.t.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {console} from "forge-std/console.sol";

contract InvariantTest is StdInvariant, BaseTest {
  Handler handler;

  function setUp() public override {
    // Deploy contracts and set up the test environment.
    BaseTest.setUp();

    // Set up the handler contract to interact with the DSCEngine and DSC contracts.
    handler = new Handler(dscEngine, dsc);

    // Set up the invariant test with the handler contract.
    targetContract(address(handler));

    // Selectors to target.
    bytes4[] memory handleSelectors = new bytes4[](3);
    handleSelectors[0] = handler.depositCollateral.selector;
    handleSelectors[1] = handler.redeemCollateral.selector;
    handleSelectors[2] = handler.mintDsc.selector;
    targetSelector(FuzzSelector({addr: address(handler), selectors: handleSelectors}));
  }

  // The total supply of collateral must be greater than the total DSC
  // The test will fail because the contract rever when user tries to redeem more than the total supply of collateral
  function invariant_totalSupplyOfCollateralMustBeGreaterThanTotalDSC() public view {
    uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(dscEngine));
    uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dscEngine));
    uint256 totalDscSupply = dsc.totalSupply();

    uint256 wethValue = dscEngine.getUsdValue(address(weth), totalWethDeposited);
    uint256 wbtcValue = dscEngine.getUsdValue(address(wbtc), totalWbtcDeposited);

    console.log("Total Weth Deposited :", totalWethDeposited);
    console.log("Weth Address :", address(weth));
    console.log("Total Wbtc Deposited :", totalWbtcDeposited);
    console.log("Wbtc Address :", address(wbtc));
    console.log("Total DSC Supply :", totalDscSupply);
    console.log("WETH Value :", wethValue);
    console.log("WBTC Value :", wbtcValue);

    uint256 totalMintsCalled = handler.mintsCalled();
    console.log("Total Mints Called :", totalMintsCalled);

    assert(wethValue + wbtcValue >= totalDscSupply);
  }
}
