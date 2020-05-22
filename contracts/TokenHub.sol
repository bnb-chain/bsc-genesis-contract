pragma solidity 0.6.4;

import "./interface/IBEP2E.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";
import "./interface/IRelayerHub.sol";
import "./System.sol";
import "./lib/SafeMath.sol";
import "./MerkleProof.sol";


contract TokenHub is ITokenHub, System{

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

  //TODO  Add governance later
  uint256 constant public minimumRelayFee=1e16;
  uint256 constant public refundRelayReward=1e16;
  uint256 constant public moleculeHeaderRelayerSystemReward = 1;
  uint256 constant public denominaroeHeaderRelayerSystemReward = 5;

  mapping(bytes32 => BindPackage) public _bindPackageRecord;
  mapping(address => bytes32) public _contractAddrToBEP2Symbol;
  mapping(address => uint256) public _bep2eContractDecimals;
  mapping(bytes32 => address) public _bep2SymbolToContractAddr;

  uint64 public _bindChannelSequence=0;
  uint64 public _transferInChannelSequence=0;
  uint64 public _refundChannelSequence=0;

  uint64 public _transferOutChannelSequence=0;
  uint64 public _bindResponseChannelSequence=0;
  uint64 public _transferInFailureChannelSequence=0;

  event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
  event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals);
  event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol);
  event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol);
  event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol);

  event LogTransferOut(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);
  event LogBatchTransferOut(uint256 sequence, uint256[] amounts, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);
  event LogBatchTransferOutAddrs(uint256 sequence, address[] recipientAddrs, address[] refundAddrs);

  event LogTransferInSuccess(uint256 sequence, address recipient, uint256 amount, address contractAddr);
  event LogTransferInFailureTimeout(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime);
  event LogTransferInFailureInsufficientBalance(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 actualBalance);
  event LogTransferInFailureUnboundToken(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol);
  event LogTransferInFailureUnknownReason(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol);

  event LogRefundSuccess(address contractAddr, address refundAddr, uint256 amount, uint16 reason);
  event LogRefundFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint16 reason, uint256 actualBalance);
  event LogRefundFailureUnboundToken(address contractAddr, address refundAddr, uint256 amount, uint16 reason);
  event LogRefundFailureUnknownReason(address contractAddr, address refundAddr, uint256 amount, uint16 reason);

  event LogUnexpectedRevertInBEP2E(address contractAddr, string reason);
  event LogUnexpectedFailureAssertionInBEP2E(address contractAddr, bytes lowLevelData);

  constructor() public {}
  
  

  modifier sequenceInOrder(uint64 sequence, uint64 expectedSequence) {
    require(sequence == expectedSequence, "sequence not in order");
    _;
  }

  function bep2TokenSymbolConvert(string memory symbol) public pure returns(bytes32) {
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

  function handleBindPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) sequenceInOrder(packageSequence, _bindChannelSequence) blockSynced(height) onlyRelayer override external returns (bool) {
    require(msgBytes.length==157, "wrong bind package size");
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(_bindChannelSequence, BIND_CHANNEL_ID), msgBytes, proof), "invalid merkle proof");
    _bindChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);
    BindPackage memory bindPackage = decodeBindPackage(msgBytes);
    IRelayerIncentivize(INCENTIVIZE_ADDR).addReward{value: bindPackage.relayFee}(tendermintHeaderSubmitter, msg.sender);

    _bindPackageRecord[bindPackage.bep2TokenSymbol]=bindPackage;
    emit LogBindRequest(bindPackage.contractAddr, bindPackage.bep2TokenSymbol, bindPackage.totalSupply, bindPackage.peggyAmount);
    return true;
  }

  function checkSymbol(string memory bep2eSymbol, bytes32 bep2TokenSymbol) public pure returns(bool) {
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

  function convertToBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) public pure returns (uint256) {
    if (bep2eTokenDecimals > BEP2_TOKEN_DECIMALS) {
      return amount.div(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS));
    }
    return amount.mul(10**(BEP2_TOKEN_DECIMALS-bep2eTokenDecimals));
  }

  function approveBind(address contractAddr, string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindPackage memory bindPackage = _bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    uint256 lockedAmount = bindPackage.totalSupply.sub(bindPackage.peggyAmount);
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can approve this bind request");
    require(IBEP2E(contractAddr).allowance(msg.sender, address(this))==lockedAmount, "allowance doesn't equal to (totalSupply - peggyAmount)");

    if (bindPackage.expireTime<block.timestamp) {
      emit LogBindTimeout(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
      delete _bindPackageRecord[bep2TokenSymbol];
      return false;
    }

    uint256 decimals = IBEP2E(contractAddr).decimals();
    string memory bep2eSymbol = IBEP2E(contractAddr).symbol();
    if (!checkSymbol(bep2eSymbol, bep2TokenSymbol) ||
      _bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol]!=address(0x00)||
      _contractAddrToBEP2Symbol[bindPackage.contractAddr]!=bytes32(0x00)||
      IBEP2E(bindPackage.contractAddr).totalSupply()!=bindPackage.totalSupply||
      decimals!=bindPackage.bep2eDecimals) {
      delete _bindPackageRecord[bep2TokenSymbol];
      emit LogBindInvalidParameter(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
      return false;
    }
    IBEP2E(contractAddr).transferFrom(msg.sender, address(this), lockedAmount);
    _contractAddrToBEP2Symbol[bindPackage.contractAddr] = bindPackage.bep2TokenSymbol;
    _bep2eContractDecimals[bindPackage.contractAddr] = bindPackage.bep2eDecimals;
    _bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol] = bindPackage.contractAddr;

    delete _bindPackageRecord[bep2TokenSymbol];
    emit LogBindSuccess(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol, bindPackage.totalSupply, bindPackage.peggyAmount, decimals);
    return true;
  }

  function rejectBind(address contractAddr, string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindPackage memory bindPackage = _bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can reject");
    delete _bindPackageRecord[bep2TokenSymbol];
    emit LogBindRejected(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
    return true;
  }

  function expireBind(string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindPackage memory bindPackage = _bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(bindPackage.expireTime<block.timestamp, "bind request is not expired");
    delete _bindPackageRecord[bep2TokenSymbol];
    emit LogBindTimeout(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
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

  function handleTransferInPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) sequenceInOrder(packageSequence, _transferInChannelSequence) blockSynced(height) onlyRelayer override external returns (bool) {
    require(msgBytes.length==164, "wrong transfer package size");
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(_transferInChannelSequence, TRANSFER_IN_CHANNEL_ID), msgBytes, proof), "invalid merkle proof");
    _transferInChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);
    TransferInPackage memory transferInPackage = decodeTransferInPackage(msgBytes);
    IRelayerIncentivize(INCENTIVIZE_ADDR).addReward{value: transferInPackage.relayFee}(tendermintHeaderSubmitter, msg.sender);

    if (transferInPackage.contractAddr==address(0x0) && transferInPackage.bep2TokenSymbol==BEP2_TOKEN_SYMBOL_FOR_BNB) {
      if (block.timestamp > transferInPackage.expireTime) {
        emit LogTransferInFailureTimeout(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/1e10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, transferInPackage.expireTime);
        return false;
      }
      if (address(this).balance < transferInPackage.amount) {
        emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/1e10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, address(this).balance);
        return false;
      }
      if (!transferInPackage.recipient.send(transferInPackage.amount)) {
        emit LogTransferInFailureUnknownReason(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/1e10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      emit LogTransferInSuccess(_transferInChannelSequence-1, transferInPackage.recipient, transferInPackage.amount, transferInPackage.contractAddr);
      return true;
    } else {
      uint256 bep2Amount = convertToBep2Amount(transferInPackage.amount, _bep2eContractDecimals[transferInPackage.contractAddr]);
      if (_contractAddrToBEP2Symbol[transferInPackage.contractAddr]!= transferInPackage.bep2TokenSymbol) {
        emit LogTransferInFailureUnboundToken(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      if (block.timestamp > transferInPackage.expireTime) {
        emit LogTransferInFailureTimeout(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, transferInPackage.expireTime);
        return false;
      }
      try IBEP2E(transferInPackage.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transferInPackage.recipient, transferInPackage.amount) returns (bool success) {
        if (success) {
          emit LogTransferInSuccess(_transferInChannelSequence-1, transferInPackage.recipient, transferInPackage.amount, transferInPackage.contractAddr);
          return true;
        } else {
          try IBEP2E(transferInPackage.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
            emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, actualBalance);
            return false;
          } catch Error(string memory reason) {
            emit LogTransferInFailureUnknownReason(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
            emit LogUnexpectedRevertInBEP2E(transferInPackage.contractAddr, reason);
            return false;
          } catch (bytes memory lowLevelData) {
            emit LogTransferInFailureUnknownReason(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
            emit LogUnexpectedFailureAssertionInBEP2E(transferInPackage.contractAddr, lowLevelData);
            return false;
          }
        }
      } catch Error(string memory reason) {
        emit LogTransferInFailureUnknownReason(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        emit LogUnexpectedRevertInBEP2E(transferInPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogTransferInFailureUnknownReason(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        emit LogUnexpectedFailureAssertionInBEP2E(transferInPackage.contractAddr, lowLevelData);
        return false;
      }
    }
  }

  // | length   | refundAmount | contractAddr | refundAddr | failureReason |
  // | 32 bytes | 32 bytes   | 20 bytes   | 20 bytes   | 2 bytes     |
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

    ptr+=2;
    uint16 reason;
    assembly {
      reason := mload(ptr)
    }
    refundPackage.reason = reason;


    return refundPackage;
  }

  function handleRefundPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) sequenceInOrder(packageSequence, _refundChannelSequence) blockSynced(height) onlyRelayer override external returns (bool) {
    require(msgBytes.length==74, "wrong refund package size");
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(_refundChannelSequence,REFUND_CHANNEL_ID), msgBytes, proof), "invalid merkle proof");
    _refundChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);
    uint256 reward = refundRelayReward.mul(moleculeHeaderRelayerSystemReward).div(denominaroeHeaderRelayerSystemReward);
    //TODO ensure reward is in (0, 1e18)
    ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(tendermintHeaderSubmitter, reward);
    reward = refundRelayReward.sub(reward);
    //TODO ensure reward is in (0, 1e18)
    ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, reward);

    RefundPackage memory refundPackage = decodeRefundPackage(msgBytes);
    if (refundPackage.contractAddr==address(0x0)) {
      uint256 actualBalance = address(this).balance;
      if (actualBalance < refundPackage.refundAmount) {
        emit LogRefundFailureInsufficientBalance(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason, actualBalance);
        return false;
      }
      if (!refundPackage.refundAddr.send(refundPackage.refundAmount)){
        emit LogRefundFailureUnknownReason(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return false;
      }
      emit LogRefundSuccess(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
      return true;
    } else {
      if (_contractAddrToBEP2Symbol[refundPackage.contractAddr]==bytes32(0x00)) {
        emit LogRefundFailureUnboundToken(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return false;
      }
      try IBEP2E(refundPackage.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(refundPackage.refundAddr, refundPackage.refundAmount) returns (bool success) {
        if (success) {
          emit LogRefundSuccess(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
          return true;
        } else {
          try IBEP2E(refundPackage.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
            emit LogRefundFailureInsufficientBalance(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason, actualBalance);
            return false;
          } catch Error(string memory reason) {
            emit LogRefundFailureUnknownReason(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
            emit LogUnexpectedRevertInBEP2E(refundPackage.contractAddr, reason);
            return false;
          } catch (bytes memory lowLevelData) {
            emit LogRefundFailureUnknownReason(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
            emit LogUnexpectedFailureAssertionInBEP2E(refundPackage.contractAddr, lowLevelData);
            return false;
          }
        }
      } catch Error(string memory reason) {
        emit LogRefundFailureUnknownReason(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        emit LogUnexpectedRevertInBEP2E(refundPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogRefundFailureUnknownReason(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        emit LogUnexpectedFailureAssertionInBEP2E(refundPackage.contractAddr, lowLevelData);
        return false;
      }
    }
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
      bep2TokenSymbol = _contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
      uint256 bep2eTokenDecimals=_bep2eContractDecimals[contractAddr];
      require(bep2eTokenDecimals<=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals>BEP2_TOKEN_DECIMALS && amount.mod(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS))==0), "invalid transfer amount: precision loss in amount conversion");
      convertedAmount = convertToBep2Amount(amount, bep2eTokenDecimals);// convert to bep2 amount
      require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amount), "amount is too large, uint256 overflow");
      require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), amount));
    }
    emit LogTransferOut(_transferOutChannelSequence++, msg.sender, recipient, convertedAmount, contractAddr, bep2TokenSymbol, expireTime, convertedRelayFee);
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
      uint256 bep2eTokenDecimals=_bep2eContractDecimals[contractAddr];
      for (uint i = 0; i < amounts.length; i++) {
        require(bep2eTokenDecimals<=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals>BEP2_TOKEN_DECIMALS && amounts[i].mod(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS))==0), "invalid transfer amount: precision loss in amount conversion");
        uint256 convertedAmount = convertToBep2Amount(amounts[i], bep2eTokenDecimals);// convert to bep2 amount
        require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amounts[i]), "amount is too large, uint256 overflow");
        require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
        convertedAmounts[i] = convertedAmount;
      }
      bep2TokenSymbol = _contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), totalAmount));
    }
    emit LogBatchTransferOut(_transferOutChannelSequence, convertedAmounts, contractAddr, bep2TokenSymbol, expireTime, relayFee.div(1e10));
    emit LogBatchTransferOutAddrs(_transferOutChannelSequence++, recipientAddrs, refundAddrs);
    return true;
  }
}
