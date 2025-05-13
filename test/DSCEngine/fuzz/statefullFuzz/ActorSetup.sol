// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// // Importing the required contracts for fuzz testing (Nosso contrato BaseTest já tem os contratos que precisamos)
// // import {DSCEngine} from "../../../../src/DSCEngine.sol";
// // import {DescentralizedStablecoin} from "../../../../src/DescentralizedStablecoin.sol";

// import {ActorManagement} from "./ActorManagement.sol";

// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import {BaseTest} from "../../../BaseTest.t.sol";
// import {Test} from "forge-std/Test.sol";

// /*
//  * @title ActorManagement
//  * @author 0XC4RL0S
//  * @notice This contract containing the actor configuration.
//  */

// contract ActorSetup is ActorManagement, Test {
//   constructor() {
//     deploy();
//   }

//   function deploy() internal {
//     // Deploy contracts and set up the environment
//     // ------ CODE ------ //

//     // Set up actors
//     setupActor();
//   }

//   function setupActor() internal {
//     // Set up the actors with a starting balance
//     for (uint256 i = 0; i < actors.length; i++) {
//       address actor = actors[i];

//       // Approve all to the dscEngine contract
//       vm.startPrank(actor);
//       // The actor will have balance of all tokens which are used in the dscEngine
//       ERC20Mock(weth).mint(actor, STARTING_BALANCE);
//       ERC20Mock(wbtc).mint(actor, STARTING_BALANCE);

//       // Approve the dscEngine to spend the tokens
//       ERC20Mock(weth).approve(address(dscEngine), STARTING_BALANCE);
//       ERC20Mock(wbtc).approve(address(dscEngine), STARTING_BALANCE);
//       vm.stopPrank();
//     }
//   }

// function redeemCollateral(uint256 collateralSeed_, uint256 amountCollateral_, uint256 actorIndexSeed) public useActor(actorIndexSeed) {
//     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed_);
//     uint256 amountCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(currentActor, address(collateral));
//     amountCollateral_ = bound(amountCollateral_, 0, amountCollateralToRedeem);
//     if (amountCollateral_ == 0) {
//       return;
//     }
//     console.log("Amount Collateral to redeem:", amountCollateral_);

//     vm.startPrank(currentActor);
//     dscEngine.redeemCollateral(address(collateral), amountCollateral_);
//     vm.stopPrank();
//   }

//   function mintDsc(uint256 amountDsc_, uint256 actorIndexSeed) public useActor(actorIndexSeed) {
//     uint256 maxDscToMint = dscEngine.getMaxDscToMint(currentActor);
//     if (amountDsc_ == 0) {
//       return;
//     }
//     console.log("Max DSC to mint:", maxDscToMint);
//     amountDsc_ = bound(amountDsc_, 1, maxDscToMint);

//     vm.startPrank(currentActor);
//     dscEngine.mintDsc(amountDsc_);
//     vm.stopPrank();
//     mintsCalled++;
//   }

// }
