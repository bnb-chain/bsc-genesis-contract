pragma solidity 0.6.4;

import "./interface/IERC20.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";
import "./MerkleProof.sol";


contract TokenHub is ITokenHub {

  struct BindPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 totalSupply;
    uint256 peggyAmount;
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

  uint8 constant bindChannelID = 0x01;
  uint8 constant transferInChannelID = 0x02;
  uint8 constant refundChannelID=0x03;
  // the store name of the package
  string constant STORE_NAME = "ibc";

  bytes32 constant bep2TokenSymbolForBNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
  bytes32 constant crossChainKeyPrefix = 0x000000000000000000000000000000000000000000000000000000000003000f; // last 5 bytes


  uint256 constant public _minimumRelayFee=10000000000000000;
  uint256 constant public _refundRelayReward=10000000000000000;
  address constant public _systemRewardContract=0x0000000000000000000000000000000000001002;
  address constant public _lightClientContract=0x0000000000000000000000000000000000001003;
  address constant public _incentivizeContractForHeaderSyncRelayers=0x0000000000000000000000000000000000001005;
  address constant public _incentivizeContractForTransferRelayers=0x0000000000000000000000000000000000001006;


  mapping(bytes32 => BindPackage) public _bindPackageRecord;
  mapping(address => bytes32) public _contractAddrToBEP2Symbol;
  mapping(bytes32 => address) public _bep2SymbolToContractAddr;

  uint256 public _bindChannelSequence=0;
  uint256 public _transferInChannelSequence=0;
  uint256 public _refundChannelSequence=0;

  uint256 public _transferOutChannelSequence=0;
  uint256 public _bindResponseChannelSequence=0;
  uint256 public _transferInFailureChannelSequence=0;

  event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
  event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals);
  event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol);
  event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol);
  event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol);

  event LogTransferOut(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);
  event LogBatchTransferOut(uint256 sequence, uint256[] amounts, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);

  event LogTransferInSuccess(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr);
  event LogTransferInFailureTimeout(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime);
  event LogTransferInFailureInsufficientBalance(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 actualBalance);
  event LogTransferInFailureUnboundToken(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol);

  event LogRefundSuccess(address contractAddr, address refundAddr, uint256 amount, uint16 reason);
  event LogRefundFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint16 reason, uint256 actualBalance);
  event LogRefundFailureUnboundToken(address contractAddr, address refundAddr, uint256 amount, uint16 reason);

  event LogUnexpectedRevertInERC20(address contractAddr, string reason);
  event LogUnexpectedFailureAssertionInERC20(address contractAddr, bytes lowLevelData);

  constructor() public {}


  function bep2TokenSymbolConvert(string memory symbol) public pure returns(bytes32) {
    bytes32 result;
    assembly {
      result := mload(add(symbol, 32))
    }
    return result;
  }

  //TODO need further discussion
  function calculateRewardForTendermintHeaderRelayer(uint256 reward) internal pure returns (uint256) {
    return reward/5; //20%
  }
  // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
  // | 32 bytes | 1 byte | 2 bytes    | 2 bytes      |  1 bytes  | 8 bytes  |
  function generateKey(uint8 channelID, uint256 sequence) internal pure returns(bytes memory) {
    bytes memory key = new bytes(14);

    uint256 ptr;
    assembly {
      ptr := add(key, 14)
    }


    assembly {
      mstore(ptr, sequence)
    }
    ptr -= 8;


    assembly {
      mstore(ptr, channelID)
    }
    ptr -= 1;

    assembly {
      mstore(ptr, crossChainKeyPrefix)
    }
    ptr -= 5;

    assembly {
      mstore(ptr, 14)
    }

    return key;
  }

  // | length   | bep2TokenSymbol | contractAddr | totalSupply | peggyAmount | expireTime | relayFee |
  // | 32 bytes | 32 bytes    | 20 bytes   |  32 bytes   | 32 bytes  | 8 bytes  | 32 bytes  |
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

  function handleBindPackage(uint64 height,  bytes calldata value, bytes calldata proof) override external returns (bool) {
    require(value.length==156, "wrong bind package size");
    require(ILightClient(_lightClientContract).isHeaderSynced(height));
    bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(bindChannelID, _bindChannelSequence), value, proof), "invalid merkle proof");
    _bindChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

    BindPackage memory bindPackage = decodeBindPackage(value);

    uint256 reward = calculateRewardForTendermintHeaderRelayer(bindPackage.relayFee);
    IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward{value: reward}(tendermintHeaderSubmitter);
    reward = bindPackage.relayFee-reward;
    // TODO maybe the reward should be paid to msg.sender directly
    IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward{value: reward}(msg.sender);

    _bindPackageRecord[bindPackage.bep2TokenSymbol]=bindPackage;
    emit LogBindRequest(bindPackage.contractAddr, bindPackage.bep2TokenSymbol, bindPackage.totalSupply, bindPackage.peggyAmount);
    return true;
  }

  function checkSymbol(string memory erc20Symbol, bytes32 bep2TokenSymbol) public pure returns(bool) {
    bytes memory erc20SymbolBytes = bytes(erc20Symbol);
    //Upper case string
    for (uint i = 0; i < erc20SymbolBytes.length; i++) {
      if (0x61 <= uint8(erc20SymbolBytes[i]) && uint8(erc20SymbolBytes[i]) <= 0x7A) {
        erc20SymbolBytes[i] = byte(uint8(erc20SymbolBytes[i]) - 0x20);
      }
    }

    bytes memory bep2TokenSymbolBytes = new bytes(32);
    assembly {
      mstore(add(bep2TokenSymbolBytes, 32), bep2TokenSymbol)
    }
    bool symbolMatch = true;
    for(uint256 index=0; index < erc20SymbolBytes.length; index++) {
      if (erc20SymbolBytes[index] != bep2TokenSymbolBytes[index]) {
        symbolMatch = false;
        break;
      }
    }
    return symbolMatch;
  }

  function approveBind(address contractAddr, bytes32 bep2TokenSymbol) public returns (bool) {
    BindPackage memory bindPackage = _bindPackageRecord[bep2TokenSymbol];
    uint256 lockedAmount = bindPackage.totalSupply-bindPackage.peggyAmount;
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IERC20(contractAddr).getOwner()==msg.sender, "only erc20 owner can approve this bind request");
    require(IERC20(contractAddr).allowance(msg.sender, address(this))==lockedAmount, "allowance doesn't equal to (totalSupply - peggyAmount)");

    if (bindPackage.expireTime<block.timestamp) {
      emit LogBindTimeout(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
      delete _bindPackageRecord[bep2TokenSymbol];
      return false;
    }

    string memory erc20Symbol = IERC20(contractAddr).symbol();
    if (!checkSymbol(erc20Symbol, bep2TokenSymbol) ||
      _bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol]!=address(0x00)||
      _contractAddrToBEP2Symbol[bindPackage.contractAddr]!=bytes32(0x00)||
      IERC20(bindPackage.contractAddr).totalSupply()!=bindPackage.totalSupply) {
      delete _bindPackageRecord[bep2TokenSymbol];
      emit LogBindInvalidParameter(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
      return false;
    }
    IERC20(contractAddr).transferFrom(msg.sender, address(this), lockedAmount);
    _contractAddrToBEP2Symbol[bindPackage.contractAddr] = bindPackage.bep2TokenSymbol;
    _bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol] = bindPackage.contractAddr;

    delete _bindPackageRecord[bep2TokenSymbol];
    uint256 decimals = IERC20(contractAddr).decimals();
    emit LogBindSuccess(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol, bindPackage.totalSupply, bindPackage.peggyAmount, decimals);
    return true;
  }

  function rejectBind(address contractAddr, bytes32 bep2TokenSymbol) public returns (bool) {
    BindPackage memory bindPackage = _bindPackageRecord[bep2TokenSymbol];
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IERC20(contractAddr).getOwner()==msg.sender, "only erc20 owner can reject");
    delete _bindPackageRecord[bep2TokenSymbol];
    emit LogBindRejected(_bindResponseChannelSequence++, bindPackage.contractAddr, bindPackage.bep2TokenSymbol);
    return true;
  }

  function expireBind(bytes32 bep2TokenSymbol) public returns (bool) {
    BindPackage memory bindPackage = _bindPackageRecord[bep2TokenSymbol];
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

  function handleTransferInPackage(uint64 height, bytes calldata value, bytes calldata proof) override external returns (bool) {
    require(value.length==164, "wrong transfer package size");
    require(ILightClient(_lightClientContract).isHeaderSynced(height));
    bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(transferInChannelID, _transferInChannelSequence), value, proof), "invalid merkle proof");
    _transferInChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

    TransferInPackage memory transferInPackage = decodeTransferInPackage(value);

    uint256 reward = calculateRewardForTendermintHeaderRelayer(transferInPackage.relayFee);
    IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward{value: reward}(tendermintHeaderSubmitter);
    reward = transferInPackage.relayFee-reward;
    IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward{value: reward}(msg.sender);

    if (transferInPackage.contractAddr==address(0x0) && transferInPackage.bep2TokenSymbol==bep2TokenSymbolForBNB) {
      if (block.timestamp > transferInPackage.expireTime) {
        emit LogTransferInFailureTimeout(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/10**10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, transferInPackage.expireTime);
        return false;
      }
      if (address(this).balance < transferInPackage.amount) {
        emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount/10**10, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, address(this).balance);
        return false;
      }
      transferInPackage.recipient.transfer(transferInPackage.amount);
      emit LogTransferInSuccess(_transferInChannelSequence-1, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount, transferInPackage.contractAddr);
      return true;
    } else {
      uint256 bep2Amount;
      try IERC20(transferInPackage.contractAddr).decimals() returns (uint256 decimals) {
        bep2Amount = transferInPackage.amount * (10**8) / (10**decimals);
      } catch Error(string memory reason) {
        emit LogUnexpectedRevertInERC20(transferInPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogUnexpectedFailureAssertionInERC20(transferInPackage.contractAddr, lowLevelData);
        return false;
      }
      if (_contractAddrToBEP2Symbol[transferInPackage.contractAddr]!= transferInPackage.bep2TokenSymbol) {
        emit LogTransferInFailureUnboundToken(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol);
        return false;
      }
      if (block.timestamp > transferInPackage.expireTime) {
        emit LogTransferInFailureTimeout(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, transferInPackage.expireTime);
        return false;
      }
      try IERC20(transferInPackage.contractAddr).transfer(transferInPackage.recipient, transferInPackage.amount) returns (bool success) {
        if (success) {
          emit LogTransferInSuccess(_transferInChannelSequence-1, transferInPackage.refundAddr, transferInPackage.recipient, transferInPackage.amount, transferInPackage.contractAddr);
          return true;
        } else {
          try IERC20(transferInPackage.contractAddr).balanceOf(address(this)) returns (uint256 actualBalance) {
            emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, transferInPackage.refundAddr, transferInPackage.recipient, bep2Amount, transferInPackage.contractAddr, transferInPackage.bep2TokenSymbol, actualBalance);
            return false;
          } catch Error(string memory reason) {
            emit LogUnexpectedRevertInERC20(transferInPackage.contractAddr, reason);
            return false;
          } catch (bytes memory lowLevelData) {
            emit LogUnexpectedFailureAssertionInERC20(transferInPackage.contractAddr, lowLevelData);
            return false;
          }
        }
      } catch Error(string memory reason) {
        emit LogUnexpectedRevertInERC20(transferInPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogUnexpectedFailureAssertionInERC20(transferInPackage.contractAddr, lowLevelData);
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

  function handleRefundPackage(uint64 height, bytes calldata value, bytes calldata proof) override external returns (bool) {
    require(value.length==74, "wrong refund package size");
    require(ILightClient(_lightClientContract).isHeaderSynced(height));
    bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
    require(MerkleProof.validateMerkleProof(appHash, STORE_NAME, generateKey(refundChannelID, _refundChannelSequence), value, proof), "invalid merkle proof");
    _refundChannelSequence++;

    address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);
    //TODO system reward, need further discussion,
    //TODO taking malicious refund cases caused by inconsistent total supply into consideration, so this reward must be less than minimum relay fee
    uint256 reward = calculateRewardForTendermintHeaderRelayer(_refundRelayReward);
    ISystemReward(_systemRewardContract).claimRewards(tendermintHeaderSubmitter, reward);
    reward = _refundRelayReward-reward;
    ISystemReward(_systemRewardContract).claimRewards(msg.sender, reward);

    RefundPackage memory refundPackage = decodeRefundPackage(value);
    if (refundPackage.contractAddr==address(0x0)) {
      uint256 actualBalance = address(this).balance;
      if (actualBalance < refundPackage.refundAmount) {
        emit LogRefundFailureInsufficientBalance(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason, actualBalance);
        return false;
      }
      refundPackage.refundAddr.transfer(refundPackage.refundAmount);
      emit LogRefundSuccess(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
      return true;
    } else {
      if (_contractAddrToBEP2Symbol[refundPackage.contractAddr]==bytes32(0x00)) {
        emit LogRefundFailureUnboundToken(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return false;
      }
      try IERC20(refundPackage.contractAddr).transfer(refundPackage.refundAddr, refundPackage.refundAmount) returns (bool success) {
        if (success) {
          emit LogRefundSuccess(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
          return true;
        } else {
          try IERC20(refundPackage.contractAddr).balanceOf(address(this)) returns (uint256 actualBalance) {
            emit LogRefundFailureInsufficientBalance(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason, actualBalance);
            return false;
          } catch Error(string memory reason) {
            emit LogUnexpectedRevertInERC20(refundPackage.contractAddr, reason);
            return false;
          } catch (bytes memory lowLevelData) {
            emit LogUnexpectedFailureAssertionInERC20(refundPackage.contractAddr, lowLevelData);
            return false;
          }
        }
      } catch Error(string memory reason) {
        emit LogUnexpectedRevertInERC20(refundPackage.contractAddr, reason);
        return false;
      } catch (bytes memory lowLevelData) {
        emit LogUnexpectedFailureAssertionInERC20(refundPackage.contractAddr, lowLevelData);
        return false;
      }
    }
  }

  function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) override external payable returns (bool) {
    require(relayFee%(10**10)==0, "relayFee is must be N*10^10");
    require(relayFee>=_minimumRelayFee, "relayFee is too little");
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    uint256 convertedRelayFee = relayFee / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    bytes32 bep2TokenSymbol;
    uint256 convertedAmount;
    if (contractAddr==address(0x0)) {
      require(msg.value==amount+relayFee, "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
      convertedAmount = amount / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
      bep2TokenSymbol=bep2TokenSymbolForBNB;
    } else {
      uint256 erc20TokenDecimals=IERC20(contractAddr).decimals();
      if (erc20TokenDecimals > 8) {
        uint256 extraPrecision = 10**(erc20TokenDecimals-8);
        require(amount%extraPrecision==0, "invalid transfer amount: precision loss in amount conversion");
      }
      bep2TokenSymbol = _contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
      require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount));
      convertedAmount = amount * (10**8)/ (10**erc20TokenDecimals); // bep2 token decimals is 8 on BBC
    }
    emit LogTransferOut(_transferOutChannelSequence++, msg.sender, recipient, convertedAmount, contractAddr, bep2TokenSymbol, expireTime, convertedRelayFee);
    return true;
  }

  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) override external payable returns (bool) {
    require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
    require(recipientAddrs.length == refundAddrs.length, "Length of recipientAddrs doesn't equal to length of refundAddrs");
    require(relayFee/amounts.length>=_minimumRelayFee, "relayFee is too little");
    require(relayFee%(10**10)==0, "relayFee must be N*10^10");
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    uint256 totalAmount = 0;
    for (uint i = 0; i < amounts.length; i++) {
      totalAmount += amounts[i];
    }
    uint256[] memory convertedAmounts = new uint256[](amounts.length);
    bytes32 bep2TokenSymbol;
    if (contractAddr==address(0x0)) {
      for (uint8 i = 0; i < amounts.length; i++) {
        require(amounts[i]%10**10==0, "invalid transfer amount");
        convertedAmounts[i] = amounts[i]/10**10;
      }
      require(msg.value==totalAmount+relayFee, "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
      bep2TokenSymbol=bep2TokenSymbolForBNB;
    } else {
      uint256 erc20TokenDecimals=IERC20(contractAddr).decimals();
      for (uint i = 0; i < amounts.length; i++) {
        require((amounts[i]*(10**8)%(10**erc20TokenDecimals))==0, "invalid transfer amount");
        convertedAmounts[i] = amounts[i]*(10**8)/(10**erc20TokenDecimals);
      }
      bep2TokenSymbol = _contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
      require(IERC20(contractAddr).transferFrom(msg.sender, address(this), totalAmount));
    }
    emit LogBatchTransferOut(_transferOutChannelSequence++, convertedAmounts, contractAddr, bep2TokenSymbol, expireTime, relayFee/(10**10));
    return true;
  }
}