pragma solidity 0.6.4;

import "./interface/IBEP2E.sol";
import "./interface/ITokenHub.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./lib/SafeMath.sol";
import "./rlp/RLPEncode.sol";
import "./rlp/RLPDecode.sol";
import "./System.sol";

contract TokenHub is ITokenHub, System, IParamSubscriber, IApplication {

  using SafeMath for uint256;

  using RLPEncode for *;
  using RLPDecode for *;

  using RLPDecode for RLPDecode.RLPItem;
  using RLPDecode for RLPDecode.Iterator;

  // BC to BSC
  struct BindSyncPackage {
    uint8   packageType;
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 totalSupply;
    uint256 peggyAmount;
    uint8   bep2eDecimals;
    uint64  expireTime;
  }

  // BSC to BC
  struct BindAckPackage {
    bytes32 bep2TokenSymbol;
  }

  // BSC to BC
  struct ApproveBindSyncPackage {
    uint32 status;
    bytes32 bep2TokenSymbol;
  }

  // BSC to BC
  struct TransferOutSyncPackage {
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
    address payable[] refundAddrs;
    uint32 status;
  }

  // BC to BSC
  struct TransferInSyncPackage {
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 amount;
    address payable recipient;
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

  uint8 constant public   BIND_PACKAGE = 0x00;
  uint8 constant public   UNBIND_PACKAGE = 0x01;

  uint8 constant public   BIND_STATUS_SUCCESS = 0x00;
  uint8 constant public   BIND_STATUS_TIMEOUT = 0x01;
  uint8 constant public   BIND_STATUS_INCORRECT_PARAMETERS = 0x02;
  uint8 constant public   BIND_STATUS_REJECTED = 0x03;

  uint8 constant public   TRANSFER_IN_SUCCESS = 0x00;
  uint8 constant public   TRANSFER_IN_FAILURE_TIMEOUT = 0x01;
  uint8 constant public   TRANSFER_IN_FAILURE_UNBOUND_TOKEN = 0x02;
  uint8 constant public   TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE = 0x03;
  uint8 constant public   TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT = 0x04;
  uint8 constant public   TRANSFER_IN_FAILURE_UNKNOWN = 0x05;

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

  event unrecognizedPackage(bytes msgBytes);
  event refundFailure(address bep2eAddr, address refundAddr, uint256 amount);
  event refundSuccess(address bep2eAddr, address refundAddr, uint256 amount);
  event transferOutSuccess();

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

  function handleSyncPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override returns(bytes memory responsePayload){
    if (channelId == BIND_CHANNELID) {
      return handleBindSyncPackage(msgBytes);
    } else if (channelId == TRANSFER_IN_CHANNELID) {
      return handleTransferInSyncPackage(msgBytes);
    }
    return new bytes(0);
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyInit onlyCrossChainContract external override {
    if (channelId == BIND_CHANNELID) {
      handleApproveBindAckPackage(msgBytes);
    } else if (channelId == TRANSFER_OUT_CHANNELID) {
      handleTransferOutAckPackage(msgBytes);
    }
  }

  function handleFailAckPackage(uint8 /* channelId */, bytes calldata /* msgBytes */) onlyInit onlyCrossChainContract external override {
    return;
  }

  function decodeBindSyncPackage(bytes memory msgBytes) internal pure returns(BindSyncPackage memory, bool) {
    BindSyncPackage memory bindSyncPkg;
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while(iter.hasNext()) {
        if ( idx == 0 )      bindSyncPkg.packageType      = uint8(iter.next().toUint());
        else if ( idx == 1 ) bindSyncPkg.bep2TokenSymbol  = bytes32(iter.next().toUint());
        else if ( idx == 2 ) bindSyncPkg.contractAddr     = iter.next().toAddress();
        else if ( idx == 3 ) bindSyncPkg.totalSupply      = iter.next().toUint();
        else if ( idx == 4 ) bindSyncPkg.peggyAmount      = iter.next().toUint();
        else if ( idx == 5 ) bindSyncPkg.bep2eDecimals    = uint8(iter.next().toUint());
        else if ( idx == 6 ) {
          bindSyncPkg.expireTime       = uint64(iter.next().toUint());
          success = true;
        }
        else break;
        idx++;
    }
    return (bindSyncPkg, success);
  }

  function encodeBindAckPackage(BindAckPackage memory bindAckPackage) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](1);
    elements[0] = uint256(bindAckPackage.bep2TokenSymbol).encodeUint();
    return elements.encodeList();
  }

  function handleBindSyncPackage(bytes memory msgBytes) onlyInit internal returns(bytes memory) {
    (BindSyncPackage memory bindSyncPkg, bool success) = decodeBindSyncPackage(msgBytes);
    if (!success) {
      emit unrecognizedPackage(msgBytes);
      return msgBytes;
    }
    bindPackageRecord[bindSyncPkg.bep2TokenSymbol]=bindSyncPkg;
    BindAckPackage memory bindAckPackage = BindAckPackage({
      bep2TokenSymbol: bindSyncPkg.bep2TokenSymbol
    });
    return encodeBindAckPackage(bindAckPackage);
  }

  function handleApproveBindAckPackage(bytes memory msgBytes) onlyInit internal {
    // nothing to do
  }

  function encodeApproveBindSyncPackage(ApproveBindSyncPackage memory approveBindSyncPackage) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](2);
    elements[0] = approveBindSyncPackage.status.encodeUint();
    elements[1] = uint256(approveBindSyncPackage.bep2TokenSymbol).encodeUint();
    return elements.encodeList();
  }

  function approveBind(address contractAddr, string memory bep2Symbol) payable public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindSyncPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSyncPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    uint256 lockedAmount = bindSyncPkg.totalSupply.sub(bindSyncPkg.peggyAmount);
    require(contractAddr==bindSyncPkg.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can approve this bind request");
    require(IBEP2E(contractAddr).allowance(msg.sender, address(this))==lockedAmount, "allowance doesn't equal to (totalSupply - peggyAmount)");
    require(msg.value == syncRelayFee.add(ackRelayFee), "msg.value doesn't equal to syncRelayFee + ackRelayFee");

    if (bindSyncPkg.expireTime<block.timestamp) {
      delete bindPackageRecord[bep2TokenSymbol];
      ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
        status: BIND_STATUS_TIMEOUT,
        bep2TokenSymbol: bep2TokenSymbol
      });
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), syncRelayFee, ackRelayFee);
      return false;
    }

    uint256 decimals = IBEP2E(contractAddr).decimals();
    string memory bep2eSymbol = IBEP2E(contractAddr).symbol();
    if (!checkSymbol(bep2eSymbol, bep2TokenSymbol) ||
      bep2SymbolToContractAddr[bindSyncPkg.bep2TokenSymbol]!=address(0x00)||
      contractAddrToBEP2Symbol[bindSyncPkg.contractAddr]!=bytes32(0x00)||
      IBEP2E(bindSyncPkg.contractAddr).totalSupply()!=bindSyncPkg.totalSupply||
      decimals!=bindSyncPkg.bep2eDecimals) {
      delete bindPackageRecord[bep2TokenSymbol];
      ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
        status: BIND_STATUS_INCORRECT_PARAMETERS,
        bep2TokenSymbol: bep2TokenSymbol
      });
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), syncRelayFee, ackRelayFee);
      return false;
    }
    IBEP2E(contractAddr).transferFrom(msg.sender, address(this), lockedAmount);
    contractAddrToBEP2Symbol[bindSyncPkg.contractAddr] = bindSyncPkg.bep2TokenSymbol;
    bep2eContractDecimals[bindSyncPkg.contractAddr] = bindSyncPkg.bep2eDecimals;
    bep2SymbolToContractAddr[bindSyncPkg.bep2TokenSymbol] = bindSyncPkg.contractAddr;

    delete bindPackageRecord[bep2TokenSymbol];
    ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
      status: BIND_STATUS_SUCCESS,
      bep2TokenSymbol: bep2TokenSymbol
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), syncRelayFee, ackRelayFee);
    return true;
  }

  function rejectBind(address contractAddr, string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindSyncPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSyncPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(contractAddr==bindSyncPkg.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can reject");
    delete bindPackageRecord[bep2TokenSymbol];
    ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
      status: BIND_STATUS_REJECTED,
      bep2TokenSymbol: bep2TokenSymbol
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), syncRelayFee, ackRelayFee);
    return true;
  }

  function expireBind(string memory bep2Symbol) public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindSyncPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSyncPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(bindSyncPkg.expireTime<block.timestamp, "bind request is not expired");
    delete bindPackageRecord[bep2TokenSymbol];
    ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
      status: BIND_STATUS_TIMEOUT,
      bep2TokenSymbol: bep2TokenSymbol
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), syncRelayFee, ackRelayFee);
    return true;
  }

  function decodeTransferInSyncPackage(bytes memory msgBytes) internal pure returns (TransferInSyncPackage memory, bool) {
    TransferInSyncPackage memory transInSyncPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while(iter.hasNext()) {
      if ( idx == 0 ) transInSyncPkg.bep2TokenSymbol       = bytes32(iter.next().toUint());
      else if ( idx == 1 ) transInSyncPkg.contractAddr     = iter.next().toAddress();
      else if ( idx == 2 ) transInSyncPkg.amount           = iter.next().toUint();
      else if ( idx == 3 ) transInSyncPkg.recipient        = address(uint160((iter.next().toAddress())));
      else if ( idx == 4 ) transInSyncPkg.refundAddr       = iter.next().toAddress();
      else if ( idx == 5 ) {
        transInSyncPkg.expireTime       = uint64(iter.next().toUint());
        success = true;
      }
      else break;
      idx++;
    }
    return (transInSyncPkg, success);
  }

  function encodeTransferInRefundPackage(TransferInRefundPackage memory transInAckPkg) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](4);
    elements[0] = uint256(transInAckPkg.bep2TokenSymbol).encodeUint();
    elements[1] = transInAckPkg.refundAmount.encodeUint();
    elements[2] = transInAckPkg.refundAddr.encodeAddress();
    elements[3] = uint256(transInAckPkg.status).encodeUint();
    return elements.encodeList();
  }

  function handleTransferInSyncPackage(bytes memory msgBytes) internal returns(bytes memory) {
    (TransferInSyncPackage memory transInSyncPkg, bool success) = decodeTransferInSyncPackage(msgBytes);
    if (!success) {
      emit unrecognizedPackage(msgBytes);
      return msgBytes;
    }
    uint32 status = doTransferIn(transInSyncPkg);
    if (status != TRANSFER_IN_SUCCESS) {
      uint256 bep2Amount = convertToBep2Amount(transInSyncPkg.amount, bep2eContractDecimals[transInSyncPkg.contractAddr]);
      TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage({
          bep2TokenSymbol: contractAddrToBEP2Symbol[transInSyncPkg.contractAddr],
          refundAmount: bep2Amount,
          refundAddr: transInSyncPkg.refundAddr,
          status: status
      });
      return encodeTransferInRefundPackage(transInAckPkg);
    } else {
      return new bytes(0);
    }
  }

  function doTransferIn(TransferInSyncPackage memory transInSyncPkg) internal returns (uint32) {
    if (transInSyncPkg.contractAddr==address(0x0)) {
      if (block.timestamp > transInSyncPkg.expireTime) {
        return TRANSFER_IN_FAILURE_TIMEOUT;
      }
      if (address(this).balance < transInSyncPkg.amount) {
        return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
      }
      if (!transInSyncPkg.recipient.send(transInSyncPkg.amount)) {
        return TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT;
      }
      return TRANSFER_IN_SUCCESS;
    } else {
      if (block.timestamp > transInSyncPkg.expireTime) {
        return TRANSFER_IN_FAILURE_TIMEOUT;
      }
      try IBEP2E(transInSyncPkg.contractAddr).balanceOf{gas: MAX_GAS_FOR_CALLING_BEP2E}(address(this)) returns (uint256 actualBalance) {
        if (actualBalance < transInSyncPkg.amount) {
          return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
        }
      } catch Error(string memory reason) {
        emit LogUnexpectedRevertInBEP2E(transInSyncPkg.contractAddr, reason);
        return TRANSFER_IN_FAILURE_UNKNOWN;
      } catch (bytes memory lowLevelData) {
        emit LogUnexpectedFailureAssertionInBEP2E(transInSyncPkg.contractAddr, lowLevelData);
        return TRANSFER_IN_FAILURE_UNKNOWN;
      }
      try IBEP2E(transInSyncPkg.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transInSyncPkg.recipient, transInSyncPkg.amount) returns (bool success) {
        if (success){
          return TRANSFER_IN_SUCCESS;
        } else {
          return TRANSFER_IN_FAILURE_UNKNOWN;
        }
      } catch Error(string memory reason) {
        emit LogUnexpectedRevertInBEP2E(transInSyncPkg.contractAddr, reason);
        return TRANSFER_IN_FAILURE_UNKNOWN;
      } catch (bytes memory lowLevelData) {
        emit LogUnexpectedFailureAssertionInBEP2E(transInSyncPkg.contractAddr, lowLevelData);
        return TRANSFER_IN_FAILURE_UNKNOWN;
      }
    }
  }

  function decodeTransferOutAckPackage(bytes memory msgBytes) internal pure returns(TransferOutAckPackage memory, bool) {
    TransferOutAckPackage memory transOutAckPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while(iter.hasNext()) {
        if ( idx == 0 ) {
          transOutAckPkg.contractAddr = iter.next().toAddress();
        }
        else if ( idx == 1 ) {
          RLPDecode.RLPItem[] memory list = iter.next().toList();
          transOutAckPkg.refundAmounts = new uint256[](list.length);
          for(uint256 index=0; index<list.length; index++ ) {
            transOutAckPkg.refundAmounts[index] = list[index].toUint();
          }
        }
        else if ( idx == 2 ) {
          RLPDecode.RLPItem[] memory list = iter.next().toList();
          transOutAckPkg.refundAddrs = new address payable[](list.length);
          for(uint256 index=0; index<list.length; index++ ) {
            transOutAckPkg.refundAddrs[index] = address(uint160(list[index].toAddress()));
          }
        }
        else if ( idx == 3 ) {
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
    if (msgBytes.length == 0) {
      return;
    }
    (TransferOutAckPackage memory transOutAckPkg, bool decodeSuccess) = decodeTransferOutAckPackage(msgBytes);
    if (!decodeSuccess) {
      emit unrecognizedPackage(msgBytes);
      return;
    }
    if (transOutAckPkg.contractAddr==address(0x0)) {
      for (uint256 index = 0; index<transOutAckPkg.refundAmounts.length; index++ ) {
        if (!transOutAckPkg.refundAddrs[index].send(transOutAckPkg.refundAmounts[index])){
          emit refundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
          continue;
        } else {
          emit refundSuccess(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
        }
      }
    } else {
      for (uint256 index = 0; index<transOutAckPkg.refundAmounts.length; index++) {
        try IBEP2E(transOutAckPkg.contractAddr).transfer{gas: MAX_GAS_FOR_CALLING_BEP2E}(transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]) returns (bool success) {
          if (success) {
            emit refundSuccess(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
            continue;
          } else {
            emit refundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
            continue;
          }
        } catch Error(string memory reason) {
          emit refundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
          emit LogUnexpectedRevertInBEP2E(transOutAckPkg.contractAddr, reason);
          continue;
        } catch (bytes memory lowLevelData) {
          emit refundFailure(transOutAckPkg.contractAddr, transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]);
          emit LogUnexpectedFailureAssertionInBEP2E(transOutAckPkg.contractAddr, lowLevelData);
          continue;
        }
      }
    }
  }

  function encodeTransferOutSyncPackage(TransferOutSyncPackage memory transOutSyncPkg) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](6);

    elements[0] = uint256(transOutSyncPkg.bep2TokenSymbol).encodeUint();
    elements[1] = transOutSyncPkg.contractAddr.encodeAddress();

    uint256 batchLength = transOutSyncPkg.amounts.length;

    bytes[] memory amountsElements = new bytes[](batchLength);
    for(uint256 index; index< batchLength; index++) {
      amountsElements[index] = transOutSyncPkg.amounts[index].encodeUint();
    }
    elements[2] = amountsElements.encodeList();

    bytes[] memory recipientsElements = new bytes[](batchLength);
    for(uint256 index; index< batchLength; index++) {
       recipientsElements[index] = transOutSyncPkg.recipients[index].encodeAddress();
    }
    elements[3] = recipientsElements.encodeList();

    bytes[] memory refundAddrsElements = new bytes[](batchLength);
    for(uint256 index; index< batchLength; index++) {
       refundAddrsElements[index] = transOutSyncPkg.refundAddrs[index].encodeAddress();
    }
    elements[4] = refundAddrsElements.encodeList();

    elements[5] = uint256(transOutSyncPkg.expireTime).encodeUint();
    return elements.encodeList();
  }

  function transferOut(address contractAddr, address recipient, uint256 amount, uint64 expireTime) override external payable returns (bool) {
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
      if (isMiniBEP2Token(bep2TokenSymbol)) {
        uint256 balance = IBEP2E(contractAddr).balanceOf(msg.sender);
        require(convertedAmount > 1e8 || balance == amount, "For miniToken, the transfer amount must be either large than 1 or equal to its balance");
      }
      require(bep2eTokenDecimals>=BEP2_TOKEN_DECIMALS || (bep2eTokenDecimals<BEP2_TOKEN_DECIMALS && convertedAmount>amount), "amount is too large, uint256 overflow");
      require(convertedAmount<=MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
      require(IBEP2E(contractAddr).transferFrom(msg.sender, address(this), amount));
    }
    TransferOutSyncPackage memory transOutSyncPkg = TransferOutSyncPackage({
      bep2TokenSymbol: bep2TokenSymbol,
      contractAddr: contractAddr,
      amounts: new uint256[](1),
      recipients: new address[](1),
      refundAddrs: new address[](1),
      expireTime: expireTime
    });
    transOutSyncPkg.amounts[0]=amount;
    transOutSyncPkg.recipients[0]=recipient;
    transOutSyncPkg.refundAddrs[0]=msg.sender;
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(TRANSFER_OUT_CHANNELID, encodeTransferOutSyncPackage(transOutSyncPkg), syncRelayFee.div(1e10), ackRelayFee);
    return true;
  }

  // TODO delete parameter contractAddr
  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, address contractAddr, uint64 expireTime) override external payable returns (bool) {
    require(contractAddr==address(0x0), "batchTransferOut only supports BNB");
    require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
    require(recipientAddrs.length == refundAddrs.length, "Length of recipientAddrs doesn't equal to length of refundAddrs");
    require(expireTime>=block.timestamp + 120, "expireTime must be two minutes later");
    uint256 batchLength = amounts.length;
    uint256 totalAmount = 0;
    for (uint i = 0; i < batchLength; i++) {
      totalAmount = totalAmount.add(amounts[i]);
    }
    uint256[] memory convertedAmounts = new uint256[](batchLength);

    for (uint8 i = 0; i < batchLength; i++) {
      require(amounts[i]%1e10==0, "invalid transfer amount");
      convertedAmounts[i] = amounts[i].div(1e10);
    }
    require(msg.value==totalAmount.add(syncRelayFee.mul(batchLength)).add(ackRelayFee.mul(batchLength)), "received BNB amount doesn't equal to the sum of transfer amount and relayFee");

    address[] memory recipientAddrsLocal = recipientAddrs; // fix error:  Stack too deep, try removing local variables.
    uint256[] memory amountsLocal = amounts; // fix error:  Stack too deep, try removing local variables.
    address[] memory refundAddrsLocal = refundAddrs; // fix error:  Stack too deep, try removing local variables.
    TransferOutSyncPackage memory transOutSyncPkg = TransferOutSyncPackage({
      bep2TokenSymbol: BEP2_TOKEN_SYMBOL_FOR_BNB,
      contractAddr: contractAddr,
      amounts: amountsLocal,
      recipients: recipientAddrsLocal,
      refundAddrs: refundAddrsLocal,
      expireTime: expireTime
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(TRANSFER_OUT_CHANNELID, encodeTransferOutSyncPackage(transOutSyncPkg), syncRelayFee.mul(batchLength).div(1e10), ackRelayFee.mul(batchLength));
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

  function bep2TokenSymbolConvert(string memory symbol) internal pure returns(bytes32) {
    bytes32 result;
    assembly {
      result := mload(add(symbol, 32))
    }
    return result;
  }

  function isMiniBEP2Token(bytes32 symbol) internal pure returns(bool) {
     bytes memory symbolBytes = new bytes(32);
     assembly {
       mstore(add(symbolBytes, 32), symbol)
     }
     uint256 symbolLength = symbolBytes.length;
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

  function checkSymbol(string memory bep2eSymbol, bytes32 bep2TokenSymbol) internal pure returns(bool) {
    bytes memory bep2eSymbolBytes = bytes(bep2eSymbol);
    if (bep2eSymbolBytes.length > MAXIMUM_BEP2E_SYMBOL_LEN || bep2eSymbolBytes.length < MINIMUM_BEP2E_SYMBOL_LEN) {
      return false;
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
}
