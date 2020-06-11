pragma solidity 0.6.4;

import "./interface/ISystemReward.sol";
import "./interface/IRelayerHub.sol";
import "./interface/ILightClient.sol";

contract System {

    bool public alreadyInit;

    uint8 constant public BIND_CHANNELID = 0x01;
    uint8 constant public TRANSFER_IN_CHANNELID = 0x02;
    uint8 constant public TRANSFER_OUT_CHANNELID = 0x03;
    uint8 constant public STAKING_CHANNELID = 0x08;
    uint8 constant public GOV_CHANNELID = 0x09;
    uint8 constant public SLASH_CHANNELID = 0x0b;
    uint16 constant bscChainID = 0x0060;

    address public constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
    address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
    address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
    address public constant LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
    address public constant TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
    address public constant INCENTIVIZE_ADDR=0x0000000000000000000000000000000000001005;
    address public constant RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
    address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
    address public constant CROSS_CHAIN_CONTRACT_ADDR = 0x0000000000000000000000000000000000002000;


    modifier onlyCoinbase() {
       require(msg.sender == block.coinbase, "the message sender must be the block producer");
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

    modifier doClaimReward(address relayer, uint256 reward) {
        _;
        ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, reward);
    }

    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}
