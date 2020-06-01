pragma solidity 0.6.4;

import "./interface/IBEP2E.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./System.sol";
import "./lib/SafeMath.sol";
import "./MerkleProof.sol";


contract TokenHub is ITokenHub, System, IParamSubscriber{

  using SafeMath for uint256;

  struct BindPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 totalSupply;
    uint256 peggyAmount;
    uint8   bep2eDecimals;
    uint64  expireTime;
    uint256 relayFee;
  }

  struct RefundPackage {
    uint256 refundAmount;
    address contractAddr;
    address payable refundAddr;
    uint64  transferOutSequence;
    uint16  reason;
  }

  struct TransferInPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    address refundAddr;
    address payable recipient;
    uint256 amount;
    uint64  expireTime;
    uint256 relayFee;
  }

  uint8 constant public   BIND_CHANNEL_ID = 0x01;
  uint8 constant public   TRANSFER_IN_CHANNEL_ID = 0x02;
  uint8 constant public   REFUND_CHANNEL_ID=0x03;
  uint256 constant public MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
  uint8 constant public   MINIMUM_BEP2E_SYMBOL_LEN = 3;
  uint8 constant public   MAXIMUM_BEP2E_SYMBOL_LEN = 8;
  uint8 constant public   BEP2_TOKEN_DECIMALS = 8;
  bytes32 constant public BEP2_TOKEN_SYMBOL_FOR_BNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
  uint256 constant public MAX_GAS_FOR_CALLING_BEP2E=50000;

  uint256 constant public INIT_MINIMUM_RELAY_FEE=1e16;
  uint256 constant public INIT_REFUND_RELAY_REWARD=1e16;
  uint256 constant public INIT_MOLECULE_FOR_HEADER_RELAYER=1;
  uint256 constant public INIT_DENOMINATOR_FOR_HEADER_RELAYER=5;

  uint256 public minimumRelayFee;
  uint256 public refundRelayReward;
  uint256 public moleculeForHeaderRelayer;
  uint256 public denominatorForHeaderRelayer;

  mapping(bytes32 => BindPackage) public bindPackageRecord;
  mapping(address => uint256) public bep2eContractDecimals;
  mapping(address => bytes32) private contractAddrToBEP2Symbol;
  mapping(bytes32 => address) private bep2SymbolToContractAddr;

  bool public alreadyInit;

  uint64 public bindChannelSequence=0;
  uint64 public transferInChannelSequence=0;
  uint64 public refundChannelSequence=0;

  uint64 public transferOutChannelSequence=0;
  uint64 public bindResponseChannelSequence=0;
  uint64 public transferInFailureChannelSequence=0;

  event LogBindRequest(uint256 indexed bindPackageSequence, address indexed contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
  event LogBindSuccess(uint256 indexed bindResponseSequence, address indexed contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals);
  event LogBindRejected(uint256 indexed bindResponseSequence, address indexed contractAddr, bytes32 bep2TokenSymbol);
  event LogBindTimeout(uint256 indexed bindResponseSequence, address indexed contractAddr, bytes32 bep2TokenSymbol);
  event LogBindInvalidParameter(uint256 indexed bindResponseSequence, address indexed contractAddr, bytes32 bep2TokenSymbol);

  event LogTransferOut(uint256 indexed transferOutSequenceBSC, address refundAddr, address recipient, uint256 amount, address indexed contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);
  event LogBatchTransferOut(uint256 indexed transferOutSequenceBSC, uint256[] amounts, address indexed contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);
  event LogBatchTransferOutAddrs(uint256 indexed transferOutSequenceBSC, address[] recipientAddrs, address[] refundAddrs);

  event LogTransferInSuccess(uint256 indexed transferOutSequenceBC, address indexed recipient, uint256 amount, address indexed contractAddr);
  event LogTransferInFailureTimeout(uint256 indexed transferInFailureSequence, uint64 indexed transferOutSequenceBC, address refundAddr, address recipient, uint256 bep2TokenAmount, address indexed contractAddr, bytes32 bep2TokenSymbol);
  event LogTransferInFailureInsufficientBalance(uint256 indexed transferInFailureSequence, uint64 indexed transferOutSequenceBC, address refundAddr, address recipient, uint256 bep2TokenAmount, address indexed contractAddr, bytes32 bep2TokenSymbol);
  event LogTransferInFailureUnboundToken(uint256 indexed transferInFailureSequence, uint64 indexed transferOutSequenceBC, address refundAddr, address recipient, uint256 bep2TokenAmount, address indexed contractAddr, bytes32 bep2TokenSymbol);
  event LogTransferInFailureUnknownReason(uint256 indexed transferInFailureSequence, uint64 indexed transferOutSequenceBC, address refundAddr, address recipient, uint256 bep2TokenAmount, address indexed contractAddr, bytes32 bep2TokenSymbol);

  event LogRefundSuccess(uint256 indexed refundPackageSequence, uint256 indexed transferOutSequenceBSC, address indexed contractAddr, address refundAddr, uint256 amount, uint16 reason);
  event LogRefundFailureInsufficientBalance(uint256 indexed transferOutSequenceBSC, address indexed contractAddr, address refundAddr, uint256 amount, uint16 reason);
  event LogRefundFailureUnboundToken(uint256 indexed transferOutSequenceBSC, address indexed contractAddr, address refundAddr, uint256 amount, uint16 reason);
  event LogRefundFailureUnknownReason(uint256 indexed transferOutSequenceBSC, address indexed contractAddr, address refundAddr, uint256 amount, uint16 reason);

  event LogUnexpectedRevertInBEP2E(address indexed contractAddr, string reason);
  event LogUnexpectedFailureAssertionInBEP2E(address indexed contractAddr, bytes lowLevelData);

  event paramChange(string key, bytes value);

  constructor() public {}
  
  function init() external {
    require(!alreadyInit, "already initialized");
    minimumRelayFee = INIT_MINIMUM_RELAY_FEE;
    refundRelayReward = INIT_REFUND_RELAY_REWARD;
    moleculeForHeaderRelayer = INIT_MOLECULE_FOR_HEADER_RELAYER;
    denominatorForHeaderRelayer = INIT_DENOMINATOR_FOR_HEADER_RELAYER;
    alreadyInit=true;
  }
  
  modifier sequenceInOrder(uint64 sequence, uint64 expectedSequence) {
    require(sequence == expectedSequence, "sequence not in order");
    _;
  }
  modifier onlyInit() {
    require(alreadyInit, "the contract not init yet");
    _;
  }

  function bep2TokenSymbolConvert(string memory symbol) internal pure returns(bytes32) {
    bytes32 result;
    assembly {
      result := mload(add(symbol, 32))
    }
    return result;
  }

  // | length   | bep2TokenSymbol | contractAddr | totalSupply | peggyAmount | decimals | expireTime | relayFee |
  // | 32 bytes | 32 bytes        | 20 bytes     |  32 bytes   | 32 bytes    | 1 byte   | 8 bytes    | 32 bytes |
  function decodeBindPackage(bytes memory value) internal pure returns(BindPackage memory) {
    BindPackage memory bindPackage;

    uint256 ptr;
    assembly {
      ptr := value
    }

    bytes32 bep2TokenSymbol;
    ptr+=32;
    assembly {
      bep2TokenSymbol := mload(ptr)
    }
    bindPackage.bep2TokenSymbol = bep2TokenSymbol;

    address addr;

    ptr+=20;
    assembly {
      addr := mload(ptr)
    }
    bindPackage.contractAddr = addr;

    uint256 tempValue;
    ptr+=32;
    assembly {
      tempValue := mload(ptr)
    }
    bindPackage.totalSupply = tempValue;

    ptr+=32;
    assembly {
      tempValue := mload(ptr)
    }
    bindPackage.peggyAmount = tempValue;

    ptr+=1;
    uint8 decimals;
    assembly {
      decimals := mload(ptr)
    }
    bindPackage.bep2eDecimals = decimals;

    ptr+=8;
    uint64 expireTime;
    assembly {
      expireTime := mload(ptr)
    }
    bindPackage.expireTime = expireTime;

    ptr+=32;
    assembly {
      tempValue := mload(ptr)
    }
    bindPackage.relayFee = tempValue;

    return bindPackage;
  }

  function handleBindPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) sequenceInOrder(packageSequence, bindChannelSequence) blockSynced(height) onlyRelayer override external onlyInit returns (bool) {
    require(msgBytes.length==157, "wrong bind package size");
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(bindChannelSequence, BIND_CHANNEL_ID), msgBytes, proof), "invalid merkle proof");
    bindChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);
    BindPackage memory bindPackage = decodeBindPackage(msgBytes);
    IRelayerIncentivize(INCENTIVIZE_ADDR).addReward{value: bindPackage.relayFee}(tendermintHeaderSubmitter, msg.sender);

    bindPackageRecord[bindPackage.bep2TokenSymbol]=bindPackage;
    emit LogBindRequest(packageSequence, bindPackage.contractAddr, bindPackage.bep2TokenSymbol, bindPackage.totalSupply, bindPackage.peggyAmount);
    return true;
  }

  function checkSymbol(string memory bep2eSymbol, bytes32 bep2TokenSymbol) internal pure returns(bool) {
    bytes memory bep2eSymbolBytes = bytes(bep2eSymbol);
    if (bep2eSymbolBytes.length > MAXIMUM_BEP2E_SYMBOL_LEN || bep2eSymbolBytes.length < MINIMUM_BEP2E_SYMBOL_LEN) {
      return false;
    }
    //Upper case string
    for (uint i = 0; i < bep2eSymbolBytes.length; i++) {
      if (0x61 <= uint8(bep2eSymbolBytes[i]) && uint8(bep2eSymbolBytes[i]) <= 0x7A) {
        bep2eSymbolBytes[i] = byte(uint8(bep2eSymbolBytes[i]) - 0x20);
      }
    }

    bytes memory bep2TokenSymbolBytes = new bytes(32);
    assembly {
      mstore(add(bep2TokenSymbolBytes, 32), bep2TokenSymbol)
    }
    if (bep2TokenSymbolBytes[bep2eSymbolBytes.length] != 0x2d) { // '-'
      return false;
    }
    bool symbolMatch = true;
    for(uint256 index=0; index < bep2eSymbolBytes.length; index++) {
      if (bep2eSymbolBytes[index] != bep2TokenSymbolBytes[index]) {
        symbolMatch = false;
        break;
      }
    }
    return symbolMatch;
  }

  function convertToBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) internal pure returns (uint256) {
    if (bep2eTokenDecimals > BEP2_TOKEN_DECIMALS) {
      return amount.div(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS));
    }
    return amount.mul(10**(BEP2_TOKEN_DECIMALS-bep2eTokenDecimals));
  }

  function getBoundContract(string memory bep2Symbol) public view returns (address) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    return bep2SymbolToContractAddr[bep2TokenSymbol];
  }

  function getBoundBep2Symbol(address contractAddr) public view returns (string memory) {
    bytes32 bep2SymbolBytes32 = contractAddrToBEP2Symbol[contractAddr];
    bytes memory bep2SymbolBytes = new bytes(32);
    assembly {
      mstore(add(bep2SymbolBytes,32), bep2SymbolBytes32)
    }
    uint8 bep2SymbolLength = 0;
    for (uint8 j = 0; j < 32; j++) {
      if (bep2SymbolBytes[j] != 0) {
          bep2SymbolLength++;
      } else {
        break;
      }
    }
    bytes memory bep2Symbol = new bytes(bep2SymbolLength);
    for (uint8 j = 0; j < bep2SymbolLength; j++) {
        bep2Symbol[j] = bep2SymbolBytes[j];
    }
    return string(bep2Symbol);
  }

  function approveBind(address contractAddr, string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindPackage memory bindPackage = bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    uint256 lockedAmount = bindPackage.totalSupply.sub(bindPackage.peggyAmount);
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can approve this bind request");
    require(IBEP2E(contractAddr).allowance(msg.sender, address(this))==lockedAmount, "allowance doesn't equal to (totalSupply - peggyAmount)");

    if (bindPackage.expireTime<block.timestamp) {
      emit LogBindTimeout(bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
      delete bindPackageRecord[bep2TokenSymbol];
      return false;
    }

    uint256 decimals = IBEP2E(contractAddr).decimals();
    string memory bep2eSymbol = IBEP2E(contractAddr).symbol();
    if (!checkSymbol(bep2eSymbol, bep2TokenSymbol) ||
      bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol]!=address(0x00)||
      contractAddrToBEP2Symbol[bindPackage.contractAddr]!=bytes32(0x00)||
      IBEP2E(bindPackage.contractAddr).totalSupply()!=bindPackage.totalSupply||
      decimals!=bindPackage.bep2eDecimals) {
      delete bindPackageRecord[bep2TokenSymbol];
      emit LogBindInvalidParameter(bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
      return false;
    }
    IBEP2E(contractAddr).transferFrom(msg.sender, address(this), lockedAmount);
    contractAddrToBEP2Symbol[bindPackage.contractAddr] = bindPackage.bep2TokenSymbol;
    bep2eContractDecimals[bindPackage.contractAddr] = bindPackage.bep2eDecimals;
    bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol] = bindPackage.contractAddr;

    delete bindPackageRecord[bep2TokenSymbol];
    emit LogBindSuccess(bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol, bindPackage.totalSupply, bindPackage.peggyAmount, decimals);
    return true;
  }

  function rejectBind(address contractAddr, string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindPackage memory bindPackage = bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can reject");
    delete bindPackageRecord[bep2TokenSymbol];
    emit LogBindRejected(bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
    return true;
  }

  function expireBind(string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindPackage memory bindPackage = bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(bindPackage.expireTime<block.timestamp, "bind request is not expired");
    delete bindPackageRecord[bep2TokenSymbol];
    emit LogBindTimeout(bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
    return true;
  }

  // | length   | bep2TokenSymbol | contractAddr | sender   | recipient | amount   | expireTime | relayFee |
  // | 32 bytes | 32 bytes    | 20 bytes   | 20 bytes | 20 bytes  | 32 bytes | 8 bytes  | 32 bytes  |
  function decodeTransferInPackage(bytes memory value) internal pure returns (TransferInPackage memory) {
    TransferInPackage memory transferInPackage;

    uint256 ptr;
    assembly {
      ptr := value
    }

    uint256 tempValue;
    address payable recipient;
    address addr;

    ptr+=32;
    bytes32 bep2TokenSymbol;
    assembly {
      bep2TokenSymbol := mload(ptr)
    }
    transferInPackage.bep2TokenSymbol = bep2TokenSymbol;

    ptr+=20;
    assembly {
      addr := mload(ptr)
    }
    transferInPackage.contractAddr = addr;

    ptr+=20;
    assembly {
      addr := mload(ptr)
    }
    transferInPackage.refundAddr = addr;

    ptr+=20;
    assembly {
      recipient := mload(ptr)
    }
    transferInPackage.recipient = recipient;

    ptr+=32;
    assembly {
      tempValue := mload(ptr)
    }
    transferInPackage.amount = tempValue;

    ptr+=8;
    uint64 expireTime;
    assembly {
      expireTime := mload(ptr)
    }
    transferInPackage.expireTime = expireTime;

    ptr+=32;
    assembly {
      tempValue := mload(ptr)
    }
    transferInPackage.relayFee = tempValue;

    return transferInPackage;
  }

  function handleTransferInPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) sequenceInOrder(packageSequence, transferInChannelSequence) blockSynced(height) onlyRelayer override external onlyInit returns (bool) {
    require(msgBytes.length==164, "wrong transfer package size");
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(transferInChannelSequence, TRANSFER_IN_CHANNEL_ID), msgBytes, proof), "invalid merkle proof");
    transferInChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);
    TransferInPackage memory transferInPackage = decodeTransferInPackage(msgBytes);
    IRelayerIncentivize(INCENTIVIZE_ADDR).addReward{value: transferInPackage.relayFee}(tendermintHeaderSubmitter, msg.sender);

    if (transferInPackage.contractAddr==address(0x0) && transferInPackage.bep2TokenSymbol==BEP2_TOKEN_SYMBOL_FOR_BNB) {
      if (block.timestamp > transferInPackage.expireTime) {
        emit LogTransferInFailureTimeout(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/1e10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      if (address(this).balance < transferInPackage.amount) {
        emit LogTransferInFailureInsufficientBalance(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/1e10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      if (!transferInPackage.recipient.send(transferInPackage.amount)) {
        emit LogTransferInFailureUnknownReason(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/1e10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      emit LogTransferInSuccess(packageSequence, transferInPackage.recipient, transferInPackage.amount, transferInPackage.contractAddr);
      return true;
    } else {
      uint256 bep2Amount = convertToBep2Amount(transferInPackage.amount, bep2eContractDecimals[transferInPackage.contractAddr]);
      if (contractAddrToBEP2Symbol[transferInPackage.contractAddr]!= transferInPackage.bep2TokenSymbol) {
        emit LogTransferInFailureUnboundToken(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      if (block.timestamp > transferInPackage.expireTime) {
        emit LogTransferInFailureTimeout(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      try IBEP2E(transferInPackage.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
        if (actualBalance < transferInPackage.amount) {
          emit LogTransferInFailureInsufficientBalance(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
          return false;
        }
      } catch Error(string memory reason) {
        emit LogTransferInFailureUnknownReason(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        emit LogUnexpectedRevertInBEP2E(transferInPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogTransferInFailureUnknownReason(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        emit LogUnexpectedFailureAssertionInBEP2E(transferInPackage.contractAddr, lowLevelData);
        return false;
      }
      try IBEP2E(transferInPackage.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transferInPackage.recipient, transferInPackage.amount) returns (bool success) {
        if (success) {
          emit LogTransferInSuccess(packageSequence, transferInPackage.recipient, transferInPackage.amount, transferInPackage.contractAddr);
          return true;
        } else {
          emit LogTransferInFailureUnknownReason(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        }
      } catch Error(string memory reason) {
        emit LogTransferInFailureUnknownReason(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        emit LogUnexpectedRevertInBEP2E(transferInPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogTransferInFailureUnknownReason(transferInFailureChannelSequence++, packageSequence, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        emit LogUnexpectedFailureAssertionInBEP2E(transferInPackage.contractAddr, lowLevelData);
        return false;
      }
      return false;
    }
    return false;
  }

  // | length   | refundAmount | contractAddr | refundAddr | transferOutSequence | failureReason |
  // | 32 bytes | 32 bytes     | 20 bytes     | 20 bytes   | 8 bytes             | 2 bytes     |
  function decodeRefundPackage(bytes memory value) internal pure returns(RefundPackage memory) {
    RefundPackage memory refundPackage;

    uint256 ptr;
    assembly {
      ptr := value
    }

    ptr+=32;
    uint256 refundAmount;
    assembly {
      refundAmount := mload(ptr)
    }
    refundPackage.refundAmount = refundAmount;

    ptr+=20;
    address contractAddr;
    assembly {
      contractAddr := mload(ptr)
    }
    refundPackage.contractAddr = contractAddr;

    ptr+=20;
    address payable refundAddr;
    assembly {
      refundAddr := mload(ptr)
    }
    refundPackage.refundAddr = refundAddr;

    ptr+=8;
    uint16 transferOutSequence;
    assembly {
      transferOutSequence := mload(ptr)
    }
    refundPackage.transferOutSequence = transferOutSequence;

    ptr+=2;
    uint16 reason;
    assembly {
      reason := mload(ptr)
    }
    refundPackage.reason = reason;


    return refundPackage;
  }

  function handleRefundPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) sequenceInOrder(packageSequence, refundChannelSequence) blockSynced(height) onlyRelayer override external onlyInit returns (bool) {
    require(msgBytes.length==82, "wrong refund package size");
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(refundChannelSequence,REFUND_CHANNEL_ID), msgBytes, proof), "invalid merkle proof");
    refundChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);
    uint256 reward = refundRelayReward.mul(moleculeForHeaderRelayer).div(denominatorForHeaderRelayer);
    ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(tendermintHeaderSubmitter, reward);
    reward = refundRelayReward.sub(reward);
    ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, reward);

    RefundPackage memory refundPackage = decodeRefundPackage(msgBytes);
    if (refundPackage.contractAddr==address(0x0)) {
      uint256 actualBalance = address(this).balance;
      if (actualBalance < refundPackage.refundAmount) {
        emit LogRefundFailureInsufficientBalance(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return false;
      }
      if (!refundPackage.refundAddr.send(refundPackage.refundAmount)){
        emit LogRefundFailureUnknownReason(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return false;
      }
      emit LogRefundSuccess(packageSequence, refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
      return true;
    } else {
      if (contractAddrToBEP2Symbol[refundPackage.contractAddr]==bytes32(0x00)) {
        emit LogRefundFailureUnboundToken(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return false;
      }
      try IBEP2E(refundPackage.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
        if (actualBalance < refundPackage.refundAmount) {
          emit LogRefundFailureInsufficientBalance(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
          return false;
        }
      } catch Error(string memory reason) {
        emit LogRefundFailureUnknownReason(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        emit LogUnexpectedRevertInBEP2E(refundPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogRefundFailureUnknownReason(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        emit LogUnexpectedFailureAssertionInBEP2E(refundPackage.contractAddr, lowLevelData);
        return false;
      }
      try IBEP2E(refundPackage.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(refundPackage.refundAddr, refundPackage.refundAmount) returns (bool success) {
        if (success) {
          emit LogRefundSuccess(packageSequence, refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
          return true;
        } else {
          emit LogRefundFailureUnknownReason(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        }
      } catch Error(string memory reason) {
        emit LogRefundFailureUnknownReason(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        emit LogUnexpectedRevertInBEP2E(refundPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogRefundFailureUnknownReason(refundPackage.transferOutSequence, refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        emit LogUnexpectedFailureAssertionInBEP2E(refundPackage.contractAddr, lowLevelData);
        return false;
      }
      return false;
    }
    return false;
  }

  function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) override external payable returns (bool) {
    require(relayFee%(1e10)==0, "relayFee is must be N*1e10");
    require(relayFee>=minimumRelayFee, "relayFee is too little");
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    uint256 convertedRelayFee = relayFee.div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    bytes32 bep2TokenSymbol;
    uint256 convertedAmount;
    if (contractAddr==address(0x0)) {
      require(amount%1e10==0, "invalid transfer amount: precision loss in amount conversion");
      require(msg.value==amount.add(relayFee), "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
      convertedAmount = amount.div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
      bep2TokenSymbol=BEP2_TOKEN_SYMBOL_FOR_BNB;
    } else {
      bep2TokenSymbol = contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
      uint256 bep2eTokenDecimals=bep2eContractDecimals[contractAddr];
      require(bep2eTokenDecimals<=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals>BEP2_TOKEN_DECIMALS && amount.mod(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS))==0), "invalid transfer amount: precision loss in amount conversion");
      convertedAmount = convertToBep2Amount(amount, bep2eTokenDecimals);// convert to bep2 amount
      require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amount), "amount is too large, uint256 overflow");
      require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), amount));
    }
    emit LogTransferOut(transferOutChannelSequence++, msg.sender, recipient, convertedAmount, contractAddr, bep2TokenSymbol, expireTime, convertedRelayFee);
    return true;
  }

  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) override external payable returns (bool) {
    require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
    require(recipientAddrs.length == refundAddrs.length, "Length of recipientAddrs doesn't equal to length of refundAddrs");
    require(relayFee.div(amounts.length)>=minimumRelayFee, "relayFee is too little");
    require(relayFee%(1e10)==0, "relayFee must be N*1e10");
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    uint256 totalAmount = 0;
    for (uint i = 0; i < amounts.length; i++) {
      totalAmount = totalAmount.add(amounts[i]);
    }
    uint256[] memory convertedAmounts = new uint256[](amounts.length);
    bytes32 bep2TokenSymbol;
    if (contractAddr==address(0x0)) {
      for (uint8 i = 0; i < amounts.length; i++) {
        require(amounts[i]%1e10==0, "invalid transfer amount");
        convertedAmounts[i] = amounts[i].div(1e10);
      }
      require(msg.value==totalAmount.add(relayFee), "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
      bep2TokenSymbol=BEP2_TOKEN_SYMBOL_FOR_BNB;
    } else {
      uint256 bep2eTokenDecimals=bep2eContractDecimals[contractAddr];
      for (uint i = 0; i < amounts.length; i++) {
        require(bep2eTokenDecimals<=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals>BEP2_TOKEN_DECIMALS && amounts[i].mod(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS))==0), "invalid transfer amount: precision loss in amount conversion");
        uint256 convertedAmount = convertToBep2Amount(amounts[i], bep2eTokenDecimals);// convert to bep2 amount
        require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amounts[i]), "amount is too large, uint256 overflow");
        require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
        convertedAmounts[i] = convertedAmount;
      }
      bep2TokenSymbol = contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), totalAmount));
    }
    emit LogBatchTransferOut(transferOutChannelSequence, convertedAmounts, contractAddr, bep2TokenSymbol, expireTime, relayFee.div(1e10));
    emit LogBatchTransferOutAddrs(transferOutChannelSequence++, recipientAddrs, refundAddrs);
    return true;
  }

  function updateParam(string calldata key, bytes calldata value) override external onlyGov{
    require(value.length == 32, "expected value length is 32");
    string memory localKey = key;
    bytes memory localValue = value;
    bytes32 bytes32Key;
    assembly {
      bytes32Key := mload(add(localKey, 32))
    }
    if (bytes32Key == bytes32(0x6d696e696d756d52656c61794665650000000000000000000000000000000000)){ // minimumRelayFee
      uint256 newMinimumRelayFee;
      assembly {
        newMinimumRelayFee := mload(add(localValue, 32))
      }
      require(newMinimumRelayFee >= 0 && newMinimumRelayFee <= 1e18, "the relayerReward out of range");
      minimumRelayFee = newMinimumRelayFee;
    }else if(bytes32Key == bytes32(0x726566756e6452656c6179526577617264000000000000000000000000000000)){ // refundRelayReward
      uint256 newRefundRelayReward;
      assembly {
        newRefundRelayReward := mload(add(localValue, 32))
      }
      require(newRefundRelayReward >= 0 && newRefundRelayReward <= 1e18, "the refundRelayReward out of range");
      refundRelayReward = newRefundRelayReward;
    }else if (bytes32Key == bytes32(0x6d6f6c6563756c65466f7248656164657252656c617965720000000000000000)){ // moleculeForHeaderRelayer
      uint256 newMoleculeForHeaderRelayer;
      assembly {
        newMoleculeForHeaderRelayer := mload(add(localValue, 32))
      }
      moleculeForHeaderRelayer = newMoleculeForHeaderRelayer;
    }else if (bytes32Key == bytes32(0x64656e6f6d696e61746f72466f7248656164657252656c617965720000000000)){ // denominatorForHeaderRelayer
       uint256 newDenominatorForHeaderRelayer;
       assembly {
         newDenominatorForHeaderRelayer := mload(add(localValue, 32))
       }
       require(newDenominatorForHeaderRelayer != 0, "the denominatorForHeaderRelayer must not be zero");
       denominatorForHeaderRelayer = newDenominatorForHeaderRelayer;
     }else{
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }
}
