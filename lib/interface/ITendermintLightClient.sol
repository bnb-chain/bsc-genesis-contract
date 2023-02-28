pragma solidity ^0.8.10;

interface TendermintLightClient {
    event initConsensusState(uint64 initHeight, bytes32 appHash);
    event paramChange(string key, bytes value);
    event syncConsensusState(uint64 height, uint64 preValidatorSetChangeHeight, bytes32 appHash, bool validatorChanged);

    function BIND_CHANNELID() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_CONSENSUS_STATE_BYTES() external view returns (bytes memory);
    function INIT_REWARD_FOR_VALIDATOR_SER_CHANGE() external view returns (uint256);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
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
    function chainID() external view returns (bytes32);
    function getAppHash(uint64 height) external view returns (bytes32);
    function getChainID() external view returns (string memory);
    function getSubmitter(uint64 height) external view returns (address);
    function init() external;
    function initialHeight() external view returns (uint64);
    function isHeaderSynced(uint64 height) external view returns (bool);
    function latestHeight() external view returns (uint64);
    function lightClientConsensusStates(uint64)
        external
        view
        returns (
            uint64 preValidatorSetChangeHeight,
            bytes32 appHash,
            bytes32 curValidatorSetHash,
            bytes memory nextValidatorSet
        );
    function rewardForValidatorSetChange() external view returns (uint256);
    function submitters(uint64) external view returns (address);
    function syncTendermintHeader(bytes memory header, uint64 height) external returns (bool);
    function updateParam(string memory key, bytes memory value) external;
}
