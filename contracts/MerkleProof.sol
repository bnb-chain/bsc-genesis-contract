pragma solidity 0.5.16;

import "./Seriality/Memory.sol";

library MerkleProof {
    function validateMerkleProof(bytes32 appHash, string memory storeName, bytes memory key,
        bytes memory value, bytes memory proof) internal view returns (bool) {
        if (appHash == bytes32(0)) {
            return false;
        }

        // | storeName | key length | key | value length | value | appHash  | proof |
        // | 32 bytes  | 32 bytes   |     | 32 bytes     |       | 32 bytes |
        bytes memory input = new bytes(128+key.length+value.length+proof.length);

        uint256 ptr = Memory.dataPtr(input);

        bytes memory storeNameBytes = bytes(storeName);
        assembly {
            mstore(add(ptr, 0), mload(add(storeNameBytes, 32)))
        }

        uint256 src;
        uint256 length;

        // write key length and key to input
        ptr+=32;
        (src, length) = Memory.fromBytes(key);
        assembly {
            mstore(ptr, length)
        }
        ptr+=32;
        Memory.copy(src, ptr, length);

        // write value length and value to input
        ptr+=length;
        (src, length) = Memory.fromBytes(value);
        assembly {
            mstore(ptr, length)
        }
        ptr+=32;
        Memory.copy(src, ptr, length);

        // write appHash to input
        ptr+=length;
        assembly {
            mstore(ptr, appHash)
        }

        // write proof to input
        ptr+=32;
        (src,length) = Memory.fromBytes(proof);
        Memory.copy(src, ptr, length);

        length = input.length+32;

        uint256[1] memory result;
        assembly {
        // call validateMerkleProof precompile contract
        // Contract address: 0x65
            if iszero(staticcall(not(0), 0x65, input, length, result, 0x20)) {
                revert(0, 0)
            }
        }

        if (result[0] != 0x01) {
            return false;
        }

        return true;
    }
}