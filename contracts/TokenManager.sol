pragma solidity 0.6.4;

import "./interface/IBEP2E.sol";
import "./interface/ITokenHub.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./System.sol";

contract TokenManager is System, IApplication {

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
  struct ApproveBindSyncPackage {
    uint32 status;
    bytes32 bep2TokenSymbol;
  }

  uint8 constant public   BIND_PACKAGE = 0;
  uint8 constant public   UNBIND_PACKAGE = 1;

  // bind status
  uint8 constant public   BIND_STATUS_SUCCESS = 0;
  uint8 constant public   BIND_STATUS_TIMEOUT = 1;
  uint8 constant public   BIND_STATUS_INCORRECT_PARAMETERS = 2;
  uint8 constant public   BIND_STATUS_REJECTED = 3;

  uint8 constant public   MINIMUM_BEP2E_SYMBOL_LEN = 3;
  uint8 constant public   MAXIMUM_BEP2E_SYMBOL_LEN = 8;

  mapping(bytes32 => BindSyncPackage) public bindPackageRecord;

  event unexpectedPackage(uint8 channelId, bytes msgBytes);

  constructor() public {}

  function handleSynPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override returns(bytes memory){
    if (channelId == BIND_CHANNELID) {
      return handleBindSyncPackage(msgBytes);
    } else {
      // should not happen
      require(false, "unrecognized sync package");
      return new bytes(0);
    }
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    emit unexpectedPackage(channelId, msgBytes);
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    emit unexpectedPackage(channelId, msgBytes);
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

  function handleBindSyncPackage(bytes memory msgBytes) internal returns(bytes memory) {
    (BindSyncPackage memory bindSyncPkg, bool success) = decodeBindSyncPackage(msgBytes);
    require(success, "unrecognized transferIn package");
    if (bindSyncPkg.packageType == BIND_PACKAGE) {
      bindPackageRecord[bindSyncPkg.bep2TokenSymbol]=bindSyncPkg;
    } else if (bindSyncPkg.packageType == UNBIND_PACKAGE) {
      address contractAddr = ITokenHub(TOKEN_HUB_ADDR).getContractAddrByBEP2Symbol(bindSyncPkg.bep2TokenSymbol);
      if (contractAddr!=address(0x00)) {
        ITokenHub(TOKEN_HUB_ADDR).unsetBindMapping(bindSyncPkg.bep2TokenSymbol, contractAddr);
      }
    } else {
      require(false, "unrecognized bind package");
    }
    return new bytes(0);
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
    uint256 relayFee = ITokenHub(TOKEN_HUB_ADDR).getRelayFee();
    require(msg.value == relayFee, "msg.value doesn't equal to relayFee");

    if (bindSyncPkg.expireTime<block.timestamp) {
      delete bindPackageRecord[bep2TokenSymbol];
      ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
        status: BIND_STATUS_TIMEOUT,
        bep2TokenSymbol: bep2TokenSymbol
      });
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), relayFee.div(1e10));
      return false;
    }

    uint256 decimals = IBEP2E(contractAddr).decimals();
    string memory bep2eSymbol = IBEP2E(contractAddr).symbol();
    if (!checkSymbol(bep2eSymbol, bep2TokenSymbol) ||
      ITokenHub(TOKEN_HUB_ADDR).getContractAddrByBEP2Symbol(bindSyncPkg.bep2TokenSymbol)!=address(0x00)||
      ITokenHub(TOKEN_HUB_ADDR).getBep2SymbolByContractAddr(bindSyncPkg.contractAddr)!=bytes32(0x00)||
      IBEP2E(bindSyncPkg.contractAddr).totalSupply()!=bindSyncPkg.totalSupply||
      decimals!=bindSyncPkg.bep2eDecimals) {
      delete bindPackageRecord[bep2TokenSymbol];
      ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
        status: BIND_STATUS_INCORRECT_PARAMETERS,
        bep2TokenSymbol: bep2TokenSymbol
      });
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), relayFee.div(1e10));
      return false;
    }
    IBEP2E(contractAddr).transferFrom(msg.sender, TOKEN_HUB_ADDR, lockedAmount);
    ITokenHub(TOKEN_HUB_ADDR).setBindMapping(bindSyncPkg.bep2TokenSymbol, bindSyncPkg.contractAddr);
    ITokenHub(TOKEN_HUB_ADDR).setContractAddrDecimals(bindSyncPkg.contractAddr, bindSyncPkg.bep2eDecimals);

    delete bindPackageRecord[bep2TokenSymbol];
    ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
      status: BIND_STATUS_SUCCESS,
      bep2TokenSymbol: bep2TokenSymbol
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), relayFee.div(1e10));
    return true;
  }

  function rejectBind(address contractAddr, string memory bep2Symbol) payable public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindSyncPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSyncPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(contractAddr==bindSyncPkg.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can reject");
    uint256 relayFee = ITokenHub(TOKEN_HUB_ADDR).getRelayFee();
    require(msg.value == relayFee, "msg.value doesn't equal to syncRelayFee");
    delete bindPackageRecord[bep2TokenSymbol];
    ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
      status: BIND_STATUS_REJECTED,
      bep2TokenSymbol: bep2TokenSymbol
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), relayFee.div(1e10));
    return true;
  }

  function expireBind(string memory bep2Symbol) payable public returns (bool) {
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSyncPackage memory bindSyncPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSyncPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    require(bindSyncPkg.expireTime<block.timestamp, "bind request is not expired");
    uint256 relayFee = ITokenHub(TOKEN_HUB_ADDR).getRelayFee();
    require(msg.value == relayFee, "msg.value doesn't equal to syncRelayFee");
    delete bindPackageRecord[bep2TokenSymbol];
    ApproveBindSyncPackage memory approveBindSyncPackage = ApproveBindSyncPackage({
      status: BIND_STATUS_TIMEOUT,
      bep2TokenSymbol: bep2TokenSymbol
    });
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(BIND_CHANNELID, encodeApproveBindSyncPackage(approveBindSyncPackage), relayFee.div(1e10));
    return true;
  }

  function bep2TokenSymbolConvert(string memory symbol) internal pure returns(bytes32) {
    bytes32 result;
    assembly {
      result := mload(add(symbol, 32))
    }
    return result;
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
}
