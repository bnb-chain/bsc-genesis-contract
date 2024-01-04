// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface RelayerHub {
    event managerAdded(address _addedManager);
    event managerRemoved(address _removedManager);
    event paramChange(string key, bytes value);
    event relayerAddedProvisionally(address _relayer);
    event relayerUnRegister(address _relayer);
    event relayerUpdated(address _from, address _to);

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function BIND_CHANNELID() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOVERNOR_ADDR() external view returns (address);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function GOV_TOKEN_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_DUES() external view returns (uint256);
    function INIT_REQUIRED_DEPOSIT() external view returns (uint256);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKE_CREDIT_ADDR() external view returns (address);
    function STAKE_HUB_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TIMELOCK_ADDR() external view returns (address);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TOKEN_RECOVER_PORTAL_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function WHITELIST_1() external view returns (address);
    function WHITELIST_2() external view returns (address);
    function acceptBeingRelayer(address manager) external;
    function alreadyInit() external view returns (bool);
    function bscChainID() external view returns (uint16);
    function init() external;
    function isManager(address managerAddress) external view returns (bool);
    function isProvisionalRelayer(address relayerAddress) external view returns (bool);
    function isRelayer(address relayerAddress) external view returns (bool);
    function removeManagerByHimself() external;
    function unregister() external;
    function updateParam(string memory key, bytes memory value) external;
    function updateRelayer(address relayerToBeAdded) external;
    function whitelistInit() external;
    function whitelistInitDone() external view returns (bool);
}
