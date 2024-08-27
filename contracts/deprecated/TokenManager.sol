pragma solidity 0.6.4;

import "../interface/0.6.x/IBEP20.sol";
import "../interface/0.6.x/ITokenHub.sol";
import "../interface/0.6.x/IApplication.sol";
import "../interface/0.6.x/ICrossChain.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../lib/0.6.x/SafeMath.sol";
import "../lib/0.6.x/RLPEncode.sol";
import "../lib/0.6.x/RLPDecode.sol";
import "../System.sol";

contract TokenManager is System, IApplication, IParamSubscriber {
    using SafeMath for uint256;

    using RLPEncode for *;
    using RLPDecode for *;

    using RLPDecode for RLPDecode.RLPItem;
    using RLPDecode for RLPDecode.Iterator;

    // BC to BSC
    struct BindSynPackage {
        uint8 packageType;
        bytes32 bep2TokenSymbol;
        address contractAddr;
        uint256 totalSupply;
        uint256 peggyAmount;
        uint8 bep20Decimals;
        uint64 expireTime;
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
        uint8 bep20Decimals;
        uint256 mirrorFee;
        uint64 expireTime;
    }

    // BC to BSC
    struct MirrorAckPackage {
        address mirrorSender;
        address bep20Addr;
        uint8 bep20Decimals;
        bytes32 bep2Symbol;
        uint256 mirrorFee;
        uint8 errorCode;
    }

    // BSC to BC
    struct SyncSynPackage {
        address syncSender;
        address bep20Addr;
        bytes32 bep2Symbol;
        uint256 bep20Supply;
        uint256 syncFee;
        uint64 expireTime;
    }

    // BC to BSC
    struct SyncAckPackage {
        address syncSender;
        address bep20Addr;
        uint256 syncFee;
        uint8 errorCode;
    }

    uint8 public constant BIND_PACKAGE = 0;
    uint8 public constant UNBIND_PACKAGE = 1;

    // bind status
    uint8 public constant BIND_STATUS_TIMEOUT = 1;
    uint8 public constant BIND_STATUS_SYMBOL_MISMATCH = 2;
    uint8 public constant BIND_STATUS_TOO_MUCH_TOKENHUB_BALANCE = 3;
    uint8 public constant BIND_STATUS_TOTAL_SUPPLY_MISMATCH = 4;
    uint8 public constant BIND_STATUS_DECIMALS_MISMATCH = 5;
    uint8 public constant BIND_STATUS_ALREADY_BOUND_TOKEN = 6;
    uint8 public constant BIND_STATUS_REJECTED = 7;

    uint8 public constant MIRROR_CHANNELID = 0x04;
    uint8 public constant SYNC_CHANNELID = 0x05;
    uint8 public constant BEP2_TOKEN_DECIMALS = 8;
    uint256 public constant MAX_GAS_FOR_TRANSFER_BNB = 10000;
    uint256 public constant MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
    uint256 public constant LOG_MAX_UINT256 = 77;
    // mirror status
    uint8 public constant MIRROR_STATUS_TIMEOUT = 1;
    uint8 public constant MIRROR_STATUS_DUPLICATED_BEP2_SYMBOL = 2;
    uint8 public constant MIRROR_STATUS_ALREADY_BOUND = 3;
    // sync status
    uint8 public constant SYNC_STATUS_TIMEOUT = 1;
    uint8 public constant SYNC_STATUS_NOT_BOUND_MIRROR = 2;

    uint8 public constant MINIMUM_BEP20_SYMBOL_LEN = 2;
    uint8 public constant MAXIMUM_BEP20_SYMBOL_LEN = 8;

    uint256 public constant TEN_DECIMALS = 1e10;

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

    function handleSynPackage(
        uint8 channelId,
        bytes calldata msgBytes
    ) external override onlyCrossChainContract returns (bytes memory) {
        revert("deprecated");
    }

    function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external override onlyCrossChainContract {
        revert("deprecated");
    }

    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external override onlyCrossChainContract {
        revert("deprecated");
    }

    function approveBind(address contractAddr, string memory bep2Symbol) public payable returns (bool) {
        revert("deprecated");
    }

    function rejectBind(address contractAddr, string memory bep2Symbol) public payable returns (bool) {
        revert("deprecated");
    }

    function expireBind(string memory bep2Symbol) public payable returns (bool) {
        revert("deprecated");
    }

    function mirror(address bep20Addr, uint64 expireTime) public payable returns (bool) {
        revert("deprecated");
    }

    function sync(address bep20Addr, uint64 expireTime) public payable returns (bool) {
        revert("deprecated");
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyGov {
        revert("deprecated");
    }

    function queryRequiredLockAmountForBind(string memory symbol) public view returns (uint256) {
        bytes32 bep2Symbol;
        assembly {
            bep2Symbol := mload(add(symbol, 32))
        }
        BindSynPackage memory bindRequest = bindPackageRecord[bep2Symbol];
        if (bindRequest.contractAddr == address(0x00)) {
            return 0;
        }
        uint256 tokenHubBalance = IBEP20(bindRequest.contractAddr).balanceOf(TOKEN_HUB_ADDR);
        uint256 requiredBalance = bindRequest.totalSupply.sub(bindRequest.peggyAmount);
        return requiredBalance.sub(tokenHubBalance);
    }
}
