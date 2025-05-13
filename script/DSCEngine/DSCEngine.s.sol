// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DescentralizedStablecoin} from "../../src/DescentralizedStablecoin.sol";

import {DeployDescentralizedStablecoin} from "../DescentralizedStablecoin/DescentralizedStablecoin.s.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

contract DeployDSCEngine is Script {
  DescentralizedStablecoin dsc;
  DeployDescentralizedStablecoin deployer;
  address owner = makeAddr("owner");

  function run() external returns (DSCEngine, HelperConfig, DescentralizedStablecoin) {
    // Set up the collateral tokens and their price feeds
    HelperConfig helperConfig = new HelperConfig();
    (address weth, address wbtc, address wethPriceFeed, address wbtcPriceFeed, uint256 deployerKey) =
      helperConfig.activeNetworkConfig();

    // Set up the token addresses and price feed addresses
    address[] memory tokenAddresses;
    address[] memory priceFeedAddresses;

    tokenAddresses = new address[](2);
    tokenAddresses[0] = weth;
    tokenAddresses[1] = wbtc;

    priceFeedAddresses = new address[](2);
    priceFeedAddresses[0] = wethPriceFeed;
    priceFeedAddresses[1] = wbtcPriceFeed;

    vm.startBroadcast(owner);
    DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses);
    dsc = dscEngine.dsc();
    vm.stopBroadcast();
    return (dscEngine, helperConfig, dsc);
  }
}
