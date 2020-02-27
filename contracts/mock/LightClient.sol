pragma solidity ^0.5.15;

import "../interface/ILightClient.sol";

contract LightClient is ILightClient{
  bool blockNotSynced;
  bool stateNotVerified;

  function isBlockSynced(uint256) external returns (bool){
    return !blockNotSynced;
  }

  function validateMerkleProof(uint256, string calldata, bytes calldata, bytes calldata, bytes calldata) external view returns (bool){
    return !stateNotVerified;
  }

  function setBlockNotSynced(bool notSynced) external{
    blockNotSynced = notSynced;
  }

  function setStateNotVerified(bool notVerified) external{
    stateNotVerified = notVerified;
  }
}