pragma solidity 0.6.4;

import "../interface/0.6.x/IBEP20.sol";
import "../interface/0.6.x/IApplication.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../lib/0.6.x/SafeMath.sol";
import "../System.sol";

contract TokenManager is System, IApplication, IParamSubscriber {
    using SafeMath for uint256;

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
