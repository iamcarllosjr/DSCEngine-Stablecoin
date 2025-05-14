// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../../../src/DSCEngine.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {ERC20Mock} from "../../Mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../Mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";

contract DSCEngineLiquidateTest is BaseTest {
  address liquidator = makeAddr("liquidator");
  uint256 amountCollateral = 0.075 ether;

  uint256 constant LIQUIDATION_BPS = 10000; // 100%
  uint256 constant LIQUIDATION_BONUS_BPS = 1000; // 10%

  function setUp() public virtual override {
    BaseTest.setUp();
  }

  /* Esses são os cálculos principais envolvidos até o ponto de liquidação de um usuário. Em resumo :

  1. Calcular o Health Factor.

  2. Se o HF for menor que 1, calcular a dívida a ser liquidada.

  3. Ajustar a dívida a ser liquidada de acordo com o colateral disponível.

  4. Permitir que o liquidante cubra a dívida do usuário.
  */

  function test_Liquidate() public mintAndApproveERC20 {
    // Iniciar o "prank" para o liquidator
    vm.startPrank(liquidator);

    // Mintar tokens para o liquidator
    ERC20Mock(weth).mint(liquidator, amountCollateral);
    uint256 liquidatorBalance = ERC20Mock(weth).balanceOf(liquidator);
    console.log("Liquidator WETH balance: ", liquidatorBalance);
    ERC20Mock(weth).approve(address(dscEngine), liquidatorBalance);

    // Liquidator deposita colateral e mint DSC
    dscEngine.depositCollateralAndMintDsc(weth, liquidatorBalance);
    uint256 liquidatorDscBalance = dscEngine.dscMinted(liquidator);
    console.log("Liquidator DSC balance: ", liquidatorDscBalance);

    // Aprovar o DSC Engine para gastar os DSC do liquidator
    dsc.approve(address(dscEngine), liquidatorDscBalance);
    vm.stopPrank();

    // Usuário deposita colateral e mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, amountCollateral);

    uint256 userBalance = dscEngine.dscMinted(user);
    console.log("Saldo em DSC do usuario no protocol: ", userBalance);

    // Calcular o Health Factor antes da atualização do preço
    uint256 healthFactorBeforeUpdatePrice = dscEngine.getHealthFactor(user);
    console.log("User health factor before update price: ", healthFactorBeforeUpdatePrice);

    // Atualizar o preço do colateral para deixar o usuário "under-collateralized"
    int256 ethUsdUpdatedPrice = 1200e8; // 1 ETH = $1200
    MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

    // Calcular o novo Health Factor
    uint256 healthFactorAfterUpdatePrice = dscEngine.getHealthFactor(user);
    console.log("User health factor after update price (Apto a ser liquidado): ", healthFactorAfterUpdatePrice);


    // Liquidar a dívida
    vm.prank(liquidator);
    dscEngine.liquidate(weth, user, 50e18);

    // Verificar o saldo do liquidator após a liquidação
    uint256 liquidatorBalanceAfter = ERC20Mock(weth).balanceOf(liquidator); // .068750000000000000
    console.log("Liquidator WETH balance after liquidation: ", liquidatorBalanceAfter);

    // Verificar o saldo do usuário após a liquidação
    uint256 userBalanceAfter = dscEngine.dscMinted(user);
    console.log("Saldo em DSC do usuario apos ser liquidado (Apenas subtraido do protocolo): ", userBalanceAfter);

    // Verificar o saldo de colateral do usuário após a liquidação
    uint256 userCollateralBalanceAfter = ERC20Mock(weth).balanceOf(user);
    console.log("User WETH balance after liquidation: ", userCollateralBalanceAfter);

    // Verificar o saldo de DSC do liquidator após a liquidação
    uint256 liquidatorDscBalanceAfter = dsc.balanceOf(liquidator);
    console.log("Liquidator DSC balance after liquidation (Quantidade que deve ter apos cobrir o debito): ", liquidatorDscBalanceAfter);

    // Verificar o healthFactor do user
    uint256 userHealthFactorAfter = dscEngine.getHealthFactor(user);
    console.log("User health factor after liquidation: ", userHealthFactorAfter);
}


  function test_Revert_Liquidate_With_Zero_Amount() public mintAndApproveERC20 {
    uint256 debtToLiquidate = 0;

    // 1. Deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    // 1. Liquidate the user
    vm.startPrank(liquidator);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.AmountShouldBeMoreThanZero.selector, debtToLiquidate));
    dscEngine.liquidate(weth, user, debtToLiquidate);
    vm.stopPrank();
  }

  function test_Revert_When_User_Cannot_Be_Liquidate() public mintAndApproveERC20 {
    // 1. Deposit collateral and mint DSC
    vm.prank(user);
    dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL);

    uint256 totalDscMinted = dscEngine.dscMinted(user);
    console.log("DSC minted: ", totalDscMinted);

    uint256 healthFactor = dscEngine.getHealthFactor(user);
    console.log("Health factor: ", healthFactor);

    // 1. Liquidate the user
    vm.startPrank(liquidator);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.UserCannotBeLiquidated.selector, user, healthFactor));
    dscEngine.liquidate(weth, user, totalDscMinted);
    vm.stopPrank();
  }
}
