pragma solidity 0.6.4;

import "./interface/IBEP2E.sol";
import "./interface/ITokenHub.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/ISystemReward.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./System.sol";

contract TokenHub is ITokenHub, System, IParamSubscriber, IApplication, ISystemReward {

  using SafeMath for uint256;

  using RLPEncode for *;
  using RLPDecode for *;

  using RLPDecode for RLPDecode.RLPItem;
  using RLPDecode for RLPDecode.Iterator;

  // BSC to BC
  struct TransferOutSynPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256[] amounts;
    address[] recipients;
    address[] refundAddrs;
    uint64  expireTime;
  }

  // BC to BSC
  struct TransferOutAckPackage {
    address contractAddr;
    uint256[] refundAmounts;
    address[] refundAddrs;
    uint32 status;
  }

  // BC to BSC
  struct TransferInSynPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 amount;
    address recipient;
    address refundAddr;
    uint64  expireTime;
  }

  // BSC to BC
  struct TransferInRefundPackage {
    bytes32 bep2TokenSymbol;
    uint256 refundAmount;
    address refundAddr;
    uint32 status;
  }

  // transfer in channel
  uint8 constant public   TRANSFER_IN_SUCCESS = 0;
  uint8 constant public   TRANSFER_IN_FAILURE_TIMEOUT = 1;
  uint8 constant public   TRANSFER_IN_FAILURE_UNBOUND_TOKEN = 2;
  uint8 constant public   TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE = 3;
  uint8 constant public   TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT = 4;
  uint8 constant public   TRANSFER_IN_FAILURE_UNKNOWN = 5;

  uint256 constant public MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
  uint8 constant public   MINIMUM_BEP2E_SYMBOL_LEN = 3;
  uint8 constant public   MAXIMUM_BEP2E_SYMBOL_LEN = 8;
  uint8 constant public   BEP2_TOKEN_DECIMALS = 8;
  bytes32 constant public BEP2_TOKEN_SYMBOL_FOR_BNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
  uint256 constant public MAX_GAS_FOR_CALLING_BEP2E=50000;

  uint256 constant public INIT_MINIMUM_RELAY_FEE =1e16;

  uint256 public relayFee;

  mapping(address => uint256) public bep2eContractDecimals;
  mapping(address => bytes32) private contractAddrToBEP2Symbol;
  mapping(bytes32 => address) private bep2SymbolToContractAddr;

  event transferInSuccess(address bep2eAddr, address refundAddr, uint256 amount);
  event transferOutSuccess(address bep2eAddr, address senderAddr, uint256 amount, uint256 relayFee);
  event refundSuccess(address bep2eAddr, address refundAddr, uint256 amount, uint32 status);
  event refundFailure(address bep2eAddr, address refundAddr, uint256 amount, uint32 status);
  event rewardTo(address to, uint256 amount);
  event receiveDeposit(address from, uint256 amount);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);
  event paramChange(string key, bytes value);

  constructor() public {}

  function init() onlyNotInit external {
    relayFee = INIT_MINIMUM_RELAY_FEE;
    bep2eContractDecimals[address(0x0)] = 18; // BNB decimals is 18
    alreadyInit=true;
  }

  receive() external payable{
    if (msg.value>0) {
      emit receiveDeposit(msg.sender, msg.value);
    }
  }

  function claimRewards(address payable to, uint256 amount) onlyInit onlyRelayerIncentivize external override returns(uint256) {
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if (actualAmount>0) {
      to.transfer(actualAmount);
      emit rewardTo(to, actualAmount);
    }
    return actualAmount;
  }

  function getMiniRelayFee() external view override returns(uint256) {
    return relayFee;
  }

  function handleSynPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override returns(bytes memory) {
    if (channelId == TRANSFER_IN_CHANNELID) {
      return handleTransferInSynPackage(msgBytes);
    } else {
      // should not happen
      require(false, "unrecognized syn package");
      return new bytes(0);
    }
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override {
    if (channelId == TRANSFER_OUT_CHANNELID) {
      handleTransferOutAckPackage(msgBytes);
    } else {
      emit unexpectedPackage(channelId, msgBytes);
    }
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override {
    if (channelId == TRANSFER_OUT_CHANNELID) {
      handleTransferOutFailAckPackage(msgBytes);
    } else {
      emit unexpectedPackage(channelId, msgBytes);
    }
  }

  function decodeTransferInSynPackage(bytes memory msgBytes) internal pure returns (TransferInSynPackage memory, bool) {
    TransferInSynPackage memory transInSynPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0) transInSynPkg.bep2TokenSymbol       = bytes32(iter.next().toUint());
      else if (idx == 1) transInSynPkg.contractAddr     = iter.next().toAddress();
      else if (idx == 2) transInSynPkg.amount           = iter.next().toUint();
      else if (idx == 3) transInSynPkg.recipient        = ((iter.next().toAddress()));
      else if (idx == 4) transInSynPkg.refundAddr       = iter.next().toAddress();
      else if (idx == 5) {
        transInSynPkg.expireTime       = uint64(iter.next().toUint());
        success = true;
      }
      else break;
      idx++;
    }
    return (transInSynPkg, success);
  }

  function encodeTransferInRefundPackage(TransferInRefundPackage memory transInAckPkg) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](4);
    elements[0] = uint256(transInAckPkg.bep2TokenSymbol).encodeUint();
    elements[1] = transInAckPkg.refundAmount.encodeUint();
    elements[2] = transInAckPkg.refundAddr.encodeAddress();
    elements[3] = uint256(transInAckPkg.status).encodeUint();
    return elements.encodeList();
  }

  function handleTransferInSynPackage(bytes memory msgBytes) internal returns(bytes memory) {
    (TransferInSynPackage memory transInSynPkg, bool success) = decodeTransferInSynPackage(msgBytes);
    require(success, "unrecognized transferIn package");
    uint32 resCode = doTransferIn(transInSynPkg);
    if (resCode != TRANSFER_IN_SUCCESS) {
      uint256 bep2Amount = convertToBep2Amount(transInSynPkg.amount, bep2eContractDecimals[transInSynPkg.contractAddr]);
      TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage({
          bep2TokenSymbol: transInSynPkg.bep2TokenSymbol,
          refundAmount: bep2Amount,
          refundAddr: transInSynPkg.refundAddr,
          status: resCode
      });
      return encodeTransferInRefundPackage(transInAckPkg);
    } else {
      return new bytes(0);
    }
  }

  function doTransferIn(TransferInSynPackage memory transInSynPkg) internal returns (uint32) {
    if (transInSynPkg.contractAddr==address(0x0)) {
      if (block.timestamp > transInSynPkg.expireTime) {
        return TRANSFER_IN_FAILURE_TIMEOUT;
      }
      if (address(this).balance < transInSynPkg.amount) {
        return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
      }
      if (!address(uint160(transInSynPkg.recipient)).send(transInSynPkg.amount)) {
        return TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT;
      }
      emit transferInSuccess(transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount);
      return TRANSFER_IN_SUCCESS;
    } else {
      if (block.timestamp > transInSynPkg.expireTime) {
        return TRANSFER_IN_FAILURE_TIMEOUT;
      }
      if (contractAddrToBEP2Symbol[transInSynPkg.contractAddr]!= transInSynPkg.bep2TokenSymbol) {
        return TRANSFER_IN_FAILURE_UNBOUND_TOKEN;
      }
      uint256 actualBalance = IBEP2E(transInSynPkg.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this));
      if (actualBalance < transInSynPkg.amount) {
        return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
      }
      bool success = IBEP2E(transInSynPkg.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transInSynPkg.recipient, transInSynPkg.amount);
      if (success) {
        emit transferInSuccess(transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount);
        return TRANSFER_IN_SUCCESS;
      } else {
        return TRANSFER_IN_FAILURE_UNKNOWN;
      }
    }
  }

  function decodeTransferOutAckPackage(bytes memory msgBytes) internal pure returns(TransferOutAckPackage memory, bool) {
    TransferOutAckPackage memory transOutAckPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
        if (idx == 0) {
          transOutAckPkg.contractAddr = iter.next().toAddress();
        }
        else if (idx == 1) {
          RLPDecode.RLPItem[] memory list = iter.next().toList();
          transOutAckPkg.refundAmounts = new uint256[](list.length);
          for (uint256 index=0; index<list.length; index++) {
            transOutAckPkg.refundAmounts[index] = list[index].toUint();
          }
        }
        else if (idx == 2) {
          RLPDecode.RLPItem[] memory list = iter.next().toList();
          transOutAckPkg.refundAddrs = new address[](list.length);
          for (uint256 index=0; index<list.length; index++) {
            transOutAckPkg.refundAddrs[index] = list[index].toAddress();
          }
        }
        else if (idx == 3) {
          transOutAckPkg.status = uint32(iter.next().toUint());
          success = true;
        }
        else {
          break;
        }
        idx++;
    }
    return (transOutAckPkg, success);
  }

  function handleTransferOutAckPackage(bytes memory msgBytes) internal {
    (TransferOutAckPackage memory transOutAckPkg, bool decodeSuccess) = decodeTransferOutAckPackage(msgBytes);
    require(decodeSuccess, "unrecognized transferOut ack package");
    doRefund(transOutAckPkg);
  }

  function doRefund(TransferOutAckPackage memory transOutAckPkg) internal {
    if (transOutAckPkg.contractAddr==address(0x0)) {
      for (uint256 index = 0; index<transOutAckPkg.refundAmounts.length; index++) {
        if (!address(uint160(transOutAckPkg.refundAddrs[index])).send(transOutAckPkg.refundAmounts[index])) {
          emit refundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
        } else {
          emit refundSuccess(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
        }
      }
    } else {
      for (uint256 index = 0; index<transOutAckPkg.refundAmounts.length; index++) {
        bool success = IBEP2E(transOutAckPkg.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
        if (success) {
          emit refundSuccess(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
        } else {
          emit refundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index], transOutAckPkg.status);
        }
      }
    }
  }

  function decodeTransferOutSynPackage(bytes memory msgBytes) internal pure returns (TransferOutSynPackage memory, bool) {
    TransferOutSynPackage memory transOutSynPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0) {
        transOutSynPkg.bep2TokenSymbol = bytes32(iter.next().toUint());
      } else if (idx == 1) {
        transOutSynPkg.contractAddr = iter.next().toAddress();
      } else if (idx == 2) {
        RLPDecode.RLPItem[] memory list = iter.next().toList();
        transOutSynPkg.amounts = new uint256[](list.length);
        for (uint256 index=0; index<list.length; index++) {
          transOutSynPkg.amounts[index] = list[index].toUint();
        }
      } else if (idx == 3) {
        RLPDecode.RLPItem[] memory list = iter.next().toList();
        transOutSynPkg.recipients = new address[](list.length);
        for (uint256 index=0; index<list.length; index++) {
          transOutSynPkg.recipients[index] = list[index].toAddress();
        }
      } else if (idx == 4) {
        RLPDecode.RLPItem[] memory list = iter.next().toList();
        transOutSynPkg.refundAddrs = new address[](list.length);
        for (uint256 index=0; index<list.length; index++) {
          transOutSynPkg.refundAddrs[index] = list[index].toAddress();
        }
      } else if (idx == 5) {
        transOutSynPkg.expireTime = uint64(iter.next().toUint());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    return (transOutSynPkg, true);
  }

  function handleTransferOutFailAckPackage(bytes memory msgBytes) internal {
    (TransferOutSynPackage memory transOutSynPkg, bool decodeSuccess) = decodeTransferOutSynPackage(msgBytes);
    require(decodeSuccess, "unrecognized transferOut syn package");
    TransferOutAckPackage memory transOutAckPkg;
    transOutAckPkg.contractAddr = transOutSynPkg.contractAddr;
    transOutAckPkg.refundAmounts = transOutSynPkg.amounts;
    uint256 bep2eTokenDecimals = bep2eContractDecimals[transOutSynPkg.contractAddr];
    for (uint idx=0;idx<transOutSynPkg.amounts.length;idx++) {
      transOutSynPkg.amounts[idx] = convertFromBep2Amount(transOutSynPkg.amounts[idx], bep2eTokenDecimals);
    }
    transOutAckPkg.refundAddrs = transOutSynPkg.refundAddrs;
    transOutAckPkg.status = TRANSFER_IN_FAILURE_UNKNOWN;
    doRefund(transOutAckPkg);
  }

  function encodeTransferOutSynPackage(TransferOutSynPackage memory transOutSynPkg) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](6);

    elements[0] = uint256(transOutSynPkg.bep2TokenSymbol).encodeUint();
    elements[1] = transOutSynPkg.contractAddr.encodeAddress();

    uint256 batchLength = transOutSynPkg.amounts.length;

    bytes[] memory amountsElements = new bytes[](batchLength);
    for (uint256 index; index< batchLength; index++) {
      amountsElements[index] = transOutSynPkg.amounts[index].encodeUint();
    }
    elements[2] = amountsElements.encodeList();

    bytes[] memory recipientsElements = new bytes[](batchLength);
    for (uint256 index; index< batchLength; index++) {
       recipientsElements[index] = transOutSynPkg.recipients[index].encodeAddress();
    }
    elements[3] = recipientsElements.encodeList();

    bytes[] memory refundAddrsElements = new bytes[](batchLength);
    for (uint256 index; index< batchLength; index++) {
       refundAddrsElements[index] = transOutSynPkg.refundAddrs[index].encodeAddress();
    }
    elements[4] = refundAddrsElements.encodeList();

    elements[5] = uint256(transOutSynPkg.expireTime).encodeUint();
    return elements.encodeList();
  }

  function transferOut(address contractAddr, address recipient, uint256 amount, uint64 expireTime) external override onlyInit payable returns (bool) {
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    require(msg.value%1e10==0, "invalid received BNB amount: precision loss in amount conversion");
    bytes32 bep2TokenSymbol;
    uint256 convertedAmount;
    uint256 rewardForRelayer;
    if (contractAddr==address(0x0)) {
      require(msg.value>=amount.add(relayFee), "received BNB amount should be no less than the sum of transferOut BNB amount and minimum relayFee");
      require(amount%1e10==0, "invalid transfer amount: precision loss in amount conversion");
      rewardForRelayer=msg.value.sub(amount);
      convertedAmount = amount.div(1e10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
      bep2TokenSymbol=BEP2_TOKEN_SYMBOL_FOR_BNB;
    } else {
      bep2TokenSymbol = contractAddrToBEP2Symbol[contractAddr];
      require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bound to any bep2 token");
      require(msg.value>=relayFee, "received BNB amount should be no less than the minimum relayFee");
      rewardForRelayer=msg.value;
      uint256 bep2eTokenDecimals=bep2eContractDecimals[contractAddr];
      require(bep2eTokenDecimals<=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals>BEP2_TOKEN_DECIMALS && amount.mod(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS))==0), "invalid transfer amount: precision loss in amount conversion");
      convertedAmount = convertToBep2Amount(amount, bep2eTokenDecimals);// convert to bep2 amount
      if (isMiniBEP2Token(bep2TokenSymbol)) {
        require(convertedAmount >= 1e8 , "For miniToken, the transfer amount must not be less than 1");
      }
      require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amount), "amount is too large, uint256 overflow");
      require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), amount));
    }
    TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage({
      bep2TokenSymbol: bep2TokenSymbol,
      contractAddr: contractAddr,
      amounts: new uint256[](1),
      recipients: new address[](1),
      refundAddrs: new address[](1),
      expireTime: expireTime
    });
    transOutSynPkg.amounts[0]=convertedAmount;
    transOutSynPkg.recipients[0]=recipient;
    transOutSynPkg.refundAddrs[0]=msg.sender;
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(TRANSFER_OUT_CHANNELID, encodeTransferOutSynPackage(transOutSynPkg), rewardForRelayer.div(1e10));
    emit transferOutSuccess(contractAddr, msg.sender, amount, rewardForRelayer);
    return true;
  }

  function batchTransferOutBNB(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, uint64 expireTime) external override onlyInit payable returns (bool) {
    require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
    require(recipientAddrs.length == refundAddrs.length, "Length of recipientAddrs doesn't equal to length of refundAddrs");
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    require(msg.value%1e10==0, "invalid received BNB amount: precision loss in amount conversion");
    uint256 batchLength = amounts.length;
    uint256 totalAmount = 0;
    uint256 rewardForRelayer;
    uint256[] memory convertedAmounts = new uint256[](batchLength);
    for (uint i = 0; i < batchLength; i++) {
      require(amounts[i]%1e10==0, "invalid transfer amount: precision loss in amount conversion");
      totalAmount = totalAmount.add(amounts[i]);
      convertedAmounts[i] = amounts[i].div(1e10);
    }
    require(msg.value>=totalAmount.add(relayFee.mul(batchLength)), "received BNB amount should be no less than the sum of transfer BNB amount and relayFee");
    rewardForRelayer = msg.value.sub(totalAmount);

    TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage({
      bep2TokenSymbol: BEP2_TOKEN_SYMBOL_FOR_BNB,
      contractAddr: address(0x00),
      amounts: convertedAmounts,
      recipients: recipientAddrs,
      refundAddrs: refundAddrs,
      expireTime: expireTime
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(TRANSFER_OUT_CHANNELID, encodeTransferOutSynPackage(transOutSynPkg), rewardForRelayer.div(1e10));
    emit transferOutSuccess(address(0x0), msg.sender, totalAmount, rewardForRelayer);
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
    if (bytes32Key == bytes32(0x72656c6179466565000000000000000000000000000000000000000000000000)) { // relayFee
      uint256 newRelayFee;
      assembly {
        newRelayFee := mload(add(localValue, 32))
      }
      require(newRelayFee >= 0 && newRelayFee <= 1e18 && newRelayFee%(1e10)==0, "the relayFee out of range");
      relayFee = newRelayFee;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external view override returns(address) {
    return bep2SymbolToContractAddr[bep2Symbol];
  }

  function getBep2SymbolByContractAddr(address contractAddr) external view override returns(bytes32) {
    return contractAddrToBEP2Symbol[contractAddr];
  }

  function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external override onlyTokenManager {
    bep2SymbolToContractAddr[bep2Symbol] = contractAddr;
    contractAddrToBEP2Symbol[contractAddr] = bep2Symbol;
    bep2eContractDecimals[contractAddr] = decimals;
  }

  function unbindToken(bytes32 bep2Symbol, address contractAddr) external override onlyTokenManager {
    delete bep2SymbolToContractAddr[bep2Symbol];
    delete contractAddrToBEP2Symbol[contractAddr];
  }

  function isMiniBEP2Token(bytes32 symbol) internal pure returns(bool) {
     bytes memory symbolBytes = new bytes(32);
     assembly {
       mstore(add(symbolBytes, 32), symbol)
     }
     uint8 symbolLength = 0;
     for (uint8 j = 0; j < 32; j++) {
       if (symbolBytes[j] != 0) {
         symbolLength++;
       } else {
         break;
       }
     }
     if (symbolLength < MINIMUM_BEP2E_SYMBOL_LEN + 5) {
       return false;
     }
     if (symbolBytes[symbolLength-5] != 0x2d) { // '-'
       return false;
     }
     if (symbolBytes[symbolLength-1] != 'M') { // ABC-XXXM
       return false;
     }
     return true;
  }

  function convertToBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) internal pure returns (uint256) {
    if (bep2eTokenDecimals > BEP2_TOKEN_DECIMALS) {
      return amount.div(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS));
    }
    return amount.mul(10**(BEP2_TOKEN_DECIMALS-bep2eTokenDecimals));
  }

  function convertFromBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) internal pure returns (uint256) {
    if (bep2eTokenDecimals > BEP2_TOKEN_DECIMALS) {
      return amount.mul(10**(bep2eTokenDecimals-BEP2_TOKEN_DECIMALS));
    }
    return amount.div(10**(BEP2_TOKEN_DECIMALS-bep2eTokenDecimals));
  }

  function getBoundContract(string memory bep2Symbol) public view returns (address) {
    bytes32 bep2TokenSymbol;
    assembly {
      bep2TokenSymbol := mload(add(bep2Symbol, 32))
    }
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
}
