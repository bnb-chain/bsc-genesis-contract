pragma solidity 0.5.16;

library MockMerkleProof {
    function validateMerkleProof(bytes32 appHash, string memory storeName, bytes memory key,
        bytes memory value, bytes memory proof) internal view returns (bool) {
        return true;
    }
}