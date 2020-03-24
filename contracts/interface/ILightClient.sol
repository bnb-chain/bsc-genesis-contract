pragma solidity ^0.5.16;

interface ILightClient {

  function isHeaderSynced(uint64 height) external view returns (bool);

  function getAppHash(uint64 height) external view returns (bytes32);

  function getSubmitter(uint64 height) external view returns (address payable);

}