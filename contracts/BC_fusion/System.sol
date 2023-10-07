// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract System {
    uint16 public constant bscChainID = 0x0060;

    address public constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
    address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
    address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
    address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
    address public constant STAKE_HUB_ADDR = 0x0000000000000000000000000000000000002002;
    address public constant GOVERNANCE_ADDR = 0x0000000000000000000000000000000000002003;

    modifier onlyCoinbase() {
        require(msg.sender == block.coinbase, "the message sender must be the block producer");
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

    modifier onlyGovernance() {
        require(msg.sender == GOVERNANCE_ADDR, "the message sender must be governance v2 contract");
        _;
    }

    modifier onlyStakeHub() {
        require(msg.sender == STAKE_HUB_ADDR, "the msg sender must be stakeHub");
        _;
    }
}
