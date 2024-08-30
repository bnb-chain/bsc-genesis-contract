pragma solidity 0.6.4;

import "../interface/0.6.x/IBEP20.sol";
import "../interface/0.6.x/IApplication.sol";
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

    mapping(address => bool) public mirrorPendingRecord;  // @dev deprecated
    mapping(address => bool) public boundByMirror;  // @dev deprecated
    uint256 public mirrorFee;  // @dev deprecated
    uint256 public syncFee;  // @dev deprecated

    event bindSuccess(address indexed contractAddr, string bep2Symbol, uint256 totalSupply, uint256 peggyAmount);  // @dev deprecated
    event bindFailure(address indexed contractAddr, string bep2Symbol, uint32 failedReason);  // @dev deprecated
    event unexpectedPackage(uint8 channelId, bytes msgBytes);  // @dev deprecated
    event paramChange(string key, bytes value);  // @dev deprecated
    event mirrorSuccess(address indexed bep20Addr, bytes32 bep2Symbol);  // @dev deprecated
    event mirrorFailure(address indexed bep20Addr, uint8 errCode);  // @dev deprecated
    event syncSuccess(address indexed bep20Addr);  // @dev deprecated
    event syncFailure(address indexed bep20Addr, uint8 errCode);  // @dev deprecated

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
