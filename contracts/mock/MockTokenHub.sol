pragma solidity 0.6.4;

import "../interface/ITokenHub.sol";

contract MockTokenHub is ITokenHub {

  bool panicBatchTransferOut;

  function getRelayFee() external override(ITokenHub) returns (uint256) {
    return (1e16);
  }

  function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external override(ITokenHub) returns(address){
    return address(0x0);
  }

  function getBep2SymbolByContractAddr(address contractAddr) external override(ITokenHub) returns(bytes32){
    return bytes32(0x0);
  }

  function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external override(ITokenHub){}

  function unbindToken(bytes32 bep2Symbol, address contractAddr) external override(ITokenHub){}

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


