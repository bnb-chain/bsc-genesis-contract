pragma solidity 0.6.4;

import "./System.sol";
import "./Seriality/TypesToBytes.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/BytesLib.sol";


contract BSCValidatorSetTool{
  // keep consistent with the channel id in BBC;
  uint8 public constant CHANNEL_ID =  8;
  // {20 bytes consensusAddress} + {20 bytes feeAddress} + {20 bytes BBCFeeAddress} + {8 bytes voting power}
  uint constant  VALIDATOR_BYTES_LENGTH = 68;

  uint16 public constant FROM_CHAIN_ID = 0x0001;
  uint16 public constant TO_CHAIN_ID = 0x0002;

  Validator[] public currentValidatorSet;

  struct Validator{
    address consensusAddress;
    address payable feeAddress;
    address BBCFeeAddress;
    uint64  votingPower;
    bool jailed;
    uint256 incoming;
  }


  function verify(bytes key, bytes calldata msgBytes, uint64 packageSequence) external{
    // verify key value against light client;
    bytes memory key = generateKey(packageSequence);

    bool valid = MerkleProof.validateMerkleProof(appHash, STORE_NAME, key, msgBytes, proof);
    require(valid, "the package is invalid against its proof");
    parseValidatorSet(msgBytes);
  }

  /*********************** Internal Functions **************************/

  function parseValidatorSet(bytes memory validatorSetBytes) internal{
    uint length = validatorSetBytes.length-1;
    require(length > 0, "the validatorSetBytes should not be empty");
    require(length % VALIDATOR_BYTES_LENGTH == 0, "the length of validatorSetBytes should be times of 68");
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

  function generateKey(uint64 packageSequence) internal view returns (bytes memory){
    // A copy of keyPrefix
    bytes memory sequenceBytes = new bytes(8);
    bytes keyPrefix = generatePrefixKey();
    TypesToBytes.uintToBytes(32, packageSequence, sequenceBytes);
    return BytesLib.concat(keyPrefix, sequenceBytes);
  }


  function generatePrefixKey() private pure returns(bytes memory prefix){

    prefix = new bytes(5);
    uint256 pos=prefix.length;

    assembly {
      mstore(add(prefix, pos), CHANNEL_ID)
    }
    pos -=1;
    assembly {
      mstore(add(prefix, pos), TO_CHAIN_ID)
    }
    pos -=2;

    assembly {
      mstore(add(prefix, pos), FROM_CHAIN_ID)
    }
    pos -=2;
    assembly {
      mstore(add(prefix, pos), 0x5)
    }
    return prefix;
  }
}