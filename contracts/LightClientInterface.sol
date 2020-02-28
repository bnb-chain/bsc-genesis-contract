pragma solidity 0.5.16;

interface LightClientInterface {

    function validateMerkleProof(uint64 height, string calldata storeName, bytes calldata key, bytes calldata value, bytes calldata proof) external view returns (bool);

    function isHeaderSynced(uint64 height) external view returns (bool);

    function getSubmitter(uint64 height) external view returns (address);
}