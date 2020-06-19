pragma solidity 0.6.4;
import "./System.sol";
import "./lib/BytesToTypes.sol";
import "./lib/Memory.sol";
import "./lib/BytesLib.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
import "./lib/RLPDecode.sol";
import "./lib/CmnPkg.sol";


contract GovHub is System, IApplication{
  using RLPDecode for *;

  uint8 public constant PARAM_UPDATE_MESSAGE_TYPE = 0;

  uint32 public constant ERROR_TARGET_NOT_CONTRACT = 101;
  uint32 public constant ERROR_TARGET_CONTRACT_FAIL = 102;

  event failReasonWithStr(string message);
  event failReasonWithBytes(bytes message);
  event paramChange(string key, bytes value);

  struct ParamChangePackage {
    string   key;
    bytes    value;
    address  target;
  }

  function handleSynPackage(uint8, bytes calldata msgBytes) onlyCrossChainContract external override returns(bytes memory responsePayload) {
    (ParamChangePackage memory proposal, bool success) = decodeSynPackage(msgBytes);
    if (!success) {
      return CmnPkg.encodeCommonAckPackage(ERROR_FAIL_DECODE);
    }
    uint32 resCode = notifyUpdates(proposal);
    if (resCode == CODE_OK) {
      return new bytes(0);
    } else {
      return CmnPkg.encodeCommonAckPackage(resCode);
    }
  }

  // should not happen
  function handleAckPackage(uint8, bytes calldata) external override {
    require(false, "receive unexpected ack package");
  }

  // should not happen
  function handleFailAckPackage(uint8, bytes calldata) external override {
    require(false, "receive unexpected fail ack package");
  }

  function notifyUpdates(ParamChangePackage memory proposal) internal returns(uint32) {

    if (!isContract(proposal.target)) {
      emit failReasonWithStr("the target is not a contract");
      return ERROR_TARGET_NOT_CONTRACT;
    }
    try IParamSubscriber(proposal.target).updateParam(proposal.key, proposal.value) {
    }catch Error(string memory reason) {
      emit failReasonWithStr(reason);
      return ERROR_TARGET_CONTRACT_FAIL;
    } catch (bytes memory lowLevelData) {
      emit failReasonWithBytes(lowLevelData);
      return ERROR_TARGET_CONTRACT_FAIL;
    }
    return CODE_OK;
  }

  //rlp encode & decode function
  function decodeSynPackage(bytes memory msgBytes) internal pure returns (ParamChangePackage memory, bool) {
    ParamChangePackage memory pkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0) {
        pkg.key = string(iter.next().toBytes());
      } else if (idx == 1) {
        pkg.value = iter.next().toBytes();
      } else if (idx == 2) {
        pkg.target = iter.next().toAddress();
        success = true;
      } else {
        break;
      }
      idx++;
    }
    return (pkg, success);
  }
}