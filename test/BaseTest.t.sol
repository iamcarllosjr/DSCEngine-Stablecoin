// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DeployDSCEngine} from "../script/DSCEngine/DSCEngine.s.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DescentralizedStablecoin} from "../src/DescentralizedStablecoin.sol";
import {ERC20Mock} from "./Mocks/ERC20Mock.sol";
import {Test} from "forge-std/Test.sol";

abstract contract BaseTest is Test {
  /*//////////////////////////////////////////////////////////////////////////
                                   VARIABLES
  //////////////////////////////////////////////////////////////////////////*/
  address user = makeAddr("user");
  uint256 AMOUNT_COLLATERAL = 0.075 ether; // $150 USD

  /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
  //////////////////////////////////////////////////////////////////////////*/
  DeployDSCEngine dscEngineDeployer;
  DSCEngine dscEngine;
  DescentralizedStablecoin dsc;
  HelperConfig helperConfig;
  address weth;
  address ethUsdPriceFeed;
  address wbtc;
  address wbtcPriceFeed;

  /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
  function setUp() public virtual {
    // Deploy the base test contracts.
    dscEngineDeployer = new DeployDSCEngine();
    (dscEngine, helperConfig, dsc) = dscEngineDeployer.run();
    (weth, wbtc, ethUsdPriceFeed, wbtcPriceFeed,) = helperConfig.activeNetworkConfig();

    // ERC20Mock weth = new ERC20Mock(1000e8);
    // ERC20Mock wbtc = new ERC20Mock(1000e8);
  }

  // This modifier is used to mint WETH and approve the DSCEngine to spend it (Unit Tests)
  modifier mintAndApproveERC20() {
    vm.startPrank(user);
    // Mint WETH to the user
    ERC20Mock(weth).mint(user, AMOUNT_COLLATERAL);
    // Approve the DSCEngine to spend WETH
    ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
    vm.stopPrank();
    _;
  }

  // This modifier is used to the depositCollateral only, not minting DSC (Unit Tests)
  modifier depositCollateral() {
    vm.startPrank(user);
    dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
    vm.stopPrank();
    _;
  }
}
