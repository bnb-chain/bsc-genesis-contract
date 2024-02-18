// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface TokenRecoverPortal {
    error AlreadyPaused();
    error AlreadyRecovered();
    error ApprovalAddressNotInitialized();
    error InBlackList();
    error InvalidApprovalSignature();
    error InvalidOwnerPubKeyLength();
    error InvalidOwnerSignatureLength();
    error InvalidProof();
    error InvalidValue(string key, bytes value);
    error MerkleRootAlreadyInitiated();
    error MerkleRootNotInitialized();
    error NotPaused();
    error OnlyCoinbase();
    error OnlyProtector();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error TokenRecoverPortalPaused();
    error UnknownParam(string key, bytes value);

    event BlackListed(address indexed target);
    event Initialized(uint8 version);
    event ParamChange(string key, bytes value);
    event Paused();
    event ProtectorChanged(address indexed oldProtector, address indexed newProtector);
    event Resumed();
    event TokenRecoverRequested(bytes ownerAddress, bytes32 tokenSymbol, address account, uint256 amount);
    event UnBlackListed(address indexed target);

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function SOURCE_CHAIN_ID() external view returns (string memory);
    function STAKING_CHANNELID() external view returns (uint8);
    function addToBlackList(address account) external;
    function approvalAddress() external view returns (address);
    function blackList(address) external view returns (bool);
    function cancelTokenRecover(bytes32 tokenSymbol, address attacker) external;
    function initialize() external;
    function isPaused() external view returns (bool);
    function isRecovered(bytes32 node) external view returns (bool);
    function merkleRoot() external view returns (bytes32);
    function merkleRootAlreadyInit() external view returns (bool);
    function pause() external;
    function recover(
        bytes32 tokenSymbol,
        uint256 amount,
        bytes memory ownerPubKey,
        bytes memory ownerSignature,
        bytes memory approvalSignature,
        bytes32[] memory merkleProof
    ) external;
    function removeFromBlackList(address account) external;
    function resume() external;
    function updateParam(string memory key, bytes memory value) external;
}
