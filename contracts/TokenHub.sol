pragma solidity 0.6.4;

import "./interface/IBEP2E.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/Application.sol";
import "./System.sol";
import "./lib/SafeMath.sol";

contract TokenHub is ITokenHub, System, IParamSubscriber, Application {

  using SafeMath for uint256;

  struct BindSyncPackage {
    uint8   packageType;
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 totalSupply;
    uint256 peggyAmount;
    uint8   bep2eDecimals;
    uint64  expireTime;
  }

  struct TransferOutAckPackage {
    uint256 refundAmount;
    address contractAddr;
    address payable refundAddr;
    uint64  transferOutSequence;
    uint16  reason;
  }

  struct TransferInSyncPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    address refundAddr;
    address payable recipient;
    uint256 amount;
    uint64  expireTime;
  }


  uint8 constant public   BIND_PACKAGE = 0x00;
  uint8 constant public   UNBIND_PACKAGE = 0x01;

  uint8 constant public   BIND_CHANNEL_ID = 0x01;
  uint8 constant public   TRANSFER_IN_CHANNEL_ID = 0x02;
  uint8 constant public   REFUND_CHANNEL_ID=0x03;

  uint256 constant public MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
  uint8 constant public   MINIMUM_BEP2E_SYMBOL_LEN = 3;
  uint8 constant public   MAXIMUM_BEP2E_SYMBOL_LEN = 8;
  uint8 constant public   BEP2_TOKEN_DECIMALS = 8;
  bytes32 constant public BEP2_TOKEN_SYMBOL_FOR_BNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
  uint256 constant public MAX_GAS_FOR_CALLING_BEP2E=50000;

  uint256 constant public INIT_MINIMUM_SYNC_RELAY_FEE=1e16;
  uint256 constant public INIT_MINIMUM_ACK_RELAY_FEE=1e16;

  uint256 public syncRelayFee;
  uint256 public ackRelayFee;

  mapping(bytes32 => BindSyncPackage) public bindPackageRecord;
  mapping(address => uint256) public bep2eContractDecimals;
  mapping(address => bytes32) private contractAddrToBEP2Symbol;
  mapping(bytes32 => address) private bep2SymbolToContractAddr;

  event LogUnexpectedRevertInBEP2E(address indexed contractAddr, string reason);
  event LogUnexpectedFailureAssertionInBEP2E(address indexed contractAddr, bytes lowLevelData);

  event paramChange(string key, bytes value);

  constructor() public {}
  
  function init() onlyNotInit external {
    syncRelayFee = INIT_MINIMUM_SYNC_RELAY_FEE;
    ackRelayFee = INIT_MINIMUM_ACK_RELAY_FEE;
    alreadyInit=true;
  }
  

  function getRelayFee() external override returns(uint256, uint256) {
    return (syncRelayFee, ackRelayFee);
  }

  function bep2TokenSymbolConvert(string memory symbol) internal pure returns(bytes32) {
    bytes32 result;
    assembly {
      result := mload(add(symbol, 32))
    }
    return result;
  }

  function handleSyncPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override returns(bytes memory responsePayload){
    if (channelId == BIND_CHANNELID) {
      handleBindSyncPackage(msgBytes);
    } else if (channelId == TRANSFER_IN_CHANNELID) {
      handleTransferInSyncPackage(msgBytes);
    } else {

    }
    return new bytes(0);
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    if (channelId == TRANSFER_OUT_CHANNELID) {
      handleTransferOutAckPackage(msgBytes);
    }
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {

  }

  // | length   | bep2TokenSymbol | contractAddr | totalSupply | peggyAmount | decimals | expireTime | relayFee |
  // | 32 bytes | 32 bytes        | 20 bytes     |  32 bytes   | 32 bytes    | 1 byte   | 8 bytes    | 32 bytes |
  function decodeBindPackage(bytes memory value) internal pure returns(BindSyncPackage memory) {
    BindSyncPackage memory bindPackage;

    uint256 ptr;
    assembly {
      ptr := value
    }

    uint8 packageType;
    ptr+=1;
    assembly {
      packageType := mload(ptr)
    }
    bindPackage.packageType = packageType;

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

    return bindPackage;
  }

  function handleBindSyncPackage(bytes memory payload) onlyInit internal {
    BindSyncPackage memory bindPackage = decodeBindPackage(payload);
    bindPackageRecord[bindPackage.bep2TokenSymbol]=bindPackage;
    // Cross Chain sendPackage
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
    BindSyncPackage memory bindPackage = bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    uint256 lockedAmount = bindPackage.totalSupply.sub(bindPackage.peggyAmount);
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can approve this bind request");
    require(IBEP2E(contractAddr).allowance(msg.sender, address(this))==lockedAmount, "allowance doesn't equal to (totalSupply - peggyAmount)");

    if (bindPackage.expireTime<block.timestamp) {
      delete bindPackageRecord[bep2TokenSymbol];
      // Cross Chain sendPackage
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
      // Cross Chain sendPackage
      return false;
    }
    IBEP2E(contractAddr).transferFrom(msg.sender, address(this), lockedAmount);
    contractAddrToBEP2Symbol[bindPackage.contractAddr] = bindPackage.bep2TokenSymbol;
    bep2eContractDecimals[bindPackage.contractAddr] = bindPackage.bep2eDecimals;
    bep2SymbolToContractAddr[bindPackage.bep2TokenSymbol] = bindPackage.contractAddr;

    delete bindPackageRecord[bep2TokenSymbol];
    // Cross Chain sendPackage
    return true;
  }

  function rejectBind(address contractAddr, string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindPackage = bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(contractAddr==bindPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can reject");
    delete bindPackageRecord[bep2TokenSymbol];
    // Cross Chain sendPackage
    return true;
  }

  function expireBind(string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindPackage = bindPackageRecord[bep2TokenSymbol];
    require(bindPackage.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(bindPackage.expireTime<block.timestamp, "bind request is not expired");
    delete bindPackageRecord[bep2TokenSymbol];
    // Cross Chain sendPackage
    return true;
  }

  // | length   | bep2TokenSymbol | contractAddr | sender   | recipient | amount   | expireTime | relayFee |
  // | 32 bytes | 32 bytes    | 20 bytes   | 20 bytes | 20 bytes  | 32 bytes | 8 bytes  | 32 bytes  |
  function decodeTransferInPackage(bytes memory value) internal pure returns (TransferInSyncPackage memory) {
    TransferInSyncPackage memory transferInPackage;

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

    return transferInPackage;
  }

  function handleTransferInSyncPackage(bytes memory payload) onlyInit internal {
    TransferInSyncPackage memory transferInPackage = decodeTransferInPackage(payload);

    if (transferInPackage.contractAddr==address(0x0) && transferInPackage.bep2TokenSymbol==BEP2_TOKEN_SYMBOL_FOR_BNB) {
      if (block.timestamp > transferInPackage.expireTime) {
        // Cross Chain sendPackage
        return;
      }
      if (address(this).balance < transferInPackage.amount) {
        // Cross Chain sendPackage
        return;
      }
      if (!transferInPackage.recipient.send(transferInPackage.amount)) {
        // Cross Chain sendPackage
        return;
      }
      return;
    } else {
      uint256 bep2Amount = convertToBep2Amount(transferInPackage.amount, bep2eContractDecimals[transferInPackage.contractAddr]);
      if (contractAddrToBEP2Symbol[transferInPackage.contractAddr]!= transferInPackage.bep2TokenSymbol) {
        // Cross Chain sendPackage
        return;
      }
      if (block.timestamp > transferInPackage.expireTime) {
        // Cross Chain sendPackage
        return;
      }
      try IBEP2E(transferInPackage.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
        if (actualBalance < transferInPackage.amount) {
          // Cross Chain sendPackage
          return;
        }
      } catch Error(string memory reason) {
        // Cross Chain sendPackage
        emit LogUnexpectedRevertInBEP2E(transferInPackage.contractAddr, reason);
        return;
      } catch (bytes memory lowLevelData) {
        // Cross Chain sendPackage
        emit LogUnexpectedFailureAssertionInBEP2E(transferInPackage.contractAddr, lowLevelData);
        return;
      }
      try IBEP2E(transferInPackage.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transferInPackage.recipient, transferInPackage.amount) returns (bool success) {
        if (success) {
          return;
        } else {
          // Cross Chain sendPackage
        }
      } catch Error(string memory reason) {
        // Cross Chain sendPackage
        emit LogUnexpectedRevertInBEP2E(transferInPackage.contractAddr, reason);
        return;
      } catch (bytes memory lowLevelData) {
        // Cross Chain sendPackage
        emit LogUnexpectedFailureAssertionInBEP2E(transferInPackage.contractAddr, lowLevelData);
        return;
      }
      return;
    }
  }

  // | length   | refundAmount | contractAddr | refundAddr | transferOutSequence | failureReason |
  // | 32 bytes | 32 bytes     | 20 bytes     | 20 bytes   | 8 bytes             | 2 bytes     |
  function decodeRefundPackage(bytes memory value) internal pure returns(TransferOutAckPackage memory) {
    TransferOutAckPackage memory refundPackage;

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

  function handleTransferOutAckPackage(bytes memory payload) onlyInit internal {
    TransferOutAckPackage memory refundPackage = decodeRefundPackage(payload);
    if (refundPackage.contractAddr==address(0x0)) {
      uint256 actualBalance = address(this).balance;
      if (actualBalance < refundPackage.refundAmount) {
        // Cross Chain sendPackage
        return;
      }
      if (!refundPackage.refundAddr.send(refundPackage.refundAmount)){
        // Cross Chain sendPackage
        return;
      }
      return;
    } else {
      if (contractAddrToBEP2Symbol[refundPackage.contractAddr]==bytes32(0x00)) {
        // Cross Chain sendPackage
        return;
      }
      try IBEP2E(refundPackage.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
        if (actualBalance < refundPackage.refundAmount) {
          // Cross Chain sendPackage
          return;
        }
      } catch Error(string memory reason) {
        // Cross Chain sendPackage
        emit LogUnexpectedRevertInBEP2E(refundPackage.contractAddr, reason);
        return;
      } catch (bytes memory lowLevelData) {
        // Cross Chain sendPackage
        emit LogUnexpectedFailureAssertionInBEP2E(refundPackage.contractAddr, lowLevelData);
        return;
      }
      try IBEP2E(refundPackage.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(refundPackage.refundAddr, refundPackage.refundAmount) returns (bool success) {
        if (success) {
          return;
        } else {
          // Cross Chain sendPackage
        }
      } catch Error(string memory reason) {
        // Cross Chain sendPackage
        emit LogUnexpectedRevertInBEP2E(refundPackage.contractAddr, reason);
        return;
      } catch (bytes memory lowLevelData) {
        // Cross Chain sendPackage
        emit LogUnexpectedFailureAssertionInBEP2E(refundPackage.contractAddr, lowLevelData);
        return;
      }
      return;
    }
  }

  function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime) override external payable returns (bool) {
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    bytes32 bep2TokenSymbol;
    uint256 convertedAmount;
    if (contractAddr==address(0x0)) {
      require(amount%1e10==0, "invalid transfer amount: precision loss in amount conversion");
      require(msg.value==amount.add(syncRelayFee).add(ackRelayFee), "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
      convertedAmount = amount.div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
      bep2TokenSymbol=BEP2_TOKEN_SYMBOL_FOR_BNB;
    } else {
      bep2TokenSymbol = contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
      require(msg.value==syncRelayFee.add(ackRelayFee), "received BNB amount doesn't equal to relayFee");
      uint256 bep2eTokenDecimals=bep2eContractDecimals[contractAddr];
      require(bep2eTokenDecimals<=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals>BEP2_TOKEN_DECIMALS && amount.mod(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS))==0), "invalid transfer amount: precision loss in amount conversion");
      convertedAmount = convertToBep2Amount(amount, bep2eTokenDecimals);// convert to bep2 amount
      require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amount), "amount is too large, uint256 overflow");
      require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), amount));
    }
    uint256 convertedSyncRelayFee = syncRelayFee.div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    uint256 convertedAckRelayFee = ackRelayFee.div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    //emit LogTransferOut(transferOutChannelSequence++, msg.sender, recipient, convertedAmount, contractAddr, bep2TokenSymbol, expireTime, convertedRelayFee);
    // Cross Chain sendPackage
    return true;
  }

  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, address contractAddr, uint256 expireTime) override external payable returns (bool) {
    require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
    require(recipientAddrs.length == refundAddrs.length, "Length of recipientAddrs doesn't equal to length of refundAddrs");
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
      require(msg.value==totalAmount.add(syncRelayFee.mul(amounts.length)).add(ackRelayFee.mul(amounts.length)), "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
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
      require(msg.value==syncRelayFee.mul(amounts.length).add(ackRelayFee.mul(amounts.length)), "received BNB amount doesn't equal to relayFee");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), totalAmount));
    }
    uint256 convertedTotalSyncRelayFee = syncRelayFee.mul(amounts.length).div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    uint256 totalAckRelayFee = ackRelayFee.mul(amounts.length); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    // emit LogBatchTransferOut(transferOutChannelSequence, convertedAmounts, contractAddr, bep2TokenSymbol, expireTime, relayFee.div(1e10));
    // emit LogBatchTransferOutAddrs(transferOutChannelSequence++, recipientAddrs, refundAddrs);
    // Cross Chain sendPackage
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
    if (bytes32Key == bytes32(0x73796e6352656c61794665650000000000000000000000000000000000000000)){ // syncRelayFee
      uint256 newSyncRelayFee;
      assembly {
        newSyncRelayFee := mload(add(localValue, 32))
      }
      require(newSyncRelayFee >= 0 && newSyncRelayFee <= 1e18 && newSyncRelayFee%(1e10)==0, "the syncRelayFee out of range");
      syncRelayFee = newSyncRelayFee;
    } else if (bytes32Key == bytes32(0x61636b52656c6179466565000000000000000000000000000000000000000000)){ // ackRelayFee
      uint256 newAckRelayFee;
      assembly {
        newAckRelayFee := mload(add(localValue, 32))
      }
      require(newAckRelayFee >= 0 && newAckRelayFee <= 1e18, "the ackRelayFee out of range");
      ackRelayFee = newAckRelayFee;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }
}
