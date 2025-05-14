// SPDX-License-Identifier: MIT

/*
 * @title: DSCEngine
 * @author: 0XC4RL0S
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
*/

pragma solidity 0.8.25;

import {DescentralizedStablecoin} from "./DescentralizedStablecoin.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract DSCEngine is ReentrancyGuard {
  /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                               VARIABLES
  //////////////////////////////////////////////////////////////*/
  DescentralizedStablecoin public immutable dsc;

  uint256 private constant FEED_PRECISION = 1e10;
  uint256 private constant PRECISION = 1e18;
  uint256 private constant COLLATERAL_FACTOR = 50; // 200% collaterization
  // CollateralFactor = 50% (Higher Margin of Safety)
  uint256 private constant LIQUIDATION_THRESHOLD = 80; // 80% (Lower Margin of Safety)
  uint256 private constant LIQUIDATION_PRECISION = 100;
  uint256 private constant MIN_HEALTH_FACTOR = 1e18;
  uint256 private constant LIQUIDATION_BONUS_BPS = 1000; // 10% bonus
  uint256 private constant LIQUIDATION_BPS = 10_000;

  address[] public collateralTokens;

  mapping(address token => bool allowed) public allowTokenAddress;
  mapping(address collateralToken => address priceFeed) public priceFeedAddress;
  mapping(address user => mapping(address tokenAddress => uint256 amount)) public collateralDeposited;
  mapping(address user => uint256 dscMinted) public dscMinted;

  /*//////////////////////////////////////////////////////////////
                                 EVENTS
  //////////////////////////////////////////////////////////////*/
  event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);
  event CollateralRedeemed(address indexed redeemFrom, address redeemTo, address indexed tokenAddress, uint256 indexed amount);
  event DebugCalculation(uint256 amount, uint256 priceWithDecimals, uint256 tokenAmount);

  /*//////////////////////////////////////////////////////////////
                                 ERROS
  //////////////////////////////////////////////////////////////*/
  error AmountShouldBeMoreThanZero(uint256 amount_);
  error HealthFactorIsBroken(uint256 healthFactor_);
  error HealthFactorNotImproved(uint256 healthFactor_);
  error UserCannotBeLiquidated(address user_, uint256 healthFactor_);
  error NoDebtToCalculateHealthFactor(address user_, uint256 amount_);
  error NotAllowedTokenAddress(address tokenAddress_);
  error MismatchArraysLength(address[] tokenAddress_, address[] priceFeedAddress_);
  error TransferFailed();
  error StalePriceFeed();
  error InsufficientCollateral(uint256 amountToRedeem_, uint256 collateralDepositedAmount_);
  error NotEnoughCollateral(uint256 collateralDepositedAmount_);

  /*//////////////////////////////////////////////////////////////
                               MODIFIERS
  //////////////////////////////////////////////////////////////*/
  modifier moreThanZero(uint256 amount_) {
    if (amount_ == 0) {
      revert AmountShouldBeMoreThanZero(amount_);
    }
    _;
  }

  modifier isAllowedTokenAddress(address tokenAddress_) {
    if (!allowTokenAddress[tokenAddress_]) {
      revert NotAllowedTokenAddress(tokenAddress_);
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  constructor(address[] memory tokenAddresses_, address[] memory priceFeedAddresses_) {
    // USD priceFeed addresses
    if (tokenAddresses_.length != priceFeedAddresses_.length) {
      revert MismatchArraysLength(tokenAddresses_, priceFeedAddresses_);
    }

    // Allow token addresses
    for (uint256 i = 0; i < tokenAddresses_.length; i++) {
      // Avoid duplicity of Price Feed addresses.
      require(priceFeedAddress[tokenAddresses_[i]] == address(0), "Collateral token was already set");
      allowTokenAddress[tokenAddresses_[i]] = true;
      priceFeedAddress[tokenAddresses_[i]] = priceFeedAddresses_[i];
      collateralTokens.push(tokenAddresses_[i]);
    }

    dsc = new DescentralizedStablecoin();
  }

  /*  
   * @notice: This function is used to deposit collateral and mint dsc at the same time.
   * This is how users acquire the stablecoin, they deposit collateral greater than the value of the `DSC` minted
   * @param collateralTokenAddress_: The address of the collateral token to be deposited.
   * @param collateralAmount_: The amount of collateral to be deposited.
   * @param amountDscToMint: The amount of DSC to be minted.
   * @dev: The amount of collateral deposited must be greater than the amount of DSC minted.
  */
  function depositCollateralAndMintDsc(address collateralTokenAddress_, uint256 collateralAmount_) external {
    depositCollateral(collateralTokenAddress_, collateralAmount_);
    uint256 amountDscToMint = getMaxDscToMint(msg.sender);
    mintDsc(amountDscToMint);
  }

  /*
   * @notice: This function is used to deposit collateral into the protocol.
   * @param collateralTokenAddress_: The address of the collateral token to be deposited.
   * @param collateralAmount_: The amount of collateral to be deposited.
   * We need to save the amount of collateral deposited by each user.
  */
  function depositCollateral(address collateralTokenAddress_, uint256 collateralAmount_)
    public
    moreThanZero(collateralAmount_)
    isAllowedTokenAddress(collateralTokenAddress_)
  {
    collateralDeposited[msg.sender][collateralTokenAddress_] += collateralAmount_;
    emit CollateralDeposited(msg.sender, collateralTokenAddress_, collateralAmount_);

    // Transfer the collateral from the user to the contract
    SafeTransferLib.safeTransferFrom(collateralTokenAddress_, msg.sender, address(this), collateralAmount_);
  }

  /* 
   * @notice: This function is used to withdraw collateral and burn dsc at the same time.
   * Users will need to be able to return DSC to the protocol in exchange for their underlying collateral
   * @param collateralTokenAddress_: The address of the collateral token to be redeemed.
   * @param collateralAmount_: The amount of collateral to be redeemed.
  */
  function redeemCollateralForDsc(address collateralTokenAddress_, uint256 collateralAmount_) public {
    // NOTE: IMPROVING - Removing the input "AmountdSctoburn_" so that the user does not try to burn more DSC than it can
    // And keep the HF broken and end up with the transaction reversed.

    // NOTE: IMPROVING - Function to calculate how many DSC burn in relation to the amount of guarantees to be rescued.
    uint256 dscToBurn = calculateDscToBurnFromCollateral(msg.sender, collateralTokenAddress_, collateralAmount_);

    if (dscToBurn == 0) {
      revert();
    }

    // Burn
    burnDsc(dscToBurn);

    // Redeem
    _redeemCollateral(collateralTokenAddress_, collateralAmount_, msg.sender, msg.sender);
  }

  /*
   * @notice: This function is used to calculate the amount of dsc to burn for a given collateral amount.
   * @param user_: The address of the user.
   * @param collateralTokenAddress_: The address of the collateral token to be redeemed.
   * @param collateralAmount_: The amount of collateral to be redeemed.
   * @return dscToBurn: The amount of dsc to burn.
  */
  function calculateDscToBurnFromCollateral(address user_, address collateralTokenAddress_, uint256 collateralAmount_)
    public
    view
    returns (uint256 dscToBurn)
  {
    uint256 collateralValueInUsd = getUsdValue(collateralTokenAddress_, collateralAmount_);
    uint256 totalCollateralValueInUsd = _getCollateralValueInUsd(user_);
    uint256 totalDscMinted = dscMinted[user_];

    uint256 newCollateralValueInUsd = totalCollateralValueInUsd - collateralValueInUsd;

    // Calculates the DSC required to maintain the healthfactor> = 1
    uint256 adjustedCollateralValue = (newCollateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

    // Always burns DSC proportional to the collateral rescued
    if (adjustedCollateralValue < totalDscMinted) {
      dscToBurn = totalDscMinted - adjustedCollateralValue;
    } else {
      // Burn proportional to the value of the redeemed collateral
      dscToBurn = (totalDscMinted * collateralValueInUsd) / totalCollateralValueInUsd;
    }
  }

  /*
   * @notice: This function is used to redeem collateral.
   * @param collateralTokenAddress_: The address of the collateral token to be redeemed.
   * @param collateralAmount_: The amount of collateral to be redeemed.
   * @dev: If the user minted DSC, he needs to burn it before redeeming collateral.
  */
  function redeemCollateral(address collateralTokenAddress_, uint256 collateralAmount_) public moreThanZero(collateralAmount_) {
    // Check if the user has minted DSC.
    // If the user has minted DSC, they need to burn it before redeeming collateral.
    uint256 dscMintedByUser = dscMinted[msg.sender];

    // NOTE: IMPROVING - Direct the user to the ransom if it has DSC piped.
    if (dscMintedByUser > 0) {
      // Handle DSC burning and collateral redemption
      redeemCollateralForDsc(collateralTokenAddress_, collateralAmount_);
      return; // Prevent further execution
    }

    // Redeem
    _redeemCollateral(collateralTokenAddress_, collateralAmount_, msg.sender, msg.sender);

    // Checking the HF
    _revertIfHealthFactorIsBroken(msg.sender);
  }

  /*
   * @notice: This function is used to mint dsc.
   * Users will need to be able to return DSC to the protocol in exchange for their underlying collateral
   * @notice: You can only mint DSC if you hav enough collateral
   * @param amountDscToMint_: The amount of DSC to be minted.
   * @dev: The amount of collateral deposited must be greater than the amount of DSC minted.
  */

  function mintDsc(uint256 amountDscToMint_) public moreThanZero(amountDscToMint_) {
    // Calculates the maximum of SC that can be assembled
    uint256 healthFactorSimulated = _simulateHealthFactor(msg.sender, amountDscToMint_);

    // Revert if the requested value exceeds the maximum allowed
    if (healthFactorSimulated < MIN_HEALTH_FACTOR) {
      revert HealthFactorIsBroken(healthFactorSimulated);
    }

    dscMinted[msg.sender] += amountDscToMint_;

    // Mint the DSC from the contract to the user
    dsc.mint(msg.sender, amountDscToMint_);
  }

  /*
   * @notice: If the value of a user's collateral quickly falls,
   * users will need a way to quickly rectify the collateralization of their `DSC`.
   * @notice: To redeem the collateral they deposited, 
   * they need to return the DSCs they lied to, burning them in the process.
  */
  function burnDsc(uint256 amountDscToBurn_) public moreThanZero(amountDscToBurn_) {
    _burnDSC(msg.sender, msg.sender, amountDscToBurn_);
  }

  /*
   * @notice: This function is used to get the maximum amount of DSC that can be minted.
   * @param user_: The address of the user.
   * @return maxDscToMint: The maximum amount of DSC that can be minted.
   * @dev: The maximum amount of DSC that can be minted is the value of the collateral in USD
   * divided by the liquidation threshold.
  */
  function getMaxDscToMint(address user_) public view returns (uint256 maxDscToMint) {
    (uint256 totalDscMinted, uint256 collateralValue) = _getTotalDscMintedAndCollateralValueOfUser(user_);

    if (collateralValue == 0) {
      revert NotEnoughCollateral(collateralValue);
    }

    // Loan-to-Value (LTV) "COLLATERAL_FACTOR"
    // The maximum amount that can be borrowed relative to the collateral’s value.
    // For example, a 50% LTV allows borrowing 50% of the collateral’s value.
    uint256 maxMintable = (collateralValue * COLLATERAL_FACTOR) / LIQUIDATION_PRECISION;
    // `collateralValueInUsd` already on a scale of 1e18

    if (maxMintable < totalDscMinted) {
      revert HealthFactorIsBroken(maxMintable);
    }

    maxDscToMint = maxMintable - totalDscMinted;
  }

  /*
   * @notice: This function is used to liquidate a user for being undercollateralized. (with insufficient guarantee)
   * @notice: Because our protocol must always be over-collateralized (more collateral must be deposited then `DSC` is minted), 
   * @notice: If a user's collateral value falls below what's required to support their minted `DSC`, they can be `liquidated`.
   * @notice: Liquidators receive a portion of the collateral as a reward for liquidating the user.
   * @param collateralTokenAddress_: The address of the collateral token to be liquidated.
   * @param user_: The address of the user to be liquidated.
   * @param debtToCover_: The amount of debt to be covered.
  */
  function liquidate(
    address collateralTokenAddress_,
    address user_,
    uint256 debtToCover_
) external moreThanZero(debtToCover_) nonReentrant {
    uint256 oldHealthFactor = _healthFactor(user_);

    if (oldHealthFactor >= MIN_HEALTH_FACTOR) {
        revert UserCannotBeLiquidated(user_, oldHealthFactor);
    }

    // 1. Calcula o valor equivalente do colateral que cobre a dívida
    uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralTokenAddress_, debtToCover_);

    // 2. Aplica o bônus de liquidação (10%)
    uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS_BPS) / LIQUIDATION_BPS;

    // 3. Total de colateral que o liquidante vai receber
    uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

    // 4. Resgata o colateral do usuário e envia ao liquidator
    _redeemCollateral(collateralTokenAddress_, totalCollateralToRedeem, user_, msg.sender);

    // 5. Queima DSC do liquidante (ele cobre a dívida do usuário)
    _burnDSC(user_, msg.sender, debtToCover_);

    // 7. Verifica se a saúde do usuário melhorou após a liquidação
    uint256 newHealthFactor = _healthFactor(user_);
    if (newHealthFactor <= oldHealthFactor) {
        revert HealthFactorNotImproved(newHealthFactor); // .640000000000000000 .160000000000000000
    }
}

  /*
   * @notice: This function is used to check the health factor of a user.
   * @param user_: The address of the user.
   * @dev: The health factor is the ratio of the value of the collateral to the value of the DSC minted.
   * @dev: If the health factor falls below a certain threshold, the user will be at risk of liquidation.
  */
  function _revertIfHealthFactorIsBroken(address user_) internal view {
    uint256 healthFactor = _healthFactor(user_);
    // Check health factor (do they have enough collateral ?)
    // Revert if the health factor is less than 1
    if (healthFactor < MIN_HEALTH_FACTOR) {
      revert HealthFactorIsBroken(healthFactor);
    }
  }

  /*
   * @notice: This function is used to calculate the health factor of a user.
   * @param user_: The address of the user.
   * @return healthFactor: The health factor of the user.
   * @dev: The health factor is the ratio of the value of the collateral to the value of the DSC minted.
   * @dev: If the health factor falls below a certain threshold, the user will be at risk of liquidation.
  */
  function _healthFactor(address user_) private view returns (uint256 healthFactor) {
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getTotalDscMintedAndCollateralValueOfUser(user_);

    // Caso o usuário ainda não tenha mintado DSC, teriamos problema na divisão de calculo no passo 2.
    if (totalDscMinted == 0) {
      return type(uint256).max;
    }

    // Step 1: Calculate the threshold-adjusted collateral
    uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
    // $5e8 * 80 / 100 = 4e8

    // Step 2: Calculate the final health factor
    healthFactor = (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
  }

  function _simulateHealthFactor(address user_, uint256 simulatedDscMinted) internal view returns (uint256 healthFactor) {
    uint256 maxDscToMintOfUser = getMaxDscToMint(user_);

    // Calculates the simulated health factor
    healthFactor = (maxDscToMintOfUser * PRECISION) / simulatedDscMinted;
  }

  /*
   * @notice: redeem guarantees from one address to another. (Either by an user or a liquidator)
   * @param collateralTokenAddress_: The address of collateralToken to redeem.
   * @param collateralAmount_: The amount of collateral to be redeemed.
   * @param from_: The address of the user who is redeeming the collateral.
   * @param to_: The address of the user who is receiving the collateral.
  */
  function _redeemCollateral(address collateralTokenAddress_, uint256 collateralAmountToRedeem_, address from_, address to_) internal {
    // Checks
    uint256 collateralDepositedAmount = getCollateralBalanceOfUser(from_, collateralTokenAddress_);

    if (collateralAmountToRedeem_ > collateralDepositedAmount) {
      revert InsufficientCollateral(collateralAmountToRedeem_, collateralDepositedAmount);
    }

    // Effects
    collateralDeposited[from_][collateralTokenAddress_] -= collateralAmountToRedeem_;
    emit CollateralRedeemed(from_, to_, collateralTokenAddress_, collateralAmountToRedeem_);

    // Transfer the collateral from the contract to `to_`
    SafeTransferLib.safeTransfer(collateralTokenAddress_, to_, collateralAmountToRedeem_);
  }

  /*
   * @notice: This function is used to burn dsc.
   * @param onBeHalf_: The address of the user who is burning the dsc.
   * @param dscFrom_: The address of the user who is burning the dsc.
   * @param amountToBurn_: The amount of dsc to be burned.
   * @dev: Used by a liquidator to burn dsc from the user.
  */
  function _burnDSC(address onBeHalf_, address dscFrom_, uint256 amountToBurn_) internal {
    dscMinted[onBeHalf_] -= amountToBurn_;

    // Transfer the DSC from the `dscFrom_` to the contract
    SafeTransferLib.safeTransferFrom(address(dsc), dscFrom_, address(this), amountToBurn_);

    // Burn the DSC
    dsc.burn(amountToBurn_);
  }

  /*
   * @notice: This function is used to get the total amount of DSC minted and the value of the collateral in USD.
   * @param user_: The address of the user.
   * @return totalDscMinted: The total amount of DSC minted by the user.
   * @return collateralValueInUsd: The value of the collateral in USD.
  */
  function _getTotalDscMintedAndCollateralValueOfUser(address user_)
    private
    view
    returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
  {
    totalDscMinted = dscMinted[user_];
    collateralValueInUsd = _getCollateralValueInUsd(user_);
  }

  /*
   * @notice: This function is used to get the value of the collateral in USD.
   * @param user: The address of the user.
   * @return collateralValueInUsd: The value of the collateral in USD.
   * @dev: Duplicate addresses would double the amount deposited by the user. 
  */
  function _getCollateralValueInUsd(address user) internal view returns (uint256 collateralValueInUsd) {
    // Loop through each collateral token, get the amount they have deposited, and map it to the price feed, to get the value in USD
    for (uint256 i = 0; i < collateralTokens.length; i++) {
      address token = collateralTokens[i];
      uint256 amount = collateralDeposited[user][token];
      if (amount > 0) {
        // Get the price of the collateral token in USD
        collateralValueInUsd = collateralValueInUsd + getUsdValue(token, amount);
      }
    }
  }

  /*
   * @notice: This function is used to get the USD value of a token amount.
   * @param token_: The address of the token.
   * @param amount_: The amount of the token.
   * @return usdValue: The USD value of the token.
  */
  function getUsdValue(address token_, uint256 amount_) public view returns (uint256 usdValue) {
    if (token_ == address(0)) {
      revert NotAllowedTokenAddress(token_);
    }

    AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress[token_]);
    (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
    // price (ETH/USD 2000e8)

    uint8 decimals = priceFeed.decimals();
    uint256 priceWithDecimals = (uint256(price) * 1e18) / (10 ** decimals);
    // 2000.000000000000000000

    // Verifiyng if the price feed is stale
    if (block.timestamp - updatedAt >= 86_400 /* 24 hour */ ) {
      revert StalePriceFeed();
    }

    usdValue = (priceWithDecimals * amount_) / PRECISION;
    // 2000e8 * 0.075e18 = 15000000000 (150e8)
    // usdValue 150.00000000 = $150
  }

  /*
   * @notice: This function is used to get the amount of collateral from token amount.
   * @param collateralToken_: The address of the collateral token.
   * @param amount_: The amount of tokens
   * @return amountInUsd: The amount of collateral.
  */
  function getTokenAmountFromUsd(address collateralToken_, uint256 amount_) public view returns (uint256 tokenAmount) {
    if (collateralToken_ == address(0)) {
      revert NotAllowedTokenAddress(collateralToken_);
    }
    // Assumptions $2000/ETH
    // We have $100/ETH
    // 100 / 2000 = 0.05 ETH
    AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress[collateralToken_]);
    (, int256 price,,,) = priceFeed.latestRoundData();
    // NOTE: We would need an oracle like fallback if Chainlink failed

    uint8 decimals = priceFeed.decimals();
    uint256 priceWithDecimals = (uint256(price) * 1e18) / (10 ** decimals);

    // amount / price
    tokenAmount = (amount_ * PRECISION) / priceWithDecimals;
  }

  /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /*
   * @notice: This function is used to get the health factor of a user.
   * @notice: The health factor is the ratio of the value of the collateral to the value of the DSC minted.
   * @param user_: The address of the user.
   * @return healthFactor: The health factor of the user.
   * @dev: If the health factor falls below a certain threshold, the user will be at risk of liquidation.
  */
  function getHealthFactor(address user_) external view returns (uint256 healthFactor) {
    healthFactor = _healthFactor(user_);
  }

  /*
   * @notice: This function return true if the token address is allowed to be used as collateral.
   * @param tokenAddress_: The address of the collateral token.
   * @return allowed: True if the token address is allowed to be used as collateral.
  */
  function getAllowedTokenAddress(address tokenAddress_) external view returns (bool) {
    return allowTokenAddress[tokenAddress_];
  }

  /*
   * @notice: This function return the totalDscMinted and CollateralValue of a user
   * @param user: The address of the user.
   * @return totalDscMinted: The total amount of DSC minted by the user.
   * @return collateralValue: The value of the collateral in USD.
  */
  function getAccountInformation(address user) external view returns (uint256 totalDscMinted, uint256 collateralValue) {
    (totalDscMinted, collateralValue) = _getTotalDscMintedAndCollateralValueOfUser(user);
  }

  /*
   * @notice: This function is used to get the collateral tokens used by.
   * @return collateralTokens_: The array of collateral tokens.
  */
  function getCollateralTokens() external view returns (address[] memory collateralTokens_) {
    collateralTokens_ = collateralTokens;
  }

  /*
   * @notice: This function is used to get the amount of collateral deposited by a user.
   * @param user_: The address of the user.
   * @param token_: The address of the collateral token.
   * @return balanceOfUser_: The amount of collateral deposited by the user.
  */
  function getCollateralBalanceOfUser(address user_, address token_) public view returns (uint256 balanceOfUser_) {
    balanceOfUser_ = collateralDeposited[user_][token_];
  }

  /*
   * @notice: This function is used to get the price feed address of a token.
   * @param token_: The address of the token.
   * @return priceFeed_: The address of the price feed.
  */
  function getCollateralTokenPriceFeed(address token_) external view returns (address priceFeed_) {
    priceFeed_ = priceFeedAddress[token_];
  }
}
