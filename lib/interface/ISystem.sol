pragma solidity ^0.8.10;

interface System {
    function BIND_CHANNELID() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
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
}
