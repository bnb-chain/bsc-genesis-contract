// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

library Utils {
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function bytesToAddress(bytes memory _input, uint256 _offset) internal pure returns (address _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }

    function bytesToUint256(bytes memory _input, uint256 _offset) internal pure returns (uint256 _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }

    function bytesToUint64(bytes memory _input, uint256 _offset) internal pure returns (uint64 _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }

    function bytesToBytes32(bytes memory _input, uint256 _offset) internal pure returns (bytes32 _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }

    function bytesConcat(bytes memory data, bytes memory _bytes, uint256 index, uint256 len) internal pure {
        for (uint256 i; i < len; ++i) {
            data[index++] = _bytes[i];
        }
    }

    function bytesToHex(bytes memory buffer, bool prefix) internal pure returns (string memory) {
        // Fixed buffer size for hexadecimal conversion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        if (prefix) {
            return string(abi.encodePacked("0x", converted));
        }
        return string(converted);
    }
}
