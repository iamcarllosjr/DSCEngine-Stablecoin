// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*
 * @title OracleLib
 * @author 0XC4RL0S
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, the function will revert, and redener the DSCEngine unusalbe.
 */

/* @NOTE: Audit
*
https://github.com/Cyfrin/foundry-defi-stablecoin-cu/blob/main/audits/codehawks-08-05-2023.md#m-01-stalechecklatestrounddata-does-not-check-the-status-of-the-arbitrum-sequencer-in-chainlink-feeds
*
https://github.com/Cyfrin/foundry-defi-stablecoin-cu/blob/main/audits/codehawks-08-05-2023.md#m-02-dsc-protocol-can-consume-stale-price-data-or-cannot-operate-on-some-evm-chains
*
https://github.com/Cyfrin/foundry-defi-stablecoin-cu/blob/main/audits/codehawks-08-05-2023.md#m-03-chainlink-oracle-will-return-the-wrong-price-if-the-aggregator-hits-minanswer
 */

library OracleLib {
  uint256 private constant TIMEOUT = 3 hours;

  error StalePriceError();

  function stalePriceCheck(AggregatorV3Interface priceFeed)
    public
    view
    returns (uint80 roundId_, int256 answer_, uint256 startedAt_, uint256 updatedAt_, uint80 answeredInRound_)
  {
    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

    uint256 timeElapsed = block.timestamp - updatedAt;
    if (timeElapsed > TIMEOUT) {
      revert StalePriceError();
    }

    return (roundId, answer, startedAt, updatedAt, answeredInRound);
  }
}
