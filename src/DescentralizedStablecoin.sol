// SPDX-License-Identifier: MIT

/*
 * @title: DecentralizedStablecoin
 * @author: 0XC4RL0S
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stablecoin system.
*/

pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DescentralizedStablecoin is ERC20, Ownable {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
  event Mint(address indexed to, uint256 indexed amount);
  event Burn(address indexed from, uint256 indexed amount);

  /*//////////////////////////////////////////////////////////////
                                 ERROS
    //////////////////////////////////////////////////////////////*/
  error InvalidBalanceOrAmount(uint256 balance, uint256 amount);
  error InvalidAddressOrAmount(address to, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
  constructor() ERC20("DescentralizedStablecoin", "DSC") Ownable(msg.sender) {}
  // Como somente o implantador do contrato pode mintar, não há necessidade de passar o endereço do dono como parâmetro.
  // Para uma opçõa mais vantajosa, (simplicidade no deploy, Aclopamento, Controle total, e evitar passos extras como transferir o
  // propriedade)
  // DescentralizedStablecoin pode ser implantado no contructor do DSCEngine
  // dsc = new DescentralizedStablecoin();

  function mint(address to_, uint256 mintAmount_) external onlyOwner {
    if (to_ == address(0) || mintAmount_ <= 0) {
      revert InvalidAddressOrAmount(to_, mintAmount_);
    }

    _mint(to_, mintAmount_);
    emit Mint(to_, mintAmount_);
  }

  function burn(uint256 burnAmount_) external onlyOwner {
    uint256 balance = balanceOf(msg.sender);

    if (balance == 0 || burnAmount_ <= 0) {
      revert InvalidBalanceOrAmount(balance, burnAmount_);
    }

    _burn(msg.sender, burnAmount_);
    emit Burn(msg.sender, burnAmount_);
  }
}
