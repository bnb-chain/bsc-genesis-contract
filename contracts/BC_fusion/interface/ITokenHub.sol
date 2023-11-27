// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ITokenHub {
  function unlock(bytes32 tokenSymbol, address recipient, uint256 amount)
    external;
  function cancelAirdrop(bytes32 tokenSymbol, address attacker) external;
}
