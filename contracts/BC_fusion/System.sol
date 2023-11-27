// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

contract System {
    /*----------------- constants -----------------*/
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

    /*----------------- errors -----------------*/
    error UnknownParam(string key, bytes value);
    error InvalidValue(string key, bytes value);
    error OnlyCoinbase();
    error OnlyZeroGasPrice();
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
}
