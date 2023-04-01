pragma solidity 0.6.4;

import "../interface/ITokenHub.sol";

contract MockTokenHub is ITokenHub {

  bool panicBatchTransferOut;

  function getMiniRelayFee() external view override(ITokenHub) returns (uint256) {
    return (1e16);
  }

  function getContractAddrByBEP2Symbol(bytes32) external view override(ITokenHub) returns(address) {
    return address(0x0);
  }

  function getBep2SymbolByContractAddr(address) external view override(ITokenHub) returns(bytes32) {
    return bytes32(0x0);
  }

  function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external override(ITokenHub) {}

  function unbindToken(bytes32 bep2Symbol, address contractAddr) external override(ITokenHub) {}

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

  function withdrawStakingBNB(uint256 amount) external override returns(bool) {
    address STAKING_CONTRACT_ADDR = address(0x0000000000000000000000000000000000002001);
    require(msg.sender == STAKING_CONTRACT_ADDR, "only staking system contract can call this function");
    if (amount != 0) {
      payable(STAKING_CONTRACT_ADDR).transfer(amount);
    }
    return true;
  }

  function cancelTransferIn(address, address) override external {
    address CROSS_CHAIN_CONTRACT_ADDR = address(0x0000000000000000000000000000000000002000);
    require(msg.sender == CROSS_CHAIN_CONTRACT_ADDR, "only cross chain contract can call this function");
  }
}
