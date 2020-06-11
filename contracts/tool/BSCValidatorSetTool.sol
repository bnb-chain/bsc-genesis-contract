pragma solidity 0.6.4;

import "../rlp/RLPDecode.sol";



contract BSCValidatorSetTool {

  bytes public constant INIT_VALIDATORSET_BYTES = hex"f84580f842f840949fb29aac15b9a4b7f17c3385939b007540f4d791949fb29aac15b9a4b7f17c3385939b007540f4d791949fb29aac15b9a4b7f17c3385939b007540f4d79164";

  using RLPDecode for *;

  struct Validator{
    address consensusAddress;
    address payable feeAddress;
    address BBCFeeAddress;
    uint64  votingPower;
  }

  struct IbcValidatorSetPackage {
    uint8  packageType;
    Validator[] validatorSet;
  }

  function init() external {
    bool valid= decodeValidatorSetSyncPackage(INIT_VALIDATORSET_BYTES);
    require(valid, "failed to init");
  }

  function decodeValidatorSetSyncPackage(bytes memory msgBytes) internal pure returns (bool) {
    IbcValidatorSetPackage memory validatorSetPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while(iter.hasNext()) {
      if ( idx == 0 ) {
        validatorSetPkg.packageType = uint8(iter.next().toUint());
      }else if (idx == 1) {
        RLPDecode.RLPItem[] memory items = iter.next().toList();
        validatorSetPkg.validatorSet =new Validator[](items.length);
        for(uint j = 0;j<items.length;j++){
          (Validator memory val, bool ok) = decodeValidator(items[j]);
          if (!ok){
            return false;
          }
          validatorSetPkg.validatorSet[j] = val;
        }
        success = true;
      }else {
        break;
      }
      idx++;
    }
    return success;
  }

  function decodeValidator(RLPDecode.RLPItem memory itemValidator) internal pure returns(Validator memory, bool) {
    Validator memory validator;
    RLPDecode.Iterator memory iter = itemValidator.iterator();
    bool success = false;
    uint256 idx=0;
    while(iter.hasNext()) {
      if (idx == 0) {
        validator.consensusAddress = iter.next().toAddress();
      }else if (idx == 1) {
        validator.feeAddress = address(uint160(iter.next().toAddress()));
      }else if (idx == 2) {
        validator.BBCFeeAddress = iter.next().toAddress();
      }else if (idx == 3) {
        validator.votingPower = uint64(iter.next().toUint());
        success = true;
      }else {
        break;
      }
      idx++;
    }
    return (validator, success);
  }
}