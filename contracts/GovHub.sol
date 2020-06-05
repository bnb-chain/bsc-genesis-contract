pragma solidity 0.6.4;
import "./System.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/Memory.sol";
import "./Seriality/BytesLib.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";


contract GovHub is System, IApplication{

  uint8 public constant PARAM_UPDATE_MESSAGE_TYPE = 0;

  event failReasonWithStr(string message);
  event failReasonWithBytes(bytes message);
  event paramChange(string key, bytes value);

  function init() external onlyNotInit{
    alreadyInit = true;
  }

  function handleSyncPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override returns(bytes memory responsePayload){
    uint8 msgType = getMsgType(msgBytes);
    if(msgType == PARAM_UPDATE_MESSAGE_TYPE){
      notifyUpdates(msgBytes);
    }else{
      emit failReasonWithStr("unknown message type");
    }
    return new bytes(0);
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external override {
    return;
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external override {
    return;
  }

  //| Proposal type | key length | bytes of  key  | value length | value  | target addr |
  //|    1 byte   | 1 byte   |   N bytes  |   1 byte   | M bytes|  20 byte  |

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
      if (!isContract(target)){
        emit failReasonWithStr("the target is not a contract");
        return;
      }
      try IParamSubscriber(target).updateParam(key, value){
      }catch Error(string memory reason) {
        emit failReasonWithStr(reason);
      } catch (bytes memory lowLevelData) {
        emit failReasonWithBytes(lowLevelData);
      }
    }
    return;
  }

  function getMsgType(bytes memory msgBytes) internal pure returns(uint8){
    uint8 msgType = 0xff;
    assembly {
      msgType := mload(add(msgBytes, 1))
    }
    return msgType;
  }

  /*********************** Param update ********************************/
  function updateParam(string memory key, bytes memory value) internal{

  }
}
