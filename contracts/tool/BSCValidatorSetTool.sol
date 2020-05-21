pragma solidity 0.6.4;

import "../Seriality/TypesToBytes.sol";
import "../Seriality/BytesToTypes.sol";
import "../Seriality/BytesLib.sol";



contract BSCValidatorSetTool {
  // keep consistent with the channel id in BBC;
  uint8 public constant CHANNEL_ID =  8;
  // {20 bytes consensusAddress} + {20 bytes feeAddress} + {20 bytes BBCFeeAddress} + {8 bytes voting power}
  uint constant  VALIDATOR_BYTES_LENGTH = 68;
  uint256 constant crossChainKeyPrefix = 0x0000000000000000000000000000000000000000000000000000000001000200; // last 6 bytes

  uint16 public constant FROM_CHAIN_ID = 0x0001;
  uint16 public constant TO_CHAIN_ID = 0x0002;

  Validator[] public currentValidatorSet;
  bytes public expectedKey;

  struct Validator{
    address consensusAddress;
    address payable feeAddress;
    address BBCFeeAddress;
    uint64  votingPower;
  }



  function verify(bytes calldata key, bytes calldata msgBytes, uint64 packageSequence) external{
    // verify key value against light client;
    bytes memory expect = generateKey(packageSequence,CHANNEL_ID);
    expectedKey = key;
    require(BytesLib.equal(expect,key), string(expectedKey));
    parseValidatorSet(msgBytes);
  }

  /*********************** Internal Functions **************************/

  function parseValidatorSet(bytes memory validatorSetBytes) internal{
    uint length = validatorSetBytes.length-1;
    require(length > 0, "the validatorSetBytes should not be empty");
    require(length % VALIDATOR_BYTES_LENGTH == 0, "the length of validatorSetBytes should be times of 68");
    uint m = currentValidatorSet.length;
    for(uint i = 0;i<m;i++){
      currentValidatorSet.pop();
    }
    uint n = length/VALIDATOR_BYTES_LENGTH;
    for(uint i = 0;i<n;i++){
      Validator memory v;
      v.consensusAddress = BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+20,validatorSetBytes);
      v.feeAddress = address(uint160(BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+40,validatorSetBytes)));
      v.BBCFeeAddress = BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+60,validatorSetBytes);
      v.votingPower = BytesToTypes.bytesToUint64(1+i*VALIDATOR_BYTES_LENGTH+68,validatorSetBytes);
      currentValidatorSet.push(v);
    }
  }


  // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
  // | 32 bytes | 1 byte | 2 bytes    | 2 bytes      |  1 bytes  | 8 bytes  |
  function generateKey(uint64 _sequence, uint8 channelID) public pure returns(bytes memory) {

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
}