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
  struct BindSynPackage {
    uint8   packageType;
    bytes32 bep2TokenSymbol;
    address contractAddr;
    uint256 totalSupply;
    uint256 peggyAmount;
    uint8   bep2eDecimals;
    uint64  expireTime;
  }

  // BSC to BC
  struct ReactBindSynPackage {
    uint32 status;
    bytes32 bep2TokenSymbol;
  }

  uint8 constant public   BIND_PACKAGE = 0;
  uint8 constant public   UNBIND_PACKAGE = 1;

  // bind status
  uint8 constant public   BIND_STATUS_SUCCESS = 0;
  uint8 constant public   BIND_STATUS_TIMEOUT = 1;
  uint8 constant public   BIND_STATUS_SYMBOL_MISMATCH = 2;
  uint8 constant public   BIND_STATUS_TOO_MUCH_TOKENHUB_BALANCE = 3;
  uint8 constant public   BIND_STATUS_TOTAL_SUPPLY_MISMATCH = 4;
  uint8 constant public   BIND_STATUS_DECIMALS_MISMATCH = 5;
  uint8 constant public   BIND_STATUS_ALREADY_BOUND_TOKEN = 6;
  uint8 constant public   BIND_STATUS_REJECTED = 7;

  uint8 constant public   MINIMUM_BEP2E_SYMBOL_LEN = 3;
  uint8 constant public   MAXIMUM_BEP2E_SYMBOL_LEN = 8;

  uint256 constant public  TEN_DECIMALS = 1e10;

  mapping(bytes32 => BindSynPackage) public bindPackageRecord;

  event bindSuccess(address indexed contractAddr, string bep2Symbol, uint256 totalSupply, uint256 peggyAmount);
  event bindFailure(address indexed contractAddr, string bep2Symbol, uint32 failedReason);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);

  constructor() public {}

  function handleSynPackage(uint8 /* channelId */, bytes calldata msgBytes) onlyCrossChainContract external override returns(bytes memory) {
    return handleBindSynPackage(msgBytes);
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    emit unexpectedPackage(channelId, msgBytes);
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) onlyCrossChainContract external override {
    emit unexpectedPackage(channelId, msgBytes);
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
        else if (idx == 5) bindSynPkg.bep2eDecimals    = uint8(iter.next().toUint());
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
    bytes32 bep2TokenSymbol = bep2TokenSymbolConvert(bep2Symbol);
    BindSynPackage memory bindSynPkg = bindPackageRecord[bep2TokenSymbol];
    require(bindSynPkg.bep2TokenSymbol!=bytes32(0x00), "bind request doesn't exist");
    uint256 lockedAmount = bindSynPkg.totalSupply.sub(bindSynPkg.peggyAmount);
    require(contractAddr==bindSynPkg.contractAddr, "contact address doesn't equal to the contract address in bind request");
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can approve this bind request");
    uint256 tokenHubBalance = IBEP2E(contractAddr).balanceOf(TOKEN_HUB_ADDR);
    require(IBEP2E(contractAddr).allowance(msg.sender, address(this)).add(tokenHubBalance)>=lockedAmount, "allowance is not enough");
    uint256 relayFee = msg.value;
    uint256 miniRelayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
    require(relayFee >= miniRelayFee && relayFee%TEN_DECIMALS == 0, "relayFee must be N * 1e10 and greater than miniRelayFee");

    uint32 verifyCode = verifyBindParameters(bindSynPkg, contractAddr);
    if (verifyCode == BIND_STATUS_SUCCESS) {
      IBEP2E(contractAddr).transferFrom(msg.sender, TOKEN_HUB_ADDR, lockedAmount.sub(tokenHubBalance));
      ITokenHub(TOKEN_HUB_ADDR).bindToken(bindSynPkg.bep2TokenSymbol, bindSynPkg.contractAddr, bindSynPkg.bep2eDecimals);
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
    require(IBEP2E(contractAddr).getOwner()==msg.sender, "only bep2e owner can reject");
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

  function bep2TokenSymbolConvert(string memory symbol) internal pure returns(bytes32) {
    bytes32 result;
    assembly {
      result := mload(add(symbol, 32))
    }
    return result;
  }

  function verifyBindParameters(BindSynPackage memory bindSynPkg, address contractAddr) internal view returns(uint32) {
    uint256 decimals = IBEP2E(contractAddr).decimals();
    string memory bep2eSymbol = IBEP2E(contractAddr).symbol();
    uint256 tokenHubBalance = IBEP2E(contractAddr).balanceOf(TOKEN_HUB_ADDR);
    uint256 lockedAmount = bindSynPkg.totalSupply.sub(bindSynPkg.peggyAmount);
    if (bindSynPkg.expireTime<block.timestamp) {
      return BIND_STATUS_TIMEOUT;
    }
    if (!checkSymbol(bep2eSymbol, bindSynPkg.bep2TokenSymbol)) {
      return BIND_STATUS_SYMBOL_MISMATCH;
    }
    if (tokenHubBalance > lockedAmount) {
      return BIND_STATUS_TOO_MUCH_TOKENHUB_BALANCE;
    }
    if (IBEP2E(bindSynPkg.contractAddr).totalSupply() != bindSynPkg.totalSupply) {
      return BIND_STATUS_TOTAL_SUPPLY_MISMATCH;
    }
    if (decimals!=bindSynPkg.bep2eDecimals) {
      return BIND_STATUS_DECIMALS_MISMATCH;
    }
    if (ITokenHub(TOKEN_HUB_ADDR).getContractAddrByBEP2Symbol(bindSynPkg.bep2TokenSymbol)!=address(0x00)||
    ITokenHub(TOKEN_HUB_ADDR).getBep2SymbolByContractAddr(bindSynPkg.contractAddr)!=bytes32(0x00)) {
      return BIND_STATUS_ALREADY_BOUND_TOKEN;
    }
    return BIND_STATUS_SUCCESS;
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
    for (uint256 index=0; index < bep2eSymbolBytes.length; index++) {
      if (bep2eSymbolBytes[index] != bep2TokenSymbolBytes[index]) {
        symbolMatch = false;
        break;
      }
    }
    return symbolMatch;
  }
}
