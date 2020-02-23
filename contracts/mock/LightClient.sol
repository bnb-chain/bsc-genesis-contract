pragma solidity ^0.5.16;

import "../interface/ILightClient.sol";

contract LightClient is ILightClient{
  bool blockSynced;
  bool stateVerified;

  function isBlockSynced(uint256) external returns (bool){
    return blockSynced;
  }

  constructor()public{
    blockSynced = true;
    stateVerified = true;
  }

  function validateMerkleProof(uint256, string calldata, bytes calldata, bytes calldata, bytes calldata) external view returns (bool){
    return stateVerified;
  }

  function setBlockSynced(bool synced) external{
    blockSynced = synced;
  }

  function setStateVerified(bool verified) external{
    stateVerified = verified;
  }
}