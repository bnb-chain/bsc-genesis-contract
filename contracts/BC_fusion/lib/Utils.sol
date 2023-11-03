// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library Utils {
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function bytesToUint256(bytes memory _input, uint256 _offset) internal pure returns (uint256 _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }
}
