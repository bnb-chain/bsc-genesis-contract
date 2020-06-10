pragma solidity 0.6.4;

import "../interface/ITokenHub.sol";

contract MockTokenHub is ITokenHub {

  bool panicBatchTransferOut;

  function getRelayFee() external override(ITokenHub) returns (uint256, uint256) {
    return (0, 0);
  }

  function transferOut(address, address, uint256, uint64)
  external override(ITokenHub) payable returns (bool) {
    return true;
  }

  /* solium-disable-next-line */
  function batchTransferOutBNB(address[] calldata, uint256[] calldata, address[] calldata,
    uint64) external override(ITokenHub) payable returns (bool) {
    require(!panicBatchTransferOut, "panic in batchTransferOut");
    return true;
  }

  function setPanicBatchTransferOut(bool doPanic)external{
    panicBatchTransferOut = doPanic;
  }
}


