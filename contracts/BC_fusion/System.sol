// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

contract System {
    /*----------------- constants -----------------*/
    uint8 public constant STAKING_CHANNELID = 0x08;
    uint8 public constant BC_FUSION_CHANNELID = 0x11; // new channel id for cross-chain redelegate from Beacon Chain to Smart Chain after Feynman upgrade

    address internal constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
    address internal constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
    address internal constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
    address internal constant LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
    address internal constant TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
    address internal constant INCENTIVIZE_ADDR = 0x0000000000000000000000000000000000001005;
    address internal constant RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
    address internal constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
    address internal constant TOKEN_MANAGER_ADDR = 0x0000000000000000000000000000000000001008;
    address internal constant CROSS_CHAIN_CONTRACT_ADDR = 0x0000000000000000000000000000000000002000;
    address internal constant STAKING_CONTRACT_ADDR = 0x0000000000000000000000000000000000002001;
    address internal constant STAKE_HUB_ADDR = 0x0000000000000000000000000000000000002002;
    address internal constant STAKE_CREDIT_ADDR = 0x0000000000000000000000000000000000002003;
    address internal constant GOVERNOR_ADDR = 0x0000000000000000000000000000000000002004;
    address internal constant GOV_TOKEN_ADDR = 0x0000000000000000000000000000000000002005;
    address internal constant TIMELOCK_ADDR = 0x0000000000000000000000000000000000002006;
    address internal constant TOKEN_RECOVER_PORTAL_ADDR = 0x0000000000000000000000000000000000003000;

    /*----------------- errors -----------------*/
    // @notice signature: 0x97b88354
    error UnknownParam(string key, bytes value);
    // @notice signature: 0x0a5a6041
    error InvalidValue(string key, bytes value);
    // @notice signature: 0x116c64a8
    error OnlyCoinbase();
    // @notice signature: 0x83f1b1d3
    error OnlyZeroGasPrice();
    // @notice signature: 0xf22c4390
    error OnlySystemContract(address systemContract);

    /*----------------- events -----------------*/
    event ParamChange(string key, bytes value);

    /*----------------- modifiers -----------------*/
    modifier onlyCoinbase() {
        if (msg.sender != block.coinbase) revert OnlyCoinbase();
        _;
    }

    modifier onlyZeroGasPrice() {
        if (tx.gasprice != 0) revert OnlyZeroGasPrice();
        _;
    }

    modifier onlyCrossChainContract() {
        if (msg.sender != CROSS_CHAIN_CONTRACT_ADDR) revert OnlySystemContract(CROSS_CHAIN_CONTRACT_ADDR);
        _;
    }

    modifier onlyValidatorContract() {
        if (msg.sender != VALIDATOR_CONTRACT_ADDR) revert OnlySystemContract(VALIDATOR_CONTRACT_ADDR);
        _;
    }

    modifier onlySlash() {
        if (msg.sender != SLASH_CONTRACT_ADDR) revert OnlySystemContract(SLASH_CONTRACT_ADDR);
        _;
    }

    modifier onlyGov() {
        if (msg.sender != GOV_HUB_ADDR) revert OnlySystemContract(GOV_HUB_ADDR);
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != GOVERNOR_ADDR) revert OnlySystemContract(GOVERNOR_ADDR);
        _;
    }

    modifier onlyStakeHub() {
        if (msg.sender != STAKE_HUB_ADDR) revert OnlySystemContract(STAKE_HUB_ADDR);
        _;
    }

    modifier onlyTokenRecoverPortal() {
        require(msg.sender == TOKEN_RECOVER_PORTAL_ADDR, "the msg sender must be token recover portal");
        _;
    }
}
