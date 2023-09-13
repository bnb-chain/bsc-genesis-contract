pragma solidity 0.6.4;

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    // Returns true if the index has been marked claimed.
    function isClaimed(bytes32 index) external view returns (bool);
    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(bytes32 tokenSymbol, bytes32 node, uint256 amount, bytes calldata ownerSignature, bytes calldata approvalSignature, bytes32[] calldata merkleProof) external;
    // registerToken register a token to the merkle distributor.
    function registerToken(bytes32 tokenSymbol, address contractAddr, uint256 decimals, uint256 amount, bytes calldata ownerSignature, bytes calldata approvalSignature) external;
    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(bytes32 index, address account, uint256 amount);
}
