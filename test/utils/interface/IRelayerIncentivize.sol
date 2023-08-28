pragma solidity ^0.8.10;

interface RelayerIncentivize {
    event distributeCollectedReward(
        uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer
    );
    event paramChange(string key, bytes value);
    event rewardToRelayer(address relayer, uint256 amount);

    function BIND_CHANNELID() external view returns (uint8);
    function CALLER_COMPENSATION_DENOMINATOR() external view returns (uint256);
    function CALLER_COMPENSATION_MOLECULE() external view returns (uint256);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function HEADER_RELAYER_REWARD_RATE_DENOMINATOR() external view returns (uint256);
    function HEADER_RELAYER_REWARD_RATE_MOLECULE() external view returns (uint256);
    function INCENTIVIZE_ADDR() external view returns (address);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function MAXIMUM_WEIGHT() external view returns (uint256);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function ROUND_SIZE() external view returns (uint256);
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
    function addReward(address headerRelayerAddr, address packageRelayer, uint256 amount, bool fromSystemReward)
        external
        returns (bool);
    function alreadyInit() external view returns (bool);
    function bscChainID() external view returns (uint16);
    function calculateHeaderRelayerWeight(uint256 count) external pure returns (uint256);
    function calculateTransferRelayerWeight(uint256 count) external pure returns (uint256);
    function callerCompensationDenominator() external view returns (uint256);
    function callerCompensationMolecule() external view returns (uint256);
    function claimRelayerReward(address relayerAddr) external;
    function collectedRewardForHeaderRelayer() external view returns (uint256);
    function collectedRewardForTransferRelayer() external view returns (uint256);
    function countInRound() external view returns (uint256);
    function dynamicExtraIncentiveAmount() external view returns (uint256);
    function headerRelayerAddressRecord(uint256) external view returns (address);
    function headerRelayerRewardRateDenominator() external view returns (uint256);
    function headerRelayerRewardRateMolecule() external view returns (uint256);
    function headerRelayersSubmitCount(address) external view returns (uint256);
    function init() external;
    function packageRelayerAddressRecord(uint256) external view returns (address);
    function packageRelayersSubmitCount(address) external view returns (uint256);
    function relayerRewardVault(address) external view returns (uint256);
    function roundSequence() external view returns (uint256);
    function updateParam(string memory key, bytes memory value) external;
}
