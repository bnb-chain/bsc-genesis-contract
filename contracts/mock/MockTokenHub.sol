pragma solidity 0.6.4;

import "../interface/ITokenHub.sol";

contract MockTokenHub is ITokenHub {

  bool panicBatchTransferOut;

  function handleBindPackage(bytes calldata, bytes calldata, uint64, uint64)
  external override(ITokenHub) returns (bool) {
    return true;
  }

  function handleTransferInPackage( bytes calldata, bytes calldata, uint64, uint64)
  external override(ITokenHub) returns (bool) {
    return true;
  }

  function handleRefundPackage( bytes calldata, bytes calldata, uint64, uint64)
  external override(ITokenHub) returns (bool) {
    return true;
  }

  function transferOut(address, address, uint256, uint256, uint256)
  external override(ITokenHub) payable returns (bool) {
    return true;
  }

  /* solium-disable-next-line */
  function batchTransferOut(address[] calldata, uint256[] calldata, address[] calldata,
    address, uint256, uint256) external override(ITokenHub) payable returns (bool) {
    require(!panicBatchTransferOut, "panic in batchTransferOut");
    return true;
  }

  function setPanicBatchTransferOut(bool doPanic)external{
    panicBatchTransferOut = doPanic;
  }
}


