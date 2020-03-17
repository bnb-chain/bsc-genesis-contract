pragma solidity ^0.5.16;

import "../interface/ILightClient.sol";

contract LightClient is ILightClient{
  bool blockNotSynced;
  bool stateNotVerified;

  function isHeaderSynced(uint64 height) external view returns (bool){
    return !blockNotSynced;
  }

  function getAppHash(uint64 height) external view returns (bytes32) {
    return bytes32(0x0);
  }

  function getSubmitter(uint64 height) external view returns (address payable) {
    return address(0x0);
  }

  function setBlockNotSynced(bool notSynced) external{
    blockNotSynced = notSynced;
  }

  function setStateNotVerified(bool notVerified) external{
    stateNotVerified = notVerified;
  }
}