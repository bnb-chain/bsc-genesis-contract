// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface CrossChain {
    event ProposalSubmitted(
        bytes32 indexed proposalTypeHash,
        address indexed proposer,
        uint128 quorum,
        uint128 expiredAt,
        bytes32 contentHash
    );
    event Reopened(address indexed executor);
    event SuccessChallenge(address indexed challenger, uint64 packageSequence, uint8 channelId);
    event Suspended(address indexed executor);
    event addChannel(uint8 indexed channelId, address indexed contractAddr);
    event crossChainPackage(
        uint16 chainId,
        uint64 indexed oracleSequence,
        uint64 indexed packageSequence,
        uint8 indexed channelId,
        bytes payload
    );
    event enableOrDisableChannel(uint8 indexed channelId, bool isEnable);
    event paramChange(string key, bytes value);
    event receivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
    event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
    event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
    event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);

    function ACK_PACKAGE() external view returns (uint8);
    function BC_FUSION_CHANNELID() external view returns (uint8);
    function BIND_CHANNELID() external view returns (uint8);
    function CANCEL_TRANSFER_PROPOSAL() external view returns (bytes32);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_CHAIN_KEY_PREFIX() external view returns (uint256);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function EMERGENCY_PROPOSAL_EXPIRE_PERIOD() external view returns (uint256);
    function EMPTY_CONTENT_HASH() external view returns (bytes32);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function FAIL_ACK_PACKAGE() external view returns (uint8);
    function GOVERNOR_ADDR() external view returns (address);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function GOV_TOKEN_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_BATCH_SIZE() external view returns (uint256);
    function INIT_CANCEL_TRANSFER_QUORUM() external view returns (uint16);
    function INIT_REOPEN_QUORUM() external view returns (uint16);
    function INIT_SUSPEND_QUORUM() external view returns (uint16);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function REOPEN_PROPOSAL() external view returns (bytes32);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKE_CREDIT_ADDR() external view returns (address);
    function STAKE_HUB_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function STORE_NAME() external view returns (string memory);
    function SUSPEND_PROPOSAL() external view returns (bytes32);
    function SYN_PACKAGE() external view returns (uint8);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TIMELOCK_ADDR() external view returns (address);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TOKEN_RECOVER_PORTAL_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function alreadyInit() external view returns (bool);
    function batchSizeForOracle() external view returns (uint256);
    function bscChainID() external view returns (uint16);
    function cancelTransfer(address tokenAddr, address attacker) external;
    function challenge(
        uint64[4] memory params,
        bytes memory payload0,
        bytes memory payload1,
        bytes memory proof0,
        bytes memory proof1
    ) external;
    function challenged(bytes32) external view returns (bool);
    function channelHandlerContractMap(uint8) external view returns (address);
    function channelReceiveSequenceMap(uint8) external view returns (uint64);
    function channelSendSequenceMap(uint8) external view returns (uint64);
    function channelSyncedHeaderMap(uint8) external view returns (uint64);
    function emergencyProposals(bytes32)
        external
        view
        returns (uint16 quorum, uint128 expiredAt, bytes32 contentHash);
    function encodePayload(
        uint8 packageType,
        uint256 relayFee,
        bytes memory msgBytes
    ) external pure returns (bytes memory);
    function handlePackage(
        bytes memory payload,
        bytes memory proof,
        uint64 height,
        uint64 packageSequence,
        uint8 channelId
    ) external;
    function init() external;
    function isRelayRewardFromSystemReward(uint8) external view returns (bool);
    function isSuspended() external view returns (bool);
    function oracleSequence() external view returns (int64);
    function previousTxHeight() external view returns (uint256);
    function quorumMap(bytes32) external view returns (uint16);
    function registeredContractChannelMap(address, uint8) external view returns (bool);
    function reopen() external;
    function sendSynPackage(uint8 channelId, bytes memory msgBytes, uint256 relayFee) external;
    function suspend() external;
    function txCounter() external view returns (uint256);
    function updateParam(string memory key, bytes memory value) external;
}
