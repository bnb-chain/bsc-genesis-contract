pragma solidity 0.6.4;

import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/IRelayerHub.sol";
import "./Seriality/Memory.sol";
import "./interface/IParamSubscriber.sol";
import "./System.sol";
import "./MerkleProof.sol";


contract CrossChain is System, ICrossChain, IParamSubscriber{

  // the store name of the package
  string constant public STORE_NAME = "ibc";

  uint8 constant public SYNC_PACKAGE = 0x00;
  uint8 constant public ACK_PACKAGE = 0x01;
  uint8 constant public FAIL_ACK_PACKAGE = 0x02;

  uint16 constant bscChainID = 0x0060;
  uint256 constant crossChainKeyPrefix = 0x0000000000000000000000000000000000000000000000000000000001006000; // last 6 bytes

  mapping(uint8 => address) public channelHandlerContractMap;
  mapping(address => bool) public registeredContractMap;
  mapping(uint8 => uint64) public channelSendSequenceMap;
  mapping(uint8 => uint64) public channelReceiveSequenceMap;
  mapping(uint8 => bool) public isRelayRewardFromSystemReward;

  event crossChainPackage(uint16 chainId, uint64 indexed sequence, uint8 indexed channelId, bytes payload);
  event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
  event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
  event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);

  event paramChange(string key, bytes value);
  event addChannel(uint8 indexed channelId, address indexed contractAddr);

  modifier sequenceInOrder(uint64 _sequence, uint8 _channelID) {
    uint64 expectedSequence = channelReceiveSequenceMap[_channelID];
    require(_sequence == expectedSequence, "sequence not in order");

    channelReceiveSequenceMap[_channelID]=expectedSequence+1;
    _;
  }

  modifier blockSynced(uint64 _height) {
    require(ILightClient(LIGHT_CLIENT_ADDR).isHeaderSynced(_height), "light client not sync the block yet");
    _;
  }

  modifier channelSupported(uint8 _channelID) {
    require(channelHandlerContractMap[_channelID]!=address(0x0), "channel is not supported");
    _;
  }

  modifier registeredContract() {
    require(registeredContractMap[msg.sender], "handle contract has not been registered");
    _;
  }

  // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
  // | 32 bytes | 1 byte | 2 bytes      | 2 bytes            |  1 bytes  | 8 bytes  |
  function generateKey(uint64 _sequence, uint8 _channelID) internal pure returns(bytes memory) {
    uint256 fullCrossChainKeyPrefix = crossChainKeyPrefix | _channelID;
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

  function init() public onlyNotInit {
    channelHandlerContractMap[BIND_CHANNELID] = TOKEN_HUB_ADDR;
    isRelayRewardFromSystemReward[BIND_CHANNELID] = false;
    channelHandlerContractMap[TRANSFER_IN_CHANNELID] = TOKEN_HUB_ADDR;
    isRelayRewardFromSystemReward[TRANSFER_IN_CHANNELID] = false;
    channelHandlerContractMap[TRANSFER_OUT_CHANNELID] = TOKEN_HUB_ADDR;
    isRelayRewardFromSystemReward[TRANSFER_OUT_CHANNELID] = false;
    registeredContractMap[TOKEN_HUB_ADDR] = true;


    channelHandlerContractMap[STAKING_CHANNELID] = VALIDATOR_CONTRACT_ADDR;
    isRelayRewardFromSystemReward[STAKING_CHANNELID] = true;
    registeredContractMap[VALIDATOR_CONTRACT_ADDR] = true;

    channelHandlerContractMap[GOV_CHANNELID] = GOV_HUB_ADDR;
    isRelayRewardFromSystemReward[GOV_CHANNELID] = true;
    registeredContractMap[GOV_HUB_ADDR] = true;

    alreadyInit=true;
  }

function encodePayload(uint8 packageType, uint256 syncRelayFee, uint256 ackRelayFee, bytes memory msgBytes) public pure returns(bytes memory) {
    uint256 payloadLength = msgBytes.length + 65;
    bytes memory payload = new bytes(payloadLength);
    uint256 ptr;
    assembly {
      ptr := payload
    }
    ptr+=65;
    assembly {
      mstore(ptr, ackRelayFee)
    }

    ptr-=32;
    assembly {
      mstore(ptr, syncRelayFee)
    }

    ptr-=32;
    assembly {
      mstore(ptr, packageType)
    }

    ptr-=1;
    assembly {
      mstore(ptr, payloadLength)
    }

    ptr+=97;
    (uint256 src,) = Memory.fromBytes(msgBytes);
    Memory.copy(src, ptr, msgBytes.length);

    return payload;
  }

  // | type   | syncRelayFee   | ackRelayFee  | package  |
  // | 1 byte | 32 bytes       | 32 bytes     | bytes    |
  function decodePayload(bytes memory payload) internal pure returns(bool, uint8, uint256, uint256, bytes memory) {
    if (payload.length < 65) {
      return (false, 0, 0, 0, new bytes(0));
    }

    uint256 ptr;
    assembly {
      ptr := payload
    }

    uint8 packageType;
    ptr+=1;
    assembly {
      packageType := mload(ptr)
    }

    uint256 syncRelayFee;
    ptr+=32;
    assembly {
      syncRelayFee := mload(ptr)
    }

    uint256 ackRelayFee;
    ptr+=32;
    assembly {
      ackRelayFee := mload(ptr)
    }

    ptr+=32;
    bytes memory msgBytes = new bytes(payload.length-65);
    (uint256 dst, ) = Memory.fromBytes(msgBytes);
    Memory.copy(ptr, dst, payload.length-65);

    return (true, packageType, syncRelayFee, ackRelayFee, msgBytes);
  }

  function handlePackage(bytes calldata payload, bytes calldata proof, uint64 height, uint64 packageSequence, uint8 channelId) onlyInit onlyRelayer sequenceInOrder(packageSequence, channelId) blockSynced(height) channelSupported(channelId) external {
    bytes memory payloadLocal = payload; // fix error: stack too deep, try removing local variables
    bytes memory proofLocal = proof; // fix error: stack too deep, try removing local variables
    require(MerkleProof.validateMerkleProof(ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height), STORE_NAME, generateKey(packageSequence, channelId), payloadLocal, proofLocal), "invalid merkle proof");

    address payable headerRelayer = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);

    uint8 channelIdLocal = channelId; // fix error: stack too deep, try removing local variables
    (bool success, uint8 packageType, uint256 syncRelayFee, uint256 ackRelayFee, bytes memory msgBytes) = decodePayload(payloadLocal);
    if (!success) {
      emit unsupportedPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, payloadLocal);
      return;
    }

    if (packageType == SYNC_PACKAGE) {
      IRelayerIncentivize(INCENTIVIZE_ADDR).addReward(headerRelayer, msg.sender, syncRelayFee, isRelayRewardFromSystemReward[channelIdLocal]);
      address handlerContract = channelHandlerContractMap[channelIdLocal];
      try IApplication(handlerContract).handleSyncPackage(channelIdLocal, msgBytes) returns (bytes memory responsePayload) {
        emit crossChainPackage(bscChainID, channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(ACK_PACKAGE, 0, ackRelayFee, responsePayload));
      } catch Error(string memory reason) {
        emit crossChainPackage(bscChainID, channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(FAIL_ACK_PACKAGE, 0, ackRelayFee, msgBytes));
        emit unexpectedRevertInPackageHandler(handlerContract, reason);
      } catch (bytes memory lowLevelData) {
        emit crossChainPackage(bscChainID, channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(FAIL_ACK_PACKAGE, 0, ackRelayFee, msgBytes));
        emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
      }
      channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
    } else if (packageType == ACK_PACKAGE) {
      IRelayerIncentivize(INCENTIVIZE_ADDR).addReward(headerRelayer, msg.sender, ackRelayFee, isRelayRewardFromSystemReward[channelIdLocal]);
      address handlerContract = channelHandlerContractMap[channelIdLocal];
      try IApplication(handlerContract).handleAckPackage(channelIdLocal, msgBytes) {
      } catch Error(string memory reason) {
        emit unexpectedRevertInPackageHandler(handlerContract, reason);
      } catch (bytes memory lowLevelData) {
        emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
      }
    } else if (packageType == FAIL_ACK_PACKAGE) {
      IRelayerIncentivize(INCENTIVIZE_ADDR).addReward(headerRelayer, msg.sender, ackRelayFee, isRelayRewardFromSystemReward[channelIdLocal]);
      address handlerContract = channelHandlerContractMap[channelIdLocal];
      try IApplication(handlerContract).handleFailAckPackage(channelIdLocal, msgBytes) {
      } catch Error(string memory reason) {
        emit unexpectedRevertInPackageHandler(handlerContract, reason);
      } catch (bytes memory lowLevelData) {
        emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
      }
    }
  }

  function sendPackage(uint8 channelId, bytes calldata msgBytes, uint256 syncRelayFee, uint256 ackRelayFee) onlyInit registeredContract external override returns(bool) {
    uint64 sendSequence = channelSendSequenceMap[channelId];
    emit crossChainPackage(bscChainID, sendSequence, channelId, encodePayload(SYNC_PACKAGE, syncRelayFee, ackRelayFee, msgBytes));
    sendSequence++;
    channelSendSequenceMap[channelId] = sendSequence;
    return true;
  }

  function updateParam(string calldata key, bytes calldata value) onlyGov external override {
    bytes memory localKey = bytes(key);
    bytes memory localValue = value;
    require(localKey.length == 1, "expected key length is 1");
    // length is 8, used to skip receive sequence
    // length is 20, used to add or delete channel
    require(localValue.length == 8 || localValue.length == 20, "expected value length is 8 or 20");

    uint256 bytes32Key;
    assembly {
      bytes32Key := mload(add(localKey, 1))
    }
    uint8 channelId = uint8(bytes32Key);

    if (localValue.length == 8) {
      uint64 sequence;
      assembly {
        sequence := mload(add(localValue, 8))
      }
      require(channelReceiveSequenceMap[channelId]<sequence, "can't retreat sequence");
      channelReceiveSequenceMap[channelId] = sequence;
    } else {
      address handlerContract;
      assembly {
        handlerContract := mload(add(localValue, 20))
      }
      require(isContract(handlerContract), "address is not a contract");
      channelHandlerContractMap[channelId]=handlerContract;
      registeredContractMap[handlerContract] = true;
      emit addChannel(channelId, handlerContract);

    }
    emit paramChange(key, value);
  }
}
