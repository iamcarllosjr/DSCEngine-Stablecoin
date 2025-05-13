// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {ERC20Mock} from "../test/Mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/Mocks/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
  uint8 public constant DECIMALS = 8;
  int256 public constant ETH_USD_PRICE = 2000e8;
  int256 public constant BTC_USD_PRICE = 1000e8;
  uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

  struct HelperConfigNetwork {
    address weth;
    address wbtc;
    address wethPriceFeed;
    address wbtcPriceFeed;
    uint256 deployKey;
  }

  HelperConfigNetwork public activeNetworkConfig;

  constructor() {
    if (block.chainid == 11_155_111) {
      // Sepolia
      activeNetworkConfig = getSepoliaEthConfig();
    } else if (block.chainid == 31_337) {
      // Anvil
      activeNetworkConfig = getOrCreateAnvilEthConfig();
    } else {
      revert("Unsupported network");
    }
  }

  function getSepoliaEthConfig() public view returns (HelperConfigNetwork memory sepoliaNetworkConfig) {
    sepoliaNetworkConfig = HelperConfigNetwork({
      weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
      wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
      wethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
      wbtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
      deployKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
    });
  }

  function getOrCreateAnvilEthConfig() public returns (HelperConfigNetwork memory anvilNetworkConfig) {
    if (activeNetworkConfig.weth != address(0)) {
      return activeNetworkConfig;
    }

    vm.startBroadcast();
    // Deploying WETH and WBTC price feeds
    MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
    ERC20Mock weth = new ERC20Mock(1000e8);

    MockV3Aggregator wbtcPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
    ERC20Mock wbtc = new ERC20Mock(1000e8);
    vm.stopBroadcast();

    anvilNetworkConfig = HelperConfigNetwork({
      weth: address(weth),
      wbtc: address(wbtc),
      wethPriceFeed: address(ethUsdPriceFeed),
      wbtcPriceFeed: address(wbtcPriceFeed),
      deployKey: ANVIL_PRIVATE_KEY
    });
  }
}
