pragma solidity 0.6.4;

import "./interface/ISystemReward.sol";
import "./interface/IRelayerHub.sol";
import "./interface/ILightClient.sol";

contract System {

    // will reward relayer at most 0.05 BNB.
    uint256 constant public RELAYER_REWARD = 5e16;
    // the store name of the package
    string constant STORE_NAME = "ibc";

    uint256 constant crossChainKeyPrefix = 0x0000000000000000000000000000000000000000000000000000000001000200; // last 6 bytes


    address public constant  VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
    address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
    address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
    address public constant LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
    address public constant  TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
    address constant public INCENTIVIZE_ADDR=0x0000000000000000000000000000000000001005;
    address public constant RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
    address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;


    modifier onlyCoinbase() {
       require(msg.sender == block.coinbase, "the message sender must be the block producer");
       _;
   }


    modifier onlyRelayer() {
        require(IRelayerHub(RELAYERHUB_CONTRACT_ADDR).isRelayer(msg.sender), "the msg sender is not a relayer");
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

    modifier blockSynced(uint64 _height) {
        require(ILightClient(LIGHT_CLIENT_ADDR).isHeaderSynced(_height), "light client not sync the block yet");
        _;
    }

    modifier doClaimReward(uint256 reward) {
        _;
        ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, reward);
    }

    // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
    // | 32 bytes | 1 byte | 2 bytes    | 2 bytes      |  1 bytes  | 8 bytes  |
    function generateKey(uint64 _sequence, uint8 channelID) internal pure returns(bytes memory) {
        uint256 fullCrossChainKeyPrefix = crossChainKeyPrefix | channelID;
        bytes memory key = new bytes(14);

        uint256 ptr;
        assembly {
            ptr := add(key, 14)
        }
        assembly {
            mstore(ptr, _sequence)
        }
        ptr -= 8;
        assembly {
            mstore(ptr, fullCrossChainKeyPrefix)
        }
        ptr -= 6;
        assembly {
            mstore(ptr, 14)
        }
        return key;
    }

    function getMsgType(bytes memory msgBytes) internal pure returns(uint8){
        uint8 msgType = 0xff;
        assembly {
            msgType := mload(add(msgBytes, 1))
        }
        return msgType;
    }
}
