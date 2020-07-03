pragma solidity 0.6.4;

import "../interface/ILightClient.sol";

contract MockLightClient is ILightClient{
  bool blockNotSynced;
  bool stateNotVerified;

  function isHeaderSynced(uint64) external override(ILightClient) view returns (bool) {
    return !blockNotSynced;
  }

  function getAppHash(uint64) external override(ILightClient) view returns (bytes32) {
    return bytes32(0x0);
  }

  function init() public {}

  function getSubmitter(uint64) external override(ILightClient) view returns (address payable) {
    return address(0x0);
  }

  function setBlockNotSynced(bool notSynced) external{
    blockNotSynced = notSynced;
  }

  function setStateNotVerified(bool notVerified) external{
    stateNotVerified = notVerified;
  }
}