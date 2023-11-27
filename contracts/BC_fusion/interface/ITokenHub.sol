pragma solidity 0.8.17;

interface ITokenHub {
  function unlock(bytes32 tokenSymbol, address recipient, uint256 amount)
    external payable;
}
