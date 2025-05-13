// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DescentralizedStablecoin} from "../../src/DescentralizedStablecoin.sol";
import {Script} from "forge-std/Script.sol";

contract DeployDescentralizedStablecoin is Script {
  // address public owner;

  function run() external returns (DescentralizedStablecoin) {
    vm.startBroadcast(msg.sender);
    DescentralizedStablecoin dsc = new DescentralizedStablecoin();
    vm.stopBroadcast();
    return dsc;
  }
}
