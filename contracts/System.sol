pragma solidity 0.6.4;

import "./interface/ISystemReward.sol";
import "./interface/IRelayerHub.sol";
import "./interface/ILightClient.sol";

contract System {
    bool public alreadyInit;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;

    uint8 public constant BIND_CHANNELID = 0x01;
    uint8 public constant TRANSFER_IN_CHANNELID = 0x02;
    uint8 public constant TRANSFER_OUT_CHANNELID = 0x03;
    uint8 public constant STAKING_CHANNELID = 0x08;
    uint8 public constant GOV_CHANNELID = 0x09;
    uint8 public constant SLASH_CHANNELID = 0x0b;
    uint8 public constant CROSS_STAKE_CHANNELID = 0x10;
    uint8 public constant BC_FUSION_CHANNELID = 0x11; // new channel id for cross-chain redelegate from Beacon Chain to Smart Chain after Feynman upgrade
    uint16 public constant bscChainID = 0x0038;

    address public constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
    address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
    address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
    address public constant LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
    address public constant TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
    address public constant INCENTIVIZE_ADDR = 0x0000000000000000000000000000000000001005;
    address public constant RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
    address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
    address public constant TOKEN_MANAGER_ADDR = 0x0000000000000000000000000000000000001008;
    address public constant CROSS_CHAIN_CONTRACT_ADDR = 0x0000000000000000000000000000000000002000;
    address public constant STAKING_CONTRACT_ADDR = 0x0000000000000000000000000000000000002001;
    address public constant STAKE_HUB_ADDR = 0x0000000000000000000000000000000000002002;
    address public constant STAKE_CREDIT_ADDR = 0x0000000000000000000000000000000000002003;
    address public constant GOVERNOR_ADDR = 0x0000000000000000000000000000000000002004;
    address public constant GOV_TOKEN_ADDR = 0x0000000000000000000000000000000000002005;
    address public constant TIMELOCK_ADDR = 0x0000000000000000000000000000000000002006;
    address public constant TOKEN_RECOVER_PORTAL_ADDR = 0x0000000000000000000000000000000000003000;

    modifier onlyCoinbase() {
        require(msg.sender == block.coinbase, "the message sender must be the block producer");
        _;
    }

    modifier onlyZeroGasPrice() {
        require(tx.gasprice == 0, "gasprice is not zero");
        _;
    }

    modifier onlyNotInit() {
        require(!alreadyInit, "the contract already init");
        _;
    }

    modifier onlyInit() {
        require(alreadyInit, "the contract not init yet");
        _;
    }

    modifier onlySlash() {
        require(msg.sender == SLASH_CONTRACT_ADDR, "the message sender must be slash contract");
        _;
    }

    modifier onlyTokenHub() {
        require(msg.sender == TOKEN_HUB_ADDR, "the message sender must be token hub contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB_ADDR, "the message sender must be governance contract");
        _;
    }

    modifier onlyValidatorContract() {
        require(msg.sender == VALIDATOR_CONTRACT_ADDR, "the message sender must be validatorSet contract");
        _;
    }

    modifier onlyCrossChainContract() {
        require(msg.sender == CROSS_CHAIN_CONTRACT_ADDR, "the message sender must be cross chain contract");
        _;
    }

    modifier onlyRelayerIncentivize() {
        require(msg.sender == INCENTIVIZE_ADDR, "the message sender must be incentivize contract");
        _;
    }

    modifier onlyRelayer() {
        require(IRelayerHub(RELAYERHUB_CONTRACT_ADDR).isRelayer(msg.sender), "the msg sender is not a relayer");
        _;
    }

    modifier onlyTokenManager() {
        require(msg.sender == TOKEN_MANAGER_ADDR, "the msg sender must be tokenManager");
        _;
    }

    modifier onlyStakeHub() {
        require(msg.sender == STAKE_HUB_ADDR, "the msg sender must be stakeHub");
        _;
    }

    modifier onlyGovernorTimelock() {
        require(msg.sender == TIMELOCK_ADDR, "the msg sender must be governor timelock contract");
        _;
    }

    modifier onlyTokenRecoverPortal() {
        require(msg.sender == TOKEN_RECOVER_PORTAL_ADDR, "the msg sender must be token recover portal");
        _;
    }

    // Not reliable, do not use when need strong verify
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
