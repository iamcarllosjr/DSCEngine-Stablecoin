// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {ActorManagement} from "./ActorManagement.sol";
import {DSCEngine} from "../../../../src/DSCEngine.sol";
import {DescentralizedStablecoin} from "../../../../src/DescentralizedStablecoin.sol";

import {MockV3Aggregator} from "../../../Mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

contract Handler is Test {
  DSCEngine public dscEngine;
  DescentralizedStablecoin public dsc;
  ERC20Mock weth;
  ERC20Mock wbtc;
  MockV3Aggregator public ethUsdPriceFeed;

  uint256 public mintsCalled;

  // Actors are the addresses to be used as senders.
  address internal constant ACTOR_1 = address(0x10000);
  address internal constant ACTOR_2 = address(0x20000);
  address internal constant ACTOR_3 = address(0x30000);
  address internal constant ACTOR_4 = address(0x40000);

  // List of all actors
  address[] internal actors = [ACTOR_1, ACTOR_2, ACTOR_3, ACTOR_4];

  // The current actor is the one that will be used for the next transaction
  address internal currentActor;

  uint256 public constant MAX_DEPOSIT = type(uint96).max;

  constructor(DSCEngine dsce_, DescentralizedStablecoin dsc_) {
    dscEngine = dsce_;
    dsc = dsc_;

    address[] memory collateralTokens = dscEngine.getCollateralTokens();
    weth = ERC20Mock(collateralTokens[0]);
    wbtc = ERC20Mock(collateralTokens[1]);

    ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
  }

  modifier useActor(uint256 actorIndexSeed) {
    currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
    vm.startPrank(currentActor);
    _;
    vm.stopPrank();
  }

  function depositCollateral(uint256 collateralSeed_, uint256 amountCollateral_, uint256 actorIndexSeed_) public useActor(actorIndexSeed_) {
    // Pre-conditions
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed_);
    amountCollateral_ = bound(amountCollateral_, 1, MAX_DEPOSIT);

    ERC20Mock(collateral).mint(currentActor, amountCollateral_);
    ERC20Mock(collateral).approve(address(dscEngine), amountCollateral_);

    // Actions
    dscEngine.depositCollateral(address(collateral), amountCollateral_);
  }

  function redeemCollateral(uint256 collateralSeed_, uint256 amountCollateral_, uint256 actorIndexSeed_) public useActor(actorIndexSeed_) {
    // Pre-conditions
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed_);
    uint256 collateralDeposited = dscEngine.getCollateralBalanceOfUser(currentActor, address(collateral));
    if (collateralDeposited == 0) {
      return;
    }
    amountCollateral_ = bound(amountCollateral_, 1, collateralDeposited);

    // approve DSCEngine to spend the dsc
    dsc.approve(address(dscEngine), type(uint256).max);

    // Actions
    dscEngine.redeemCollateral(address(collateral), amountCollateral_);
  }

  function mintDsc(uint256 amountDsc_, uint256 actorIndexSeed_) public useActor(actorIndexSeed_) {
    // Pre-conditions
    uint256 maxDscMint = dscEngine.getMaxDscToMint(currentActor);
    if (maxDscMint == 0) { // permitir que seja 0 ?
      return;
    }
    amountDsc_ = bound(amountDsc_, 1, maxDscMint);

    // CONFIGURAR FUNÇÃO PARA MINTAR DSC CORRETAMENTE

    // Actions
    dscEngine.mintDsc(amountDsc_);
    mintsCalled++;
  }

  // Helper function
  function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
    // Use the seed to determine which collateral to use
    // For example, if the seed is even, use WETH; if odd, use WBTC
    if (collateralSeed % 2 == 0) {
      return weth;
    }
    return wbtc;
  }

  // THIS BREAKS OUR INVARIANT TEST SUITE!!!
  // function updateCollateralPrice(uint96 newPrice) public {
  //   int256 newPriceInt = int256(uint256(newPrice));
  //   ethUsdPriceFeed.updateAnswer(newPriceInt);
  // }
}