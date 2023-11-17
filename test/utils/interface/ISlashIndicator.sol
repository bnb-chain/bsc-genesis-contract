// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface SlashIndicator {
    struct FinalityEvidence {
        VoteData voteA;
        VoteData voteB;
        bytes voteAddr;
    }

    struct VoteData {
        uint256 srcNum;
        bytes32 srcHash;
        uint256 tarNum;
        bytes32 tarHash;
        bytes sig;
    }

    event crashResponse();
    event failedFelony(address indexed validator, uint256 slashCount, bytes failReason);
    event failedMaliciousVoteSlash(bytes32 indexed voteAddrSlice, bytes failReason);
    event indicatorCleaned();
    event knownResponse(uint32 code);
    event maliciousVoteSlashed(bytes32 indexed voteAddrSlice);
    event paramChange(string key, bytes value);
    event unKnownResponse(uint32 code);
    event validatorSlashed(address indexed validator);

    function BIND_CHANNELID() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function DECREASE_RATE() external view returns (uint256);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function FELONY_THRESHOLD() external view returns (uint256);
    function GOVERNOR_ADDR() external view returns (address);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_FINALITY_SLASH_REWARD_RATIO() external view returns (uint256);
    function INIT_MALICIOUS_VOTE_SLASH_SCOPE() external view returns (uint256);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function MISDEMEANOR_THRESHOLD() external view returns (uint256);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKE_HUB_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function alreadyInit() external view returns (bool);
    function bscChainID() external view returns (uint16);
    function clean() external;
    function downtimeSlash(address validator, uint256 count) external;
    function enableMaliciousVoteSlash() external view returns (bool);
    function felonyThreshold() external view returns (uint256);
    function finalitySlashRewardRatio() external view returns (uint256);
    function getSlashIndicator(address validator) external view returns (uint256, uint256);
    function getSlashThresholds() external view returns (uint256, uint256);
    function handleAckPackage(uint8, bytes memory msgBytes) external;
    function handleFailAckPackage(uint8, bytes memory) external;
    function handleSynPackage(uint8, bytes memory) external returns (bytes memory);
    function indicators(address) external view returns (uint256 height, uint256 count, bool exist);
    function init() external;
    function maliciousVoteSlashScope() external view returns (uint256);
    function misdemeanorThreshold() external view returns (uint256);
    function previousHeight() external view returns (uint256);
    function sendFelonyPackage(address validator) external;
    function slash(address validator) external;
    function submitDoubleSignEvidence(bytes memory header1, bytes memory header2) external;
    function submitFinalityViolationEvidence(FinalityEvidence memory _evidence) external;
    function updateParam(string memory key, bytes memory value) external;
    function validators(uint256) external view returns (address);
}
