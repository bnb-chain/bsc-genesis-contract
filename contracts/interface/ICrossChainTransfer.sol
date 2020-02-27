pragma solidity ^0.5.15;

interface ICrossChainTransfer {
  function batchCrossChainTransfer(address[]calldata,uint256[]calldata, address[]calldata, address, uint256)
  external payable;
}


