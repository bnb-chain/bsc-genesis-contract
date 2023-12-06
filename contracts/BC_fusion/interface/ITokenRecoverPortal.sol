// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

// TokenRecoverPortal anyone to recover a token if they exist in a Beacon Chain.
interface ITokenRecoverPortal {
    // Returns the merkle root of the merkle tree containing account balances available to recover.
    function merkleRoot() external view returns (bytes32);
    // Returns the address of the contract that is allowed to confirm the recover.
    function approvalAddress() external view returns (address);
    // Returns the address of the contract that is allowed to pause the recover.
    function assetProtector() external view returns (address);
    // Returns true if the index has been marked recovered.
    function isRecovered(bytes32 index) external view returns (bool);
    // recover the given amount of the token to the given address. Reverts if the inputs are invalid.
    function recover(
        bytes32 tokenSymbol,
        uint256 amount,
        bytes calldata ownerPubKey,
        bytes calldata ownerSignature,
        bytes calldata approvalSignature,
        bytes32[] calldata merkleProof
    ) external;
    // Cancel the user token recover request by the assetProtector.
    function cancelTokenRecover(bytes32 tokenSymbol, address recipient) external;
}
