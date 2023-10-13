pragma solidity 0.6.4;

import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/ITokenHub.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IBSCValidatorSetV2.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./interface/IParamSubscriber.sol";
import "./System.sol";
import "./MerkleProof.sol";

contract CrossChain is System, ICrossChain, IParamSubscriber{

  // constant variables
  string constant public STORE_NAME = "ibc";
  uint256 constant public CROSS_CHAIN_KEY_PREFIX = 0x0102ca00; // last 6 bytes
  uint8 constant public SYN_PACKAGE = 0x00;
  uint8 constant public ACK_PACKAGE = 0x01;
  uint8 constant public FAIL_ACK_PACKAGE = 0x02;
  uint256 constant public INIT_BATCH_SIZE = 50;

  // governable parameters
  uint256 public batchSizeForOracle;

  //state variables
  uint256 public previousTxHeight;
  uint256 public txCounter;
  int64 public oracleSequence;
  mapping(uint8 => address) public channelHandlerContractMap;
  mapping(address => mapping(uint8 => bool))public registeredContractChannelMap;
  mapping(uint8 => uint64) public channelSendSequenceMap;
  mapping(uint8 => uint64) public channelReceiveSequenceMap;
  mapping(uint8 => bool) public isRelayRewardFromSystemReward;

  // to prevent the utilization of ancient block header
  mapping(uint8 => uint64) public channelSyncedHeaderMap;


  // BEP-171: Security Enhancement for Cross-Chain Module
  // 0xebbda044f67428d7e9b472f9124983082bcda4f84f5148ca0a9ccbe06350f196
  bytes32 public constant SUSPEND_PROPOSAL = keccak256("SUSPEND_PROPOSAL");
  // 0xcf82004e82990eca84a75e16ba08aa620238e076e0bc7fc4c641df44bbf5b55a
  bytes32 public constant REOPEN_PROPOSAL = keccak256("REOPEN_PROPOSAL");
  // 0x605b57daa79220f76a5cdc8f5ee40e59093f21a4e1cec30b9b99c555e94c75b9
  bytes32 public constant CANCEL_TRANSFER_PROPOSAL = keccak256("CANCEL_TRANSFER_PROPOSAL");
  // 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
  bytes32 public constant EMPTY_CONTENT_HASH = keccak256("");
  uint16 public constant INIT_SUSPEND_QUORUM = 1;
  uint16 public constant INIT_REOPEN_QUORUM = 2;
  uint16 public constant INIT_CANCEL_TRANSFER_QUORUM = 2;
  uint256 public constant EMERGENCY_PROPOSAL_EXPIRE_PERIOD = 1 hours;

  bool public isSuspended;
  // proposal type hash => latest emergency proposal
  mapping(bytes32 => EmergencyProposal) public emergencyProposals;
  // proposal type hash => the threshold of proposal approved
  mapping(bytes32 => uint16) public quorumMap;
  // IAVL key hash => is challenged
  mapping(bytes32 => bool) public challenged;

  // struct
  // BEP-171: Security Enhancement for Cross-Chain Module
  struct EmergencyProposal {
    uint16 quorum;
    uint128 expiredAt;
    bytes32 contentHash;

    address[] approvers;
  }

  // event
  event crossChainPackage(uint16 chainId, uint64 indexed oracleSequence, uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
  event receivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
  event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
  event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
  event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
  event paramChange(string key, bytes value);
  event enableOrDisableChannel(uint8 indexed channelId, bool isEnable);
  event addChannel(uint8 indexed channelId, address indexed contractAddr);

  // BEP-171: Security Enhancement for Cross-Chain Module
  event ProposalSubmitted(
    bytes32 indexed proposalTypeHash,
    address indexed proposer,
    uint128 quorum,
    uint128 expiredAt,
    bytes32 contentHash
  );
  event Suspended(address indexed executor);
  event Reopened(address indexed executor);
  event SuccessChallenge(
    address indexed challenger,
    uint64 packageSequence,
    uint8 channelId
  );

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

  modifier onlyRegisteredContractChannel(uint8 channleId) {
    require(registeredContractChannelMap[msg.sender][channleId], "the contract and channel have not been registered");
    _;
  }

  modifier headerInOrder(uint64 height, uint8 channelId) {
    require(height >= channelSyncedHeaderMap[channelId], "too old header");
    if (height != channelSyncedHeaderMap[channelId]) {
      channelSyncedHeaderMap[channelId] = height;
    }
    _;
  }

  // BEP-171: Security Enhancement for Cross-Chain Module
  modifier onlyCabinet() {
    uint256 indexPlus = IBSCValidatorSetV2(VALIDATOR_CONTRACT_ADDR).currentValidatorSetMap(msg.sender);
    uint256 numOfCabinets = IBSCValidatorSetV2(VALIDATOR_CONTRACT_ADDR).numOfCabinets();
    if (numOfCabinets == 0) {
      numOfCabinets = 21;
    }

    require(indexPlus > 0 && indexPlus <= numOfCabinets, "not cabinet");
    _;
  }

  modifier whenNotSuspended() {
    require(!isSuspended, "suspended");
    _;
  }

  modifier whenSuspended() {
    require(isSuspended, "not suspended");
    _;
  }

  // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
  // | 32 bytes | 1 byte | 2 bytes      | 2 bytes            |  1 bytes  | 8 bytes  |
  function generateKey(uint64 _sequence, uint8 _channelID) internal pure returns(bytes memory) {
    uint256 fullCROSS_CHAIN_KEY_PREFIX = CROSS_CHAIN_KEY_PREFIX | _channelID;
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
      mstore(ptr, fullCROSS_CHAIN_KEY_PREFIX)
    }
    ptr -= 6;
    assembly {
      mstore(ptr, 14)
    }
    return key;
  }

  function init() external onlyNotInit {
    channelHandlerContractMap[BIND_CHANNELID] = TOKEN_MANAGER_ADDR;
    isRelayRewardFromSystemReward[BIND_CHANNELID] = false;
    registeredContractChannelMap[TOKEN_MANAGER_ADDR][BIND_CHANNELID] = true;

    channelHandlerContractMap[TRANSFER_IN_CHANNELID] = TOKEN_HUB_ADDR;
    isRelayRewardFromSystemReward[TRANSFER_IN_CHANNELID] = false;
    registeredContractChannelMap[TOKEN_HUB_ADDR][TRANSFER_IN_CHANNELID] = true;

    channelHandlerContractMap[TRANSFER_OUT_CHANNELID] = TOKEN_HUB_ADDR;
    isRelayRewardFromSystemReward[TRANSFER_OUT_CHANNELID] = false;
    registeredContractChannelMap[TOKEN_HUB_ADDR][TRANSFER_OUT_CHANNELID] = true;


    channelHandlerContractMap[STAKING_CHANNELID] = VALIDATOR_CONTRACT_ADDR;
    isRelayRewardFromSystemReward[STAKING_CHANNELID] = true;
    registeredContractChannelMap[VALIDATOR_CONTRACT_ADDR][STAKING_CHANNELID] = true;

    channelHandlerContractMap[GOV_CHANNELID] = GOV_HUB_ADDR;
    isRelayRewardFromSystemReward[GOV_CHANNELID] = true;
    registeredContractChannelMap[GOV_HUB_ADDR][GOV_CHANNELID] = true;

    channelHandlerContractMap[SLASH_CHANNELID] = SLASH_CONTRACT_ADDR;
    isRelayRewardFromSystemReward[SLASH_CHANNELID] = true;
    registeredContractChannelMap[SLASH_CONTRACT_ADDR][SLASH_CHANNELID] = true;

    batchSizeForOracle = INIT_BATCH_SIZE;

    oracleSequence = -1;
    previousTxHeight = 0;
    txCounter = 0;

    alreadyInit=true;
  }

  function encodePayload(uint8 packageType, uint256 relayFee, bytes memory msgBytes) public pure returns(bytes memory) {
    uint256 payloadLength = msgBytes.length + 33;
    bytes memory payload = new bytes(payloadLength);
    uint256 ptr;
    assembly {
      ptr := payload
    }
    ptr+=33;

    assembly {
      mstore(ptr, relayFee)
    }

    ptr-=32;
    assembly {
      mstore(ptr, packageType)
    }

    ptr-=1;
    assembly {
      mstore(ptr, payloadLength)
    }

    ptr+=65;
    (uint256 src,) = Memory.fromBytes(msgBytes);
    Memory.copy(src, ptr, msgBytes.length);

    return payload;
  }

  // | type   | relayFee   |package  |
  // | 1 byte | 32 bytes   | bytes    |
  function decodePayloadHeader(bytes memory payload) internal pure returns(bool, uint8, uint256, bytes memory) {
    if (payload.length < 33) {
      return (false, 0, 0, new bytes(0));
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

    uint256 relayFee;
    ptr+=32;
    assembly {
      relayFee := mload(ptr)
    }

    ptr+=32;
    bytes memory msgBytes = new bytes(payload.length-33);
    (uint256 dst, ) = Memory.fromBytes(msgBytes);
    Memory.copy(ptr, dst, payload.length-33);

    return (true, packageType, relayFee, msgBytes);
  }

  function handlePackage(bytes calldata payload, bytes calldata proof, uint64 height, uint64 packageSequence, uint8 channelId)
  onlyInit
  onlyRelayer
  sequenceInOrder(packageSequence, channelId)
  blockSynced(height)
  channelSupported(channelId)
  headerInOrder(height, channelId)
  whenNotSuspended
  external {
    bytes memory payloadLocal = payload; // fix error: stack too deep, try removing local variables
    bytes memory proofLocal = proof; // fix error: stack too deep, try removing local variables
    require(MerkleProof.validateMerkleProof(ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height), STORE_NAME, generateKey(packageSequence, channelId), payloadLocal, proofLocal), "invalid merkle proof");

    address payable headerRelayer = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);

    uint64 sequenceLocal = packageSequence; // fix error: stack too deep, try removing local variables
    uint8 channelIdLocal = channelId; // fix error: stack too deep, try removing local variables
    (bool success, uint8 packageType, uint256 relayFee, bytes memory msgBytes) = decodePayloadHeader(payloadLocal);
    if (!success) {
      emit unsupportedPackage(sequenceLocal, channelIdLocal, payloadLocal);
      return;
    }
    emit receivedPackage(packageType, sequenceLocal, channelIdLocal);
    if (packageType == SYN_PACKAGE) {
      address handlerContract = channelHandlerContractMap[channelIdLocal];
      try IApplication(handlerContract).handleSynPackage(channelIdLocal, msgBytes) returns (bytes memory responsePayload) {
        if (responsePayload.length!=0) {
          sendPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(ACK_PACKAGE, 0, responsePayload));
          channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
        }
      } catch Error(string memory reason) {
        sendPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(FAIL_ACK_PACKAGE, 0, msgBytes));
        channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
        emit unexpectedRevertInPackageHandler(handlerContract, reason);
      } catch (bytes memory lowLevelData) {
        sendPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(FAIL_ACK_PACKAGE, 0, msgBytes));
        channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
        emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
      }
    } else if (packageType == ACK_PACKAGE) {
      address handlerContract = channelHandlerContractMap[channelIdLocal];
      try IApplication(handlerContract).handleAckPackage(channelIdLocal, msgBytes) {
      } catch Error(string memory reason) {
        emit unexpectedRevertInPackageHandler(handlerContract, reason);
      } catch (bytes memory lowLevelData) {
        emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
      }
    } else if (packageType == FAIL_ACK_PACKAGE) {
      address handlerContract = channelHandlerContractMap[channelIdLocal];
      try IApplication(handlerContract).handleFailAckPackage(channelIdLocal, msgBytes) {
      } catch Error(string memory reason) {
        emit unexpectedRevertInPackageHandler(handlerContract, reason);
      } catch (bytes memory lowLevelData) {
        emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
      }
    }
    IRelayerIncentivize(INCENTIVIZE_ADDR).addReward(headerRelayer, msg.sender, relayFee, isRelayRewardFromSystemReward[channelIdLocal] || packageType != SYN_PACKAGE);
  }

  function sendPackage(uint64 packageSequence, uint8 channelId, bytes memory payload) internal whenNotSuspended {
    if (block.number > previousTxHeight) {
      ++oracleSequence;
      txCounter = 1;
      previousTxHeight=block.number;
    } else {
      ++txCounter;
      if (txCounter>batchSizeForOracle) {
        ++oracleSequence;
        txCounter = 1;
      }
    }
    emit crossChainPackage(bscChainID, uint64(oracleSequence), packageSequence, channelId, payload);
  }

  function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee)
  onlyInit
  onlyRegisteredContractChannel(channelId)
  external override {
    uint64 sendSequence = channelSendSequenceMap[channelId];
    sendPackage(sendSequence, channelId, encodePayload(SYN_PACKAGE, relayFee, msgBytes));
    ++sendSequence;
    channelSendSequenceMap[channelId] = sendSequence;
  }

  function updateParam(string calldata key, bytes calldata value)
  onlyGov
  whenNotSuspended
  external override {
    if (Memory.compareStrings(key, "batchSizeForOracle")) {
      uint256 newBatchSizeForOracle = BytesToTypes.bytesToUint256(32, value);
      require(newBatchSizeForOracle <= 10000 && newBatchSizeForOracle >= 10, "the newBatchSizeForOracle should be in [10, 10000]");
      batchSizeForOracle = newBatchSizeForOracle;
    } else if (Memory.compareStrings(key, "addOrUpdateChannel")) {
      bytes memory valueLocal = value;
      require(valueLocal.length == 22, "length of value for addOrUpdateChannel should be 22, channelId:isFromSystem:handlerAddress");
      uint8 channelId;
      assembly {
        channelId := mload(add(valueLocal, 1))
      }

      uint8 rewardConfig;
      assembly {
        rewardConfig := mload(add(valueLocal, 2))
      }
      bool isRewardFromSystem = (rewardConfig == 0x0);

      address handlerContract;
      assembly {
        handlerContract := mload(add(valueLocal, 22))
      }

      require(isContract(handlerContract), "address is not a contract");
      channelHandlerContractMap[channelId]=handlerContract;
      registeredContractChannelMap[handlerContract][channelId] = true;
      isRelayRewardFromSystemReward[channelId] = isRewardFromSystem;
      emit addChannel(channelId, handlerContract);
    } else if (Memory.compareStrings(key, "enableOrDisableChannel")) {
      bytes memory valueLocal = value;
      require(valueLocal.length == 2, "length of value for enableOrDisableChannel should be 2, channelId:isEnable");

      uint8 channelId;
      assembly {
        channelId := mload(add(valueLocal, 1))
      }
      uint8 status;
      assembly {
        status := mload(add(valueLocal, 2))
      }
      bool isEnable = (status == 1);

      address handlerContract = channelHandlerContractMap[channelId];
      if (handlerContract != address(0x00)) { //channel existing
        registeredContractChannelMap[handlerContract][channelId] = isEnable;
        emit enableOrDisableChannel(channelId, isEnable);
      }
    } else if (Memory.compareStrings(key, "suspendQuorum")) {
      require(value.length == 2, "length of value for suspendQuorum should be 2");
      uint16 suspendQuorum = BytesToTypes.bytesToUint16(2, value);
      require(suspendQuorum > 0 && suspendQuorum < 100, "invalid suspend quorum");
      quorumMap[SUSPEND_PROPOSAL] = suspendQuorum;
    } else if (Memory.compareStrings(key, "reopenQuorum")) {
      require(value.length == 2, "length of value for reopenQuorum should be 2");
      uint16 reopenQuorum = BytesToTypes.bytesToUint16(2, value);
      require(reopenQuorum > 0 && reopenQuorum < 100, "invalid reopen quorum");
      quorumMap[REOPEN_PROPOSAL] = reopenQuorum;
    } else if (Memory.compareStrings(key, "cancelTransferQuorum")) {
      require(value.length == 2, "length of value for cancelTransferQuorum should be 2");
      uint16 cancelTransferQuorum = BytesToTypes.bytesToUint16(2, value);
      require(cancelTransferQuorum > 0 && cancelTransferQuorum < 100, "invalid cancel transfer quorum");
      quorumMap[CANCEL_TRANSFER_PROPOSAL] = cancelTransferQuorum;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  // BEP-171: Security Enhancement for Cross-Chain Module
  function challenge(
    // to avoid stack too deep error, using `uint64[4] calldata params`
    // instead of  `uint64 height0, uint64 height1, uint64 packageSequence, uint8 channelId`
    uint64[4] calldata params, // 0-height0, 1-height1, 2-packageSequence, 3-channelId,
    bytes calldata payload0,
    bytes calldata payload1,
    bytes calldata proof0,
    bytes calldata proof1
  )
  onlyInit
  blockSynced(params[0])
  blockSynced(params[1])
  channelSupported(uint8(params[3]))
  whenNotSuspended
  external {
    // the same key with different values (payloads)
    require(keccak256(payload0) != keccak256(payload1), "same payload");

    bytes memory _key;
    uint64 _packageSequence;
    uint8 _channelId;
    {
      _packageSequence = params[2];
      _channelId = uint8(params[3]);
      _key = generateKey(_packageSequence, _channelId);
      bytes32 _keyHash = keccak256(_key);
      require(!challenged[_keyHash], "already challenged");

      // if succeeding in challenge
      challenged[_keyHash] = true;
    }

    // verify payload0 + proof0
    {
      uint64 _height0 = params[0];
      bytes memory _payload0 = payload0;
      bytes memory _proof0 = proof0;
      bytes32 _appHash0 = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(_height0);
      require(MerkleProof.validateMerkleProof(_appHash0, STORE_NAME, _key, _payload0, _proof0), "invalid merkle proof0");
    }

    // verify payload1 + proof1
    {
      uint64 _height1 = params[1];
      bytes memory _payload1 = payload1;
      bytes memory _proof1 = proof1;
      bytes32 _appHash1 = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(_height1);
      require(MerkleProof.validateMerkleProof(_appHash1, STORE_NAME, _key, _payload1, _proof1), "invalid merkle proof1");
    }

    _suspend();
    emit SuccessChallenge(msg.sender, _packageSequence, _channelId);
  }

  function suspend() onlyInit onlyCabinet whenNotSuspended external {
    bool isExecutable = _approveProposal(SUSPEND_PROPOSAL, EMPTY_CONTENT_HASH);
    if (isExecutable) {
      _suspend();
    }
  }

  function reopen() onlyInit onlyCabinet whenSuspended external {
    bool isExecutable = _approveProposal(REOPEN_PROPOSAL, EMPTY_CONTENT_HASH);
    if (isExecutable) {
      isSuspended = false;
      emit Reopened(msg.sender);
    }
  }

  function cancelTransfer(address tokenAddr, address attacker) onlyInit onlyCabinet external {
    bytes32 _contentHash = keccak256(abi.encode(tokenAddr, attacker));
    bool isExecutable = _approveProposal(CANCEL_TRANSFER_PROPOSAL, _contentHash);
    if (isExecutable) {
      ITokenHub(TOKEN_HUB_ADDR).cancelTransferIn(tokenAddr, attacker);
    }
  }

  function _approveProposal(bytes32 proposalTypeHash, bytes32 _contentHash) internal returns (bool isExecutable) {
    if (quorumMap[proposalTypeHash] == 0) {
      quorumMap[SUSPEND_PROPOSAL] = INIT_SUSPEND_QUORUM;
      quorumMap[REOPEN_PROPOSAL] = INIT_REOPEN_QUORUM;
      quorumMap[CANCEL_TRANSFER_PROPOSAL] = INIT_CANCEL_TRANSFER_QUORUM;
    }

    EmergencyProposal storage p = emergencyProposals[proposalTypeHash];

    // It is ok if there is an evil validator always cancel the previous vote,
    // the credible validator could use private transaction service to send a batch tx including 2 approve transactions
    if (block.timestamp >= p.expiredAt || p.contentHash != _contentHash) {
      // current proposal expired / not exist or not same with the new, create a new EmergencyProposal
      p.quorum = quorumMap[proposalTypeHash];
      p.expiredAt = uint128(block.timestamp + EMERGENCY_PROPOSAL_EXPIRE_PERIOD);
      p.contentHash = _contentHash;
      p.approvers = [msg.sender];

      emit ProposalSubmitted(proposalTypeHash, msg.sender, p.quorum, p.expiredAt, _contentHash);
    } else {
      // current proposal exists
      for (uint256 i = 0; i < p.approvers.length; ++i) {
        require(p.approvers[i] != msg.sender, "already approved");
      }
      p.approvers.push(msg.sender);
    }

    if (p.approvers.length >= p.quorum) {
      // 1. remove current proposal
      delete emergencyProposals[proposalTypeHash];

      // 2. exec this proposal
      return true;
    }

    return false;
  }

  function _suspend() whenNotSuspended internal {
    isSuspended = true;
    emit Suspended(msg.sender);
  }
}
