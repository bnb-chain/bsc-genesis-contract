pragma solidity ^0.8.10;

interface MockLightClient {
    function getAppHash(uint64) external view returns (bytes32);
    function getSubmitter(uint64) external view returns (address);
    function init() external;
    function isHeaderSynced(uint64) external view returns (bool);
    function setBlockNotSynced(bool notSynced) external;
    function setStateNotVerified(bool notVerified) external;
}
