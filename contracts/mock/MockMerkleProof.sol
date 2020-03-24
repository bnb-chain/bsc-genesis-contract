pragma solidity 0.6.4;

library MockMerkleProof {
    function validateMerkleProof(bytes32 , string memory , bytes memory,
        bytes memory , bytes memory ) internal pure returns (bool) {
        return true;
    }
}