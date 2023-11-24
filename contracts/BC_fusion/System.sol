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

    /*----------------- events -----------------*/
    event ParamChange(string key, bytes value);

    /*----------------- modifiers -----------------*/
    modifier onlyCoinbase() {
        require(msg.sender == block.coinbase, "the message sender must be the block producer");
        _;
    }

    modifier onlyZeroGasPrice() {
        require(tx.gasprice == 0, "gasprice is not zero");
        _;
    }

    modifier onlyValidatorContract() {
        require(msg.sender == VALIDATOR_CONTRACT_ADDR, "the message sender must be validatorSet contract");
        _;
    }

    modifier onlySlash() {
        require(msg.sender == SLASH_CONTRACT_ADDR, "the message sender must be slash contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB_ADDR, "the message sender must be governance contract");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == GOVERNOR_ADDR, "the message sender must be governance v2 contract");
        _;
    }

    modifier onlyStakeHub() {
        require(msg.sender == STAKE_HUB_ADDR, "the msg sender must be stakeHub");
        _;
    }
}
