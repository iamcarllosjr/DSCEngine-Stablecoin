Neste ponto da criação de um contrato, algumas pessoas começam criando uma interface. Isso pode servir como uma lista clara e organizada dos métodos e funcionalidades que você espera incluir no contrato. Por enquanto, vamos adicionar os "esqueletos" das funções diretamente no contrato.

*Vamos considerar quais funções serão necessárias para o DSC.*

**Precisaremos de :**

- Depositar colateral e mintar o token DSC.
*É assim que os usuários adquirem o stablecoin: eles depositam colateral com valor maior do que o DSC mintado.*

- Resgatar o colateral em troca de DSC.
*Os usuários precisam ser capazes de devolver o DSC mintado ao protocolo em troca do colateral subjacente depositado.*

- Burn DSC

- Habilidade de liquidar uma conta
*Se o valor do colateral de um usuário cair rapidamente, ele precisará de uma maneira de corrigir rapidamente a colateralização do seu DSC.*

**Como nosso protocolo deve estar sempre sobrecolateralizado (mais collateral deve ser depositado do que DSC mintado), se o valor do collateral de um usuário cair abaixo do necessário para suportar o DSC mintado, ele poderá ser liquidado. A liquidação permite que outros usuários fechem uma posição "subcolateralizada".**

**Visualizar o healthFactor de uma conta :**

O *healthFactor* será definido como uma certa razão de colateralização que um usuário possui para o DSC que ele mintou. À medida que o valor do collateral de um usuário cai, o healthFactor também cai, caso nenhuma mudança no DSC seja feita. Se o healthFactor de um usuário cair abaixo de um limite definido, ele estará em risco de "liquidação".

Exemplo : Um protocolo garante 200% de colateralização, isso significa que o protocolo exige que o valor do collateral seja 2 vezes o valor do DSC mintado, garantindo que o sistema seja 200% colateralizado.

Em um protocolo, o valor 50 para COLLATERAL_FACTOR é usado para justificar que o protocolo é 200% colateralizado porque ele representa a porcentagem máxima de DSC mintado em relação ao valor do colateral depositado. Vamos detalhar como isso funciona:

- Formula : 
```javascript
Valor Máximo de DSC Mintado = (Valor do Colateral * COLLATERAL_FACTOR) / LIQUIDATION_PRECISION
```

Isso significa que o usuário pode mintar no máximo 50% do valor do colateral depositado.

*Como o COLLATERAL_FACTOR Garante 200% de Colateralização ?* 
- A colateralização é definida como a razão entre o valor do colateral e o valor do DSC mintado :

```javascript
Colateralização (%) = (Valor do Colateral / Valor do DSC Mintado) * 100
```

- Se o usuário pode mintar no máximo 50% do valor do colateral, a colateralização mínima será :

```javascript
Colateralização (%) = (100 / 50) * 100 = 200%
```

**Exemplo :**
  1. Configurações do Protocolo:
     - COLLATERAL_FACTOR = 50 (50%).
     - LIQUIDATION_PRECISION = 100.
     - LIQUIDATION_THRESHOLD = 80

  2. Usuário Deposita $100 em Colateral :
     - Valor máximo de DSC que pode ser mintado :

     ```javascript
        Valor Máximo de DSC Mintado = ($100 * 50) / 100 = $50
     ```

  3. Colateralização :
     - Colateralização (%) = ($100 / $50) * 100 = 200%.

**Resumo do Funcionamento do Protocolo**

Os usuários depositarão um collateral com valor maior do que o DSC que mintarem. Se o valor do colateral cair de forma que a posição se torne subcolateralizada, outro usuário poderá liquidar a posição pagando/queimando o DSC em troca do colateral da posição. Isso dará ao liquidante a diferença entre o valor do DSC e o valor do colateral como lucro, incentivando a segurança do protocolo.

Além do que foi descrito acima, precisaremos de funções básicas como mint/deposit para dar aos usuários mais controle sobre suas posições e o healthFactor.

# Funções 

### depositCollateral()
A função depositCollateral será o ponto inicial para os usuários interagirem com o protocolo. Para depositar colateral, os usuários precisarão do endereço do tipo de colateral que estão depositando (wETH ou wBTC) e da quantidade que desejam depositar.

**Considerações:**

*Sanitização de parâmetros:* Precisamos garantir que os valores passados sejam válidos (ex.: evitar address(0) ou números negativos).
Uso de modificadores: Para evitar repetição de verificações em várias funções, utilizaremos modificadores.

*Proteção contra reentrância:* Usaremos o modificador nonReentrant da OpenZeppelin para evitar ataques de reentrância.

*Mapeamento para rastrear depósitos:*

*Padrão CEI* (Checks, Effects, Interactions): Garantiremos que a função siga o padrão CEI para evitar vulnerabilidades.

*Eventos:* Emitiremos eventos sempre que o estado do contrato for alterado.

### mintDsc()
A função mintDsc permitirá que os usuários mintem o stablecoin. Antes de mintar, verificaremos se o valor do colateral do usuário suporta a quantidade de DSC que ele deseja mintar.

**Fluxo de Chamadas**

*Função _healthFactor :*

Essa função calcula o health factor (fator de saúde) de um usuário, que é a razão entre o valor do colateral ajustado e o DSC mintado.
Ela chama _getTotalDscMintedAndCollateralValueOfUser para obter:
O total de DSC mintado pelo usuário (totalDscMinted).
O valor total do colateral depositado pelo usuário em USD (collateralValueInUsd).

```solidity
    function _healthFactor(address user_) private view returns (uint256 healthFactor) {
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getTotalDscMintedAndCollateralValueOfUser(user_);
    ...
}
```

*Função _getTotalDscMintedAndCollateralValueOfUser :*

Essa função retorna:
O total de DSC mintado pelo usuário (dscMinted[user_]).
O valor total do colateral depositado pelo usuário em USD, calculado por _getCollateralValueInUsd.

```solidity
    function _getTotalDscMintedAndCollateralValueOfUser(address user_)
    private
    view
    returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
{
    totalDscMinted = dscMinted[user_];
    collateralValueInUsd = _getCollateralValueInUsd(user_);
}
```

*Função _getCollateralValueInUsd :*

Essa função percorre todos os tokens de colateral permitidos (collateralTokens) e calcula o valor total depositado pelo usuário em USD.
Para cada token, ela usa o preço do feed da Chainlink (getUsdValue) para converter o valor depositado em USD.

```solidity
    function _getCollateralValueInUsd(address user) internal view returns (uint256 collateralValueInUsd) {
    for (uint256 i = 0; i < collateralTokens.length; i++) {
        address token = collateralTokens[i];
        uint256 amount = collateralDeposited[user][token];
        if (amount > 0) {
            collateralValueInUsd += getUsdValue(token, amount);
        }
    }
}
```

*Função getUsdValue :*

```solidity
    function getUsdValue(address token_, uint256 amount_) public view returns (uint256 usdValue) {
    AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress[token_]);
    (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
    if (block.timestamp - updatedAt >= 86400 /* 24 hours */) {
        revert StalePriceFeed();
    }
    usdValue = ((uint256(price) * FEED_PRECISION) * amount_) / PRECISION;
}
```

Essa função usa o preço do feed da Chainlink para calcular o valor em USD de uma quantidade específica de um token.

*Verificação do Colateral Depositado*

A função _getCollateralValueInUsd é responsável por verificar o colateral depositado pelo usuário. Se o usuário não tiver depositado nenhum colateral, o valor retornado será 0.

Caso o usuário não tenha colateral:
  - _getCollateralValueInUsd retorna 0.
  - _getTotalDscMintedAndCollateralValueOfUser retorna collateralValueInUsd = 0 e o valor de totalDscMinted (quantidade de DSC mintado pelo usuário).
  - _healthFactor calcula o fator de saúde com base nesses valores.

*Impacto no Health Factor*

Se o usuário não tiver DSC mintado (totalDscMinted == 0):
  - _healthFactor retorna type(uint256).max (infinito), indicando que o usuário não está em risco de liquidação.
  - Se o usuário não tiver colateral depositado (collateralValueInUsd == 0):
  - O cálculo do health factor resultará em 0, indicando que o usuário está subcolateralizado e em risco de liquidação.

*Passos:*

- Atualizar o saldo mapeado do usuário para refletir o valor mintado.
- Verificar o healthFactor do usuário usando a função _revertIfHealthFactorIsBroken.
- Utilizar feeds de preço da Chainlink para calcular o valor do colateral em USD.
- Health Factor (Fator de Saúde)
O healthFactor será calculado como a razão entre o valor ajustado do colateral e o total de DSC mintado. Se o healthFactor for menor que 1, o usuário estará em risco de liquidação.

### redeemCollateral()
Os usuários poderão resgatar seu colateral, mas apenas se o resgate não quebrar o healthFactor. 

**A função :**

- Verificará se o resgate solicitado não causa a quebra do healthFactor.
- Transferirá os tokens solicitados do protocolo para o usuário.
- Atualizará o estado interno do contrato e emitirá um evento.

### burnDsc()
Os usuários poderão queimar seu DSC para corrigir sua colateralização. A função transferirá os tokens para address(0) e atualizará o saldo mapeado do usuário.

principal uso da função burnDsc nesse protocolo é permitir que os usuários queimem seus tokens DSC para resgatar suas garantias (collateral). Isso é essencial para manter o protocolo sobrecolateralizado e garantir que os usuários possam recuperar os ativos que depositaram como garantia.

No protocolo, os usuários depositam colateral (como WETH ou WBTC) e mintam DSC (um stablecoin). Para resgatar o colateral depositado, eles precisam devolver os DSC que mintaram, queimando-os no processo. Isso reduz a quantidade de dívida no sistema e libera o colateral correspondente.

### redeemCollateralForDsc()
Combina as funcionalidades de redeemCollateral e burnDsc em uma única transação para facilitar a saída do protocolo.

### liquidate()
Se o valor do colateral de um usuário cair abaixo do limite necessário para suportar o DSC mintado, ele poderá ser liquidado. 

**A função :**

- Verificará se o usuário está elegível para liquidação (health factor < 1) com base no LIQUIDATION_THRESHOLD.
- Queimará o DSC do liquidante.
- Transferirá o colateral correspondente ao liquidante.
- Atualizará os saldos internos.

----
### Recapitulação do Projeto.

Neste projeto, aprendemos a construir um protocolo descentralizado que utiliza colateral para mintar um stablecoin (DSC). 

**Exploramos conceitos fundamentais como :**

*Colateralização e Mintagem :*

- Como os usuários podem depositar colateral e mintar um stablecoin com base no valor do colateral.

*Fator de Saúde (Health Factor) :*

- A métrica que garante que o protocolo permaneça sobrecolateralizado e seguro.

*Over-colateralização :* 
completar cyfrin, 

Com o COLLATERAL_FACTOR definido como 50, isso significa que o protocolo exige que o valor do colateral seja pelo menos 200% do valor do DSC mintado. Em outras palavras, o protocolo é 100% over-colateralizado.

Definição do COLLATERAL_FACTOR :

O COLLATERAL_FACTOR é definido como 50, o que representa 50%.
Isso significa que o valor do DSC mintado não pode exceder 50% do valor do colateral depositado.

Cálculo da Colateralização :

Para calcular a colateralização, usamos a fórmula :
```javascript
Colateralização (%) = (Valor do Colateral / Valor do DSC Mintado) * 100
```

Como o DSC mintado pode ser no máximo 50% do valor do colateral, a colateralização mínima será :
```javascript
Colateralização (%) = (100 / 50) * 100 = 200%
```

Over-Colateralização:

A over-colateralização é a diferença entre a colateralização mínima exigida e 100% (colateralização exata).
Neste caso:
```javascript
Over-Colateralização (%) = 200% - 100% = 100%
```

Conclusão :
- Com o COLLATERAL_FACTOR em 50, o protocolo exige que o sistema seja 100% over-colateralizado, ou seja, o valor do colateral deve ser o dobro do valor do DSC mintado. Isso garante a segurança do protocolo, mesmo em caso de flutuações no valor do colateral.

*Liquidação:*

- O mecanismo que protege o protocolo contra posições subcolateralizadas, incentivando outros usuários a liquidar essas posições.

*Padrões de Segurança:*

- Uso de modificadores, proteção contra reentrância e o padrão CEI para garantir a segurança do contrato.

*Interação com Feeds de Preço :*

- Utilizamos feeds da Chainlink para calcular o valor do colateral em USD.

*Este projeto demonstra como criar um protocolo robusto e seguro, com foco em colateralização, estabilidade e incentivos para os participantes.*