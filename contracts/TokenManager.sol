pragma solidity 0.6.4;

import "./interface/IBEP20.sol";
import "./interface/ITokenHub.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/IParamSubscriber.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./System.sol";

contract TokenManager is System, IApplication, IParamSubscriber {

  using SafeMath for uint256;

  using RLPEncode for *;
  using RLPDecode for *;

  using RLPDecode for RLPDecode.RLPItem;
  using RLPDecode for RLPDecode.Iterator;

  // BC to BSC
  struct BindSynPackage {
    uint8   packageType;
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 totalSupply;
    uint256 peggyAmount;
    uint8   bep20Decimals;
    uint64  expireTime;
  }

  // BSC to BC
  struct ReactBindSynPackage {
    uint32 status;
    bytes32 bep2TokenSymbol;
  }

  // BSC to BC
  struct MirrorSynPackage {
    address mirrorSender;
    address bep20Addr;
    bytes32 bep20Name;
    bytes32 bep20Symbol;
    uint256 bep20Supply;
    uint8   bep20Decimals;
    uint256 mirrorFee;
    uint64  expireTime;
  }

  // BC to BSC
  struct MirrorAckPackage {
    address mirrorSender;
    address bep20Addr;
    uint8  bep20Decimals;
    bytes32 bep2Symbol;
    uint256 mirrorFee;
    uint8   errorCode;
  }

  // BSC to BC
  struct SyncSynPackage {
    address syncSender;
    address bep20Addr;
    bytes32 bep2Symbol;
    uint256 bep20Supply;
    uint256 syncFee;
    uint64  expireTime;
  }

  // BC to BSC
  struct SyncAckPackage {
    address syncSender;
    address bep20Addr;
    uint256 syncFee;
    uint8   errorCode;
  }

  uint8 constant public   BIND_PACKAGE = 0;
  uint8 constant public   UNBIND_PACKAGE = 1;

  // bind status
  uint8 constant public   BIND_STATUS_TIMEOUT = 1;
  uint8 constant public   BIND_STATUS_SYMBOL_MISMATCH = 2;
  uint8 constant public   BIND_STATUS_TOO_MUCH_TOKENHUB_BALANCE = 3;
  uint8 constant public   BIND_STATUS_TOTAL_SUPPLY_MISMATCH = 4;
  uint8 constant public   BIND_STATUS_DECIMALS_MISMATCH = 5;
  uint8 constant public   BIND_STATUS_ALREADY_BOUND_TOKEN = 6;
  uint8 constant public   BIND_STATUS_REJECTED = 7;

  uint8 constant public MIRROR_CHANNELID = 0x04;
  uint8 constant public SYNC_CHANNELID = 0x05;
  uint8 constant public BEP2_TOKEN_DECIMALS = 8;
  uint256 constant public MAX_GAS_FOR_TRANSFER_BNB=10000;
  uint256 constant public MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
  uint256 constant public LOG_MAX_UINT256 = 77;
  // mirror status
  uint8 constant public   MIRROR_STATUS_TIMEOUT = 1;
  uint8 constant public   MIRROR_STATUS_DUPLICATED_BEP2_SYMBOL = 2;
  uint8 constant public   MIRROR_STATUS_ALREADY_BOUND = 3;
  // sync status
  uint8 constant public   SYNC_STATUS_TIMEOUT = 1;
  uint8 constant public   SYNC_STATUS_NOT_BOUND_MIRROR = 2;

  uint8 constant public   MINIMUM_BEP20_SYMBOL_LEN = 3;
  uint8 constant public   MAXIMUM_BEP20_SYMBOL_LEN = 8;

  uint256 constant public  TEN_DECIMALS = 1e10;

  mapping(bytes32 => BindSynPackage) public bindPackageRecord;

  mapping(address => bool) public mirrorPendingRecord;
  mapping(address => bool) public boundByMirror;
  uint256 public mirrorFee;
  uint256 public syncFee;

  event bindSuccess(address indexed contractAddr, string bep2Symbol, uint256 totalSupply, uint256 peggyAmount);
  event bindFailure(address indexed contractAddr, string bep2Symbol, uint32 failedReason);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);
  event paramChange(string key, bytes value);
  event mirrorSuccess(address indexed bep20Addr, bytes32 bep2Symbol);
  event mirrorFailure(address indexed bep20Addr, uint8 errCode);
  event syncSuccess(address indexed bep20Addr);
  event syncFailure(address indexed bep20Addr, uint8 errCode);

  constructor() public {}

  function handleSynPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override returns(bytes memory) {
    if (channelId == BIND_CHANNELID) {
      return handleBindSynPackage(msgBytes);
    } else {
      emit unexpectedPackage(channelId, msgBytes);
      return new bytes(0);
    }
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    if (channelId == MIRROR_CHANNELID) {
      handleMirrorAckPackage(msgBytes);
    } else if (channelId == SYNC_CHANNELID) {
      handleSyncAckPackage(msgBytes);
    } else {
      emit unexpectedPackage(channelId, msgBytes);
    }
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    if (channelId == MIRROR_CHANNELID) {
      handleMirrorFailAckPackage(msgBytes);
    } else if (channelId == SYNC_CHANNELID) {
      handleSyncFailAckPackage(msgBytes);
    } else {
      emit unexpectedPackage(channelId, msgBytes);
    }
  }

  function decodeBindSynPackage(bytes memory msgBytes) internal pure returns(BindSynPackage memory, bool) {
    BindSynPackage memory bindSynPkg;
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
        if (idx == 0)      bindSynPkg.packageType      = uint8(iter.next().toUint());
        else if (idx == 1) bindSynPkg.bep2TokenSymbol  = bytes32(iter.next().toUint());
        else if (idx == 2) bindSynPkg.contractAddr     = iter.next().toAddress();
        else if (idx == 3) bindSynPkg.totalSupply      = iter.next().toUint();
        else if (idx == 4) bindSynPkg.peggyAmount      = iter.next().toUint();
        else if (idx == 5) bindSynPkg.bep20Decimals    = uint8(iter.next().toUint());
        else if (idx == 6) {
          bindSynPkg.expireTime       = uint64(iter.next().toUint());
          success = true;
        }
        else break;
        idx++;
    }
    return (bindSynPkg, success);
  }

  function handleBindSynPackage(bytes memory msgBytes) internal returns(bytes memory) {
    (BindSynPackage memory bindSynPkg, bool success) = decodeBindSynPackage(msgBytes);
    require(success, "unrecognized transferIn package");
    if (bindSynPkg.packageType == BIND_PACKAGE) {
      bindPackageRecord[bindSynPkg.bep2TokenSymbol]=bindSynPkg;
    } else if (bindSynPkg.packageType == UNBIND_PACKAGE) {
      address contractAddr = ITokenHub(TOKEN_HUB_ADDR).getContractAddrByBEP2Symbol(bindSynPkg.bep2TokenSymbol);
      if (contractAddr!=address(0x00)) {
        ITokenHub(TOKEN_HUB_ADDR).unbindToken(bindSynPkg.bep2TokenSymbol, contractAddr);
      }
    } else {
      require(false, "unrecognized bind package");
    }
    return new bytes(0);
  }

  function encodeReactBindSynPackage(ReactBindSynPackage memory reactBindSynPackage) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](2);
    elements[0] = reactBindSynPackage.status.encodeUint();
    elements[1] = uint256(reactBindSynPackage.bep2TokenSymbol).encodeUint();
    return elements.encodeList();
  }

  function approveBind(address contractAddr, string memory bep2Symbol) payable public returns (bool) {
    require(!mirrorPendingRecord[contractAddr], "the bep20 token is in mirror pending status");
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSynPackage memory bindSynPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSynPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    uint256 lockedAmount = bindSynPkg.totalSupply.sub(bindSynPkg.peggyAmount);
    require(contractAddr==bindSynPkg.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP20(contractAddr).getOwner()==msg.sender, "only bep20 owner can approve this bind request");
    uint256 tokenHubBalance = IBEP20(contractAddr).balanceOf(TOKEN_HUB_ADDR);
    require(IBEP20(contractAddr).allowance(msg.sender, address(this)).add(tokenHubBalance)>=lockedAmount, "allowance is not enough");
    uint256 relayFee = msg.value;
    uint256 miniRelayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
    require(relayFee >= miniRelayFee && relayFee%TEN_DECIMALS == 0, "relayFee must be N * 1e10 and greater than miniRelayFee");

    uint32 verifyCode = verifyBindParameters(bindSynPkg, contractAddr);
    if (verifyCode == CODE_OK) {
      IBEP20(contractAddr).transferFrom(msg.sender, TOKEN_HUB_ADDR, lockedAmount.sub(tokenHubBalance));
      ITokenHub(TOKEN_HUB_ADDR).bindToken(bindSynPkg.bep2TokenSymbol, bindSynPkg.contractAddr, bindSynPkg.bep20Decimals);
      emit bindSuccess(contractAddr, bep2Symbol, bindSynPkg.totalSupply, lockedAmount);
    } else {
      emit bindFailure(contractAddr, bep2Symbol, verifyCode);
    }
    delete bindPackageRecord[bep2TokenSymbol];
    ReactBindSynPackage memory reactBindSynPackage = ReactBindSynPackage({
      status: verifyCode,
      bep2TokenSymbol: bep2TokenSymbol
    });
    address(uint160(TOKEN_HUB_ADDR)).transfer(relayFee);
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeReactBindSynPackage(reactBindSynPackage), relayFee.div(TEN_DECIMALS));
    return true;
  }

  function rejectBind(address contractAddr, string memory bep2Symbol) payable public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSynPackage memory bindSynPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSynPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(contractAddr==bindSynPkg.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP20(contractAddr).getOwner()==msg.sender, "only bep20 owner can reject");
    uint256 relayFee = msg.value;
    uint256 miniRelayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
    require(relayFee >= miniRelayFee && relayFee%TEN_DECIMALS == 0, "relayFee must be N * 1e10 and greater than miniRelayFee");
    delete bindPackageRecord[bep2TokenSymbol];
    ReactBindSynPackage memory reactBindSynPackage = ReactBindSynPackage({
      status: BIND_STATUS_REJECTED,
      bep2TokenSymbol: bep2TokenSymbol
    });
    address(uint160(TOKEN_HUB_ADDR)).transfer(relayFee);
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeReactBindSynPackage(reactBindSynPackage), relayFee.div(TEN_DECIMALS));
    emit bindFailure(contractAddr, bep2Symbol, BIND_STATUS_REJECTED);
    return true;
  }

  function expireBind(string memory bep2Symbol) payable public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSynPackage memory bindSynPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSynPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(bindSynPkg.expireTime<block.timestamp, "bind request is not expired");
    uint256 relayFee = msg.value;
    uint256 miniRelayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
    require(relayFee >= miniRelayFee &&relayFee%TEN_DECIMALS == 0, "relayFee must be N * 1e10 and greater than miniRelayFee");
    delete bindPackageRecord[bep2TokenSymbol];
    ReactBindSynPackage memory reactBindSynPackage = ReactBindSynPackage({
      status: BIND_STATUS_TIMEOUT,
      bep2TokenSymbol: bep2TokenSymbol
    });
    address(uint160(TOKEN_HUB_ADDR)).transfer(relayFee);
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeReactBindSynPackage(reactBindSynPackage), relayFee.div(TEN_DECIMALS));
    emit bindFailure(bindSynPkg.contractAddr, bep2Symbol, BIND_STATUS_TIMEOUT);
    return true;
  }

  function encodeMirrorSynPackage(MirrorSynPackage memory mirrorSynPackage) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](8);
    elements[0] = mirrorSynPackage.mirrorSender.encodeAddress();
    elements[1] = mirrorSynPackage.bep20Addr.encodeAddress();
    elements[2] = uint256(mirrorSynPackage.bep20Name).encodeUint();
    elements[3] = uint256(mirrorSynPackage.bep20Symbol).encodeUint();
    elements[4] = mirrorSynPackage.bep20Supply.encodeUint();
    elements[5] = uint256(mirrorSynPackage.bep20Decimals).encodeUint();
    elements[6] = mirrorSynPackage.mirrorFee.encodeUint();
    elements[7] = uint256(mirrorSynPackage.expireTime).encodeUint();
    return elements.encodeList();
  }

  function decodeMirrorSynPackage(bytes memory msgBytes) internal pure returns(MirrorSynPackage memory, bool) {
    MirrorSynPackage memory mirrorSynPackage;
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0)      mirrorSynPackage.mirrorSender  = iter.next().toAddress();
      else if (idx == 1) mirrorSynPackage.bep20Addr     = iter.next().toAddress();
      else if (idx == 2) mirrorSynPackage.bep20Name     = bytes32(iter.next().toUint());
      else if (idx == 3) mirrorSynPackage.bep20Symbol   = bytes32(iter.next().toUint());
      else if (idx == 4) mirrorSynPackage.bep20Supply   = iter.next().toUint();
      else if (idx == 5) mirrorSynPackage.bep20Decimals = uint8(iter.next().toUint());
      else if (idx == 6) mirrorSynPackage.mirrorFee     = iter.next().toUint();
      else if (idx == 7) {
        mirrorSynPackage.expireTime = uint64(iter.next().toUint());
        success = true;
      }
      else break;
      idx++;
    }
    return (mirrorSynPackage, success);
  }

  function decodeMirrorAckPackage(bytes memory msgBytes) internal pure returns(MirrorAckPackage memory, bool) {
    MirrorAckPackage memory mirrorAckPackage;
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0)      mirrorAckPackage.mirrorSender   = iter.next().toAddress();
      else if (idx == 1) mirrorAckPackage.bep20Addr      = iter.next().toAddress();
      else if (idx == 2) mirrorAckPackage.bep20Decimals  = uint8(iter.next().toUint());
      else if (idx == 3) mirrorAckPackage.bep2Symbol     = bytes32(iter.next().toUint());
      else if (idx == 4) mirrorAckPackage.mirrorFee      = iter.next().toUint();
      else if (idx == 5) {
        mirrorAckPackage.errorCode  = uint8(iter.next().toUint());
        success = true;
      }
      else break;
      idx++;
    }
    return (mirrorAckPackage, success);
  }

  function mirror(address bep20Addr, uint64 expireTime) payable public returns (bool) {
    require(ITokenHub(TOKEN_HUB_ADDR).getBep2SymbolByContractAddr(bep20Addr) == bytes32(0x00), "already bound");
    require(!mirrorPendingRecord[bep20Addr], "mirror pending");
    uint256 miniRelayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
    require(msg.value%TEN_DECIMALS == 0 && msg.value>=mirrorFee.add(miniRelayFee), "msg.value must be N * 1e10 and greater than sum of miniRelayFee and mirrorFee");
    require(expireTime>=block.timestamp + 120 && expireTime <= block.timestamp + 86400, "expireTime must be two minutes later and one day earlier");
    uint8 decimals = IBEP20(bep20Addr).decimals();
    uint256 totalSupply = IBEP20(bep20Addr).totalSupply();
    require(convertToBep2Amount(totalSupply, decimals) <= MAX_BEP2_TOTAL_SUPPLY, "too large total supply");
    string memory name = IBEP20(bep20Addr).name();
    bytes memory nameBytes = bytes(name);
    require(nameBytes.length>=1 && nameBytes.length<=32, "name length must be in [1,32]");
    string memory symbol = IBEP20(bep20Addr).symbol();
    bytes memory symbolBytes = bytes(symbol);
    require(symbolBytes.length>=MINIMUM_BEP20_SYMBOL_LEN && symbolBytes.length<=MAXIMUM_BEP20_SYMBOL_LEN, "symbol length must be in [3,8]");
    for (uint8 i = 0; i < symbolBytes.length; i++) {
      require((symbolBytes[i]>='A' && symbolBytes[i]<='Z') || (symbolBytes[i]>='a' && symbolBytes[i]<='z') || (symbolBytes[i]>='0' && symbolBytes[i]<='9'), "symbol should only contain alphabet and number");
    }
    address(uint160(TOKEN_HUB_ADDR)).transfer(msg.value.sub(mirrorFee));
    mirrorPendingRecord[bep20Addr] = true;
    bytes32 bytes32Name;
    assembly {
      bytes32Name := mload(add(name, 32))
    }
    bytes32 bytes32Symbol;
    assembly {
      bytes32Symbol := mload(add(symbol, 32))
    }
    MirrorSynPackage memory mirrorSynPackage = MirrorSynPackage({
      mirrorSender:  msg.sender,
      bep20Addr:     bep20Addr,
      bep20Name:     bytes32Name,
      bep20Symbol:   bytes32Symbol,
      bep20Supply:   totalSupply,
      bep20Decimals: decimals,
      mirrorFee:     mirrorFee.div(TEN_DECIMALS),
      expireTime:    expireTime
      });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(MIRROR_CHANNELID, encodeMirrorSynPackage(mirrorSynPackage), msg.value.sub(mirrorFee).div(TEN_DECIMALS));
    return true;
  }

  function handleMirrorAckPackage(bytes memory msgBytes) internal {
    (MirrorAckPackage memory mirrorAckPackage, bool decodeSuccess) = decodeMirrorAckPackage(msgBytes);
    require(decodeSuccess, "unrecognized package");
    mirrorPendingRecord[mirrorAckPackage.bep20Addr] = false;
    if (mirrorAckPackage.errorCode == CODE_OK ) {
      address(uint160(TOKEN_HUB_ADDR)).transfer(mirrorAckPackage.mirrorFee);
      ITokenHub(TOKEN_HUB_ADDR).bindToken(mirrorAckPackage.bep2Symbol, mirrorAckPackage.bep20Addr, mirrorAckPackage.bep20Decimals);
      boundByMirror[mirrorAckPackage.bep20Addr] = true;
      emit mirrorSuccess(mirrorAckPackage.bep20Addr, mirrorAckPackage.bep2Symbol);
      return;
    } else {
      (bool success, ) = mirrorAckPackage.mirrorSender.call{gas: MAX_GAS_FOR_TRANSFER_BNB, value: mirrorAckPackage.mirrorFee}("");
      if (!success) {
        address(uint160(SYSTEM_REWARD_ADDR)).transfer(mirrorAckPackage.mirrorFee);
      }
      emit mirrorFailure(mirrorAckPackage.bep20Addr, mirrorAckPackage.errorCode);
    }
  }

  function handleMirrorFailAckPackage(bytes memory msgBytes) internal {
    (MirrorSynPackage memory mirrorSynPackage, bool decodeSuccess) = decodeMirrorSynPackage(msgBytes);
    require(decodeSuccess, "unrecognized package");
    mirrorPendingRecord[mirrorSynPackage.bep20Addr] = false;
    (bool success, ) = mirrorSynPackage.mirrorSender.call{gas: MAX_GAS_FOR_TRANSFER_BNB, value: mirrorSynPackage.mirrorFee*TEN_DECIMALS}("");
    if (!success) {
      address(uint160(SYSTEM_REWARD_ADDR)).transfer(mirrorSynPackage.mirrorFee.mul(TEN_DECIMALS));
    }
  }

  function encodeSyncSynPackage(SyncSynPackage memory syncSynPackage) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](6);
    elements[0] = syncSynPackage.syncSender.encodeAddress();
    elements[1] = syncSynPackage.bep20Addr.encodeAddress();
    elements[2] = uint256(syncSynPackage.bep2Symbol).encodeUint();
    elements[3] = syncSynPackage.bep20Supply.encodeUint();
    elements[4] = syncSynPackage.syncFee.encodeUint();
    elements[5] = uint256(syncSynPackage.expireTime).encodeUint();
    return elements.encodeList();
  }

  function decodeSyncSynPackage(bytes memory msgBytes) internal pure returns(SyncSynPackage memory, bool) {
    SyncSynPackage memory syncSynPackage;
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0)      syncSynPackage.syncSender  = iter.next().toAddress();
      else if (idx == 1) syncSynPackage.bep20Addr   = iter.next().toAddress();
      else if (idx == 2) syncSynPackage.bep2Symbol  = bytes32(iter.next().toUint());
      else if (idx == 3) syncSynPackage.bep20Supply = iter.next().toUint();
      else if (idx == 4) syncSynPackage.syncFee     = iter.next().toUint();
      else if (idx == 5) {
        syncSynPackage.expireTime = uint64(iter.next().toUint());
        success = true;
      }
      else break;
      idx++;
    }
    return (syncSynPackage, success);
  }

  function decodeSyncAckPackage(bytes memory msgBytes) internal pure returns(SyncAckPackage memory, bool) {
    SyncAckPackage memory syncAckPackage;
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0)      syncAckPackage.syncSender   = iter.next().toAddress();
      else if (idx == 1) syncAckPackage.bep20Addr    = iter.next().toAddress();
      else if (idx == 2) syncAckPackage.syncFee      = iter.next().toUint();
      else if (idx == 3) {
        syncAckPackage.errorCode  = uint8(iter.next().toUint());
        success = true;
      }
      else break;
      idx++;
    }
    return (syncAckPackage, success);
  }

  function sync(address bep20Addr, uint64 expireTime) payable public returns (bool) {
    bytes32 bep2Symbol = ITokenHub(TOKEN_HUB_ADDR).getBep2SymbolByContractAddr(bep20Addr);
    require(bep2Symbol != bytes32(0x00), "not bound");
    require(boundByMirror[bep20Addr], "not bound by mirror");
    uint256 miniRelayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
    require(msg.value%TEN_DECIMALS == 0 && msg.value>=syncFee.add(miniRelayFee), "msg.value must be N * 1e10 and no less sum of miniRelayFee and syncFee");
    require(expireTime>=block.timestamp + 120 && expireTime <= block.timestamp + 86400, "expireTime must be two minutes later and one day earlier");
    uint256 totalSupply = IBEP20(bep20Addr).totalSupply();
    uint8 decimals = IBEP20(bep20Addr).decimals();
    require(convertToBep2Amount(totalSupply, decimals) <= MAX_BEP2_TOTAL_SUPPLY, "too large total supply");

    address(uint160(TOKEN_HUB_ADDR)).transfer(msg.value.sub(syncFee));
    SyncSynPackage memory syncSynPackage = SyncSynPackage({
      syncSender:    msg.sender,
      bep20Addr:     bep20Addr,
      bep2Symbol:    bep2Symbol,
      bep20Supply:   totalSupply,
      syncFee:       syncFee.div(TEN_DECIMALS),
      expireTime:    expireTime
      });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(SYNC_CHANNELID, encodeSyncSynPackage(syncSynPackage), msg.value.sub(syncFee).div(TEN_DECIMALS));
    return true;
  }

  function handleSyncAckPackage(bytes memory msgBytes) internal {
    (SyncAckPackage memory syncAckPackage, bool decodeSuccess) = decodeSyncAckPackage(msgBytes);
    require(decodeSuccess, "unrecognized package");
    if (syncAckPackage.errorCode == CODE_OK ) {
      address(uint160(TOKEN_HUB_ADDR)).transfer(syncAckPackage.syncFee);
      emit syncSuccess(syncAckPackage.bep20Addr);
      return;
    } else  {
      emit syncFailure(syncAckPackage.bep20Addr, syncAckPackage.errorCode);
    }
    (bool success, ) = syncAckPackage.syncSender.call{gas: MAX_GAS_FOR_TRANSFER_BNB, value: syncAckPackage.syncFee}("");
    if (!success) {
      address(uint160(SYSTEM_REWARD_ADDR)).transfer(syncAckPackage.syncFee);
    }
  }

  function handleSyncFailAckPackage(bytes memory msgBytes) internal {
    (SyncSynPackage memory syncSynPackage, bool decodeSuccess) = decodeSyncSynPackage(msgBytes);
    require(decodeSuccess, "unrecognized package");
    (bool success, ) = syncSynPackage.syncSender.call{gas: MAX_GAS_FOR_TRANSFER_BNB, value: syncSynPackage.syncFee*TEN_DECIMALS}("");
    if (!success) {
      address(uint160(SYSTEM_REWARD_ADDR)).transfer(syncSynPackage.syncFee*TEN_DECIMALS);
    }
  }

  function updateParam(string calldata key, bytes calldata value) override external onlyGov {
    require(value.length == 32, "expected value length 32");
    string memory localKey = key;
    bytes memory localValue = value;
    bytes32 bytes32Key;
    assembly {
      bytes32Key := mload(add(localKey, 32))
    }
    if (bytes32Key == bytes32(0x6d6972726f724665650000000000000000000000000000000000000000000000)) { // mirrorFee
      uint256 newMirrorFee;
      assembly {
        newMirrorFee := mload(add(localValue, 32))
      }
      require(newMirrorFee%(TEN_DECIMALS)==0, "mirrorFee must be N * 1e10");
      mirrorFee = newMirrorFee;
    } else if (bytes32Key == bytes32(0x73796e6346656500000000000000000000000000000000000000000000000000)) { // syncFee
      uint256 newSyncFee;
      assembly {
        newSyncFee := mload(add(localValue, 32))
      }
      require(newSyncFee%(TEN_DECIMALS)==0, "syncFee must be N * 1e10");
      syncFee = newSyncFee;
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

  function queryRequiredLockAmountForBind(string memory symbol) public view returns(uint256) {
    bytes32 bep2Symbol;
    assembly {
      bep2Symbol := mload(add(symbol, 32))
    }
    BindSynPackage memory bindRequest = bindPackageRecord[bep2Symbol];
    if (bindRequest.contractAddr==address(0x00)) {
      return 0;
    }
    uint256 tokenHubBalance = IBEP20(bindRequest.contractAddr).balanceOf(TOKEN_HUB_ADDR);
    uint256 requiredBalance = bindRequest.totalSupply.sub(bindRequest.peggyAmount);
    return requiredBalance.sub(tokenHubBalance);
  }

  function verifyBindParameters(BindSynPackage memory bindSynPkg, address contractAddr) internal view returns(uint32) {
    uint256 decimals = IBEP20(contractAddr).decimals();
    string memory bep20Symbol = IBEP20(contractAddr).symbol();
    uint256 tokenHubBalance = IBEP20(contractAddr).balanceOf(TOKEN_HUB_ADDR);
    uint256 lockedAmount = bindSynPkg.totalSupply.sub(bindSynPkg.peggyAmount);
    if (bindSynPkg.expireTime<block.timestamp) {
      return BIND_STATUS_TIMEOUT;
    }
    if (!checkSymbol(bep20Symbol, bindSynPkg.bep2TokenSymbol)) {
      return BIND_STATUS_SYMBOL_MISMATCH;
    }
    if (tokenHubBalance > lockedAmount) {
      return BIND_STATUS_TOO_MUCH_TOKENHUB_BALANCE;
    }
    if (IBEP20(bindSynPkg.contractAddr).totalSupply() != bindSynPkg.totalSupply) {
      return BIND_STATUS_TOTAL_SUPPLY_MISMATCH;
    }
    if (decimals!=bindSynPkg.bep20Decimals) {
      return BIND_STATUS_DECIMALS_MISMATCH;
    }
    if (ITokenHub(TOKEN_HUB_ADDR).getContractAddrByBEP2Symbol(bindSynPkg.bep2TokenSymbol)!=address(0x00)||
    ITokenHub(TOKEN_HUB_ADDR).getBep2SymbolByContractAddr(bindSynPkg.contractAddr)!=bytes32(0x00)) {
      return BIND_STATUS_ALREADY_BOUND_TOKEN;
    }
    return CODE_OK;
  }

  function checkSymbol(string memory bep20Symbol, bytes32 bep2TokenSymbol) internal pure returns(bool) {
    bytes memory bep20SymbolBytes = bytes(bep20Symbol);
    if (bep20SymbolBytes.length > MAXIMUM_BEP20_SYMBOL_LEN || bep20SymbolBytes.length < MINIMUM_BEP20_SYMBOL_LEN) {
      return false;
    }

    bytes memory bep2TokenSymbolBytes = new bytes(32);
    assembly {
      mstore(add(bep2TokenSymbolBytes, 32), bep2TokenSymbol)
    }
    if (bep2TokenSymbolBytes[bep20SymbolBytes.length] != 0x2d) { // '-'
      return false;
    }
    bool symbolMatch = true;
    for (uint256 index=0; index < bep20SymbolBytes.length; index++) {
      if (bep20SymbolBytes[index] != bep2TokenSymbolBytes[index]) {
        symbolMatch = false;
        break;
      }
    }
    return symbolMatch;
  }

  function convertToBep2Amount(uint256 amount, uint256 bep20TokenDecimals) internal pure returns (uint256) {
    if (bep20TokenDecimals > BEP2_TOKEN_DECIMALS) {
      require(bep20TokenDecimals-BEP2_TOKEN_DECIMALS <= LOG_MAX_UINT256, "too large decimals");
      return amount.div(10**(bep20TokenDecimals-BEP2_TOKEN_DECIMALS));
    }
    return amount.mul(10**(BEP2_TOKEN_DECIMALS-bep20TokenDecimals));
  }
}
