pragma solidity ^0.8.10;

interface RelayerHub {
    event managerAdded(address _addedManager);
    event managerRemoved(address _removedManager);
    event paramChange(string key, bytes value);
    event relayerRegister(address _relayer);
    event relayerUnRegister(address _relayer);
    event relayerUpdated(address _from, address _to);
    event relayerAddedProvisionally(address _relayer);

    function BIND_CHANNELID() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_DUES() external view returns (uint256);
    function INIT_REQUIRED_DEPOSIT() external view returns (uint256);
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
    function WHITELIST_1() external view returns (address);
    function WHITELIST_2() external view returns (address);
    function alreadyInit() external view returns (bool);
    function bscChainID() external view returns (uint16);
    function dues() external view returns (uint256);
    function init() external;
    function isManager(address relayerAddress) external view returns (bool);
    function isRelayer(address relayerAddress) external view returns (bool);
    function removeManagerByHimself() external;
    function requiredDeposit() external view returns (uint256);
    function unregister() external;
    function updateParam(string memory key, bytes memory value) external;
    function updateRelayer(address relayerToBeAdded) external;
    function whitelistInit() external;
    function whitelistInitDone() external view returns (bool);
    function acceptBeingRelayer(address manager) external;
    function isProvisionalRelayer(address relayerAddress) external view returns (bool);

    }

