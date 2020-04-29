pragma solidity 0.6.4;
import "./System.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/Memory.sol";
import "./Seriality/BytesLib.sol";
import "./interface/IParamSubscriber.sol";
import "./MerkleProof.sol";



contract GovHub is System{

    bytes32 constant crossChainKeyPrefix = 0x0000000000000000000000000000000000000000000000000000000001000209; // last 6 bytes
    uint8 public constant PARAM_UPDATE_MESSAGE_TYPE = 0;

    uint64 public sequence;
    uint256 public relayerReward;
    bool public alreadyInit;

    event failReasonWithStr(string message);
    event failReasonWithBytes(bytes message);
    event paramChange(string key, bytes value);


    modifier onlyNotInit() {
        require(!alreadyInit, "the contract already init");
        _;
    }

    modifier onlyInit() {
        require(alreadyInit, "the contract not init yet");
        _;
    }

    function init() external onlyNotInit{
        relayerReward = RELAYER_REWARD;
        alreadyInit = true;
    }

    modifier sequenceInOrder(uint64 _sequence) {
        require(_sequence == sequence, "sequence not in order");
        _;
        sequence ++;
    }

    function handlePackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) external onlyInit onlyRelayer sequenceInOrder(packageSequence) blockSynced(height) doClaimReward(relayerReward){
        bytes memory key = generateKey(packageSequence, crossChainKeyPrefix);
        bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
        bool valid = MerkleProof.validateMerkleProof(appHash, STORE_NAME, key, msgBytes, proof);
        require(valid, "the package is invalid against its proof");
        uint8 msgType = getMsgType(msgBytes);
        if(msgType == PARAM_UPDATE_MESSAGE_TYPE){
            notifyUpdates(msgBytes);
        }else{
            emit failReasonWithStr("unknown message type");
        }
    }

    //| Proposal type | key length | bytes of  key  | value length | value  | target addr |
    //|      1 byte   | 1 byte     |     N bytes    |   1 byte     | M bytes|  20 byte    |

    function notifyUpdates(bytes memory proposalBytes) internal {
        uint msgLength = proposalBytes.length;
        // the minimum length is 25
        if(msgLength <25){
            emit failReasonWithStr("msg length less than 25");
            return;
        }
        uint8 keyLength =  BytesToTypes.bytesToUint8(2, proposalBytes);
        if(keyLength == 0||msgLength<24+uint16(keyLength)){
            emit failReasonWithStr("keyLength mismatch");
            return;
        }
        string memory key = string(BytesLib.slice(proposalBytes, 2, keyLength));
        uint8 valueLength =  BytesToTypes.bytesToUint8(3+uint16(keyLength), proposalBytes);
        if(valueLength == 0||msgLength!=23+uint16(keyLength)+uint16(valueLength)){
            emit failReasonWithStr("valueLength mismatch");
            return;
        }
        bytes memory value = BytesLib.slice(proposalBytes, 3+uint16(keyLength), uint16(valueLength));
        address target = BytesToTypes.bytesToAddress(msgLength, proposalBytes);
        if (target == address(this)){
            updateParam(key, value);
        }else{
            try IParamSubscriber(target).updateParam(key, value){
            }catch Error(string memory reason) {
                emit failReasonWithStr(reason);
            } catch (bytes memory lowLevelData) {
                emit failReasonWithBytes(lowLevelData);
            }
        }
        return;
    }

    /*********************** Param update ********************************/
    function updateParam(string memory key, bytes memory value) internal{
        if (Memory.compareStrings(key,"relayerReward")){
            if(value.length != 32){
                emit failReasonWithStr("length of relayerReward mismatch");
                return;
            }
            uint256 newRelayerReward = BytesToTypes.bytesToUint256(32, value);
            if (newRelayerReward == 0 || newRelayerReward > 1e18){
                emit failReasonWithStr("the relayerReward out of range");
                return;
            }
            relayerReward = newRelayerReward;
            emit paramChange(key, value);
    }else{
            emit failReasonWithStr("unknown param");
        }
    }
}
