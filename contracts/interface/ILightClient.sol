pragma solidity ^0.5.16;

interface ILightClient {
  function isBlockSynced(uint256) external returns (bool);

  function validateMerkleProof(uint256, string calldata, bytes calldata, bytes calldata, bytes calldata)
  external view returns (bool);
}