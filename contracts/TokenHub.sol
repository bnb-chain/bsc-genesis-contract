pragma solidity 0.6.4;

import "./interface/0.6.x/IBEP20.sol";
import "./interface/0.6.x/ITokenHub.sol";
import "./interface/0.6.x/IParamSubscriber.sol";
import "./interface/0.6.x/IApplication.sol";
import "./interface/0.6.x/ISystemReward.sol";
import "./lib/0.6.x/SafeMath.sol";
import "./System.sol";

contract TokenHub is ITokenHub, System, IParamSubscriber, IApplication, ISystemReward {
    using SafeMath for uint256;

    // BEP-171: Security Enhancement for Cross-Chain Module
    struct LockInfo {
        uint256 amount;
        uint256 unlockAt;
    }

    uint256 public constant MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
    uint8 public constant BEP2_TOKEN_DECIMALS = 8;
    bytes32 public constant BEP2_TOKEN_SYMBOL_FOR_BNB =
        0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"

    uint256 public constant INIT_MINIMUM_RELAY_FEE = 2e15;
    uint256 public constant REWARD_UPPER_LIMIT = 1e18;
    uint256 public constant TEN_DECIMALS = 1e10;
    uint256 public constant MAX_GAS_FOR_CALLING_BEP20 = 50000;
    uint256 public constant MAX_GAS_FOR_TRANSFER_BNB = 10000;

    uint256 public relayFee;

    mapping(address => uint256) public bep20ContractDecimals;
    mapping(address => bytes32) private contractAddrToBEP2Symbol;
    mapping(bytes32 => address) private bep2SymbolToContractAddr;

    // BEP-171: Security Enhancement for Cross-Chain Module
    // the lock period for large cross-chain transfer
    uint256 public lockPeriod;  // @dev deprecated
    // the lock Period for token recover
    uint256 public constant LOCK_PERIOD_FOR_TOKEN_RECOVER = 7 days;
    // token address => largeTransferLimit amount, address(0) means BNB
    mapping(address => uint256) public largeTransferLimitMap;  // @dev deprecated
    // token address => recipient address => lockedAmount + unlockAt, address(0) means BNB
    mapping(address => mapping(address => LockInfo)) public lockInfoMap;
    uint8 internal reentryLock;

    event rewardTo(address to, uint256 amount);
    event receiveDeposit(address from, uint256 amount);
    event WithdrawUnlockedToken(address indexed tokenAddr, address indexed recipient, uint256 amount);

    event transferInSuccess(address bep20Addr, address refundAddr, uint256 amount);  // @dev deprecated
    event transferOutSuccess(address bep20Addr, address senderAddr, uint256 amount, uint256 relayFee);  // @dev deprecated
    event refundSuccess(address bep20Addr, address refundAddr, uint256 amount, uint32 status);  // @dev deprecated
    event refundFailure(address bep20Addr, address refundAddr, uint256 amount, uint32 status);  // @dev deprecated
    event unexpectedPackage(uint8 channelId, bytes msgBytes);  // @dev deprecated
    event paramChange(string key, bytes value);  // @dev deprecated
    event LargeTransferLocked(address indexed tokenAddr, address indexed recipient, uint256 amount, uint256 unlockAt);  // @dev deprecated
    event CancelTransfer(address indexed tokenAddr, address indexed attacker, uint256 amount);  // @dev deprecated
    event LargeTransferLimitSet(address indexed tokenAddr, address indexed owner, uint256 largeTransferLimit);  // @dev deprecated

    // BEP-299: Token Migration after BC Fusion
    event TokenRecoverLocked(
        bytes32 indexed tokenSymbol,
        address indexed tokenAddr,
        address indexed recipient,
        uint256 amount,
        uint256 unlockAt
    );
    event CancelTokenRecoverLock(
        bytes32 indexed tokenSymbol, address indexed tokenAddr, address indexed attacker, uint256 amount
    );
    event NotBoundToken(bytes32 indexed tokenSymbol, address indexed recipient, uint256 amount);

    // BEP-171: Security Enhancement for Cross-Chain Module
    modifier onlyTokenOwner(address bep20Token) {
        require(msg.sender == IBEP20(bep20Token).getOwner(), "not owner of BEP20 token");
        _;
    }

    modifier noReentrant() {
        require(reentryLock != 2, "No re-entrancy");
        reentryLock = 2;
        _;
        reentryLock = 1;
    }

    function init() external onlyNotInit {
        relayFee = INIT_MINIMUM_RELAY_FEE;
        bep20ContractDecimals[address(0x0)] = 18; // BNB decimals is 18
        alreadyInit = true;
    }

    receive() external payable {
        if (msg.value > 0) {
            emit receiveDeposit(msg.sender, msg.value);
        }
    }

    /**
     * @dev Claim relayer reward to target account
     *
     * @param to Whose relay reward will be claimed.
     * @param amount Reward amount
     */
    function claimRewards(
        address payable to,
        uint256 amount
    ) external override onlyInit onlyRelayerIncentivize returns (uint256) {
        revert("deprecated");
    }

    function claimMigrationFund(uint256 amount) external onlyStakeHub returns (bool) {
        revert("deprecated");
    }

    function getMiniRelayFee() external view override returns (uint256) {
        return relayFee;
    }

    /**
     * @dev handle sync cross-chain package from BC
     *
     * @param channelId The channel for cross-chain communication
     * @param msgBytes The rlp encoded message bytes sent from BC
     */
    function handleSynPackage(
        uint8 channelId,
        bytes calldata msgBytes
    ) external override onlyInit onlyCrossChainContract returns (bytes memory) {
        revert("deprecated");
    }

    /**
     * @dev handle ack cross-chain package from BC，it means cross-chain transfer successfully to BC
     * and will refund the remaining token caused by different decimals between BSC and BC.
     *
     * @param channelId The channel for cross-chain communication
     * @param msgBytes The rlp encoded message bytes sent from BC
     */
    function handleAckPackage(
        uint8 channelId,
        bytes calldata msgBytes
    ) external override onlyInit onlyCrossChainContract {
        revert("deprecated");
    }

    /**
     * @dev handle failed ack cross-chain package from BC, it means failed to cross-chain transfer to BC and will refund the token.
     *
     * @param channelId The channel for cross-chain communication
     * @param msgBytes The rlp encoded message bytes sent from BC
     */
    function handleFailAckPackage(
        uint8 channelId,
        bytes calldata msgBytes
    ) external override onlyInit onlyCrossChainContract {
        revert("deprecated");
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    function setLargeTransferLimit(
        address bep20Token,
        uint256 largeTransferLimit
    ) external onlyTokenOwner(bep20Token) {
        revert("deprecated");
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    function withdrawUnlockedToken(address tokenAddress, address recipient) external noReentrant {
        LockInfo storage lockInfo = lockInfoMap[tokenAddress][recipient];
        require(lockInfo.amount > 0, "no locked amount");
        require(block.timestamp >= lockInfo.unlockAt, "still on locking period");

        uint256 _amount = lockInfo.amount;
        lockInfo.amount = 0;

        bool _success;
        if (tokenAddress == address(0x0)) {
            (_success,) = recipient.call{ gas: MAX_GAS_FOR_TRANSFER_BNB, value: _amount }("");
        } else {
            _success = IBEP20(tokenAddress).transfer{ gas: MAX_GAS_FOR_CALLING_BEP20 }(recipient, _amount);
        }
        require(_success, "withdraw unlocked token failed");

        emit WithdrawUnlockedToken(tokenAddress, recipient, _amount);
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    function cancelTransferIn(address tokenAddress, address attacker) external override onlyCrossChainContract {
        revert("deprecated");
    }

    /**
     * @dev request a BC token recover from BSC
     *
     * @param tokenSymbol The token symbol on BSC.
     * @param recipient The destination address of the transfer on BSC.
     * @param amount The amount to transfer
     */
    function recoverBCAsset(
        bytes32 tokenSymbol,
        address recipient,
        uint256 amount
    ) external override onlyInit onlyTokenRecoverPortal {
        require(amount <= MAX_BEP2_TOTAL_SUPPLY, "amount is too large, exceed maximum bep2 token amount");
        uint256 convertedAmount;
        if (tokenSymbol != BEP2_TOKEN_SYMBOL_FOR_BNB) {
            address contractAddr = bep2SymbolToContractAddr[tokenSymbol];
            if (contractAddr == address(0x00)) {
                // if the token is not bound, just emit an event
                // please notify the token owner to handle the token recovery
                emit NotBoundToken(tokenSymbol, recipient, amount);
                return;
            }

            uint256 bep20TokenDecimals = bep20ContractDecimals[contractAddr];
            convertedAmount = convertFromBep2Amount(amount, bep20TokenDecimals); // convert to bep20 amount
            require(IBEP20(contractAddr).balanceOf(address(this)) >= convertedAmount, "insufficient balance");
            _lockRecoverToken(tokenSymbol, contractAddr, convertedAmount, recipient);
        } else {
            convertedAmount = amount.mul(TEN_DECIMALS); // native bnb decimals is 8 on BC, while the native bnb decimals on BSC is 18
            require(address(this).balance >= convertedAmount, "insufficient balance");
            address contractAddr = address(0x00);
            _lockRecoverToken(tokenSymbol, contractAddr, convertedAmount, recipient);
        }
    }

    // lock the token for 7 days to the recipient address
    function _lockRecoverToken(bytes32 tokenSymbol, address contractAddr, uint256 amount, address recipient) internal {
        LockInfo storage lockInfo = lockInfoMap[contractAddr][recipient];
        lockInfo.amount = lockInfo.amount.add(amount);
        lockInfo.unlockAt = block.timestamp + LOCK_PERIOD_FOR_TOKEN_RECOVER;

        emit TokenRecoverLocked(tokenSymbol, contractAddr, recipient, amount, lockInfo.unlockAt);
    }

    function cancelTokenRecoverLock(bytes32 tokenSymbol, address attacker) external override onlyTokenRecoverPortal {
        address tokenAddress = address(0x00);
        if (tokenSymbol != BEP2_TOKEN_SYMBOL_FOR_BNB) {
            tokenAddress = bep2SymbolToContractAddr[tokenSymbol];
            require(tokenAddress != address(0x00), "invalid symbol");
        }
        LockInfo storage lockInfo = lockInfoMap[tokenAddress][attacker];
        require(lockInfo.amount > 0, "no locked amount");

        uint256 _amount = lockInfo.amount;
        lockInfo.amount = 0;

        emit CancelTokenRecoverLock(tokenSymbol, tokenAddress, attacker, _amount);
    }

    /**
     * @dev request a cross-chain transfer from BSC to BC
     * @notice this function is deprecated after Feynman upgrade
     *
     * @param contractAddr The token contract which is transferred
     * @param recipient The destination address of the cross-chain transfer on BC.
     * @param amount The amount to transfer
     * @param expireTime The expire time for the cross-chain transfer
     */
    function transferOut(
        address contractAddr,
        address recipient,
        uint256 amount,
        uint64 expireTime
    ) external payable override onlyInit returns (bool) {
        revert("deprecated");
    }

    /**
     * @dev request a batch cross-chain BNB transfers from BSC to BC
     *
     * @param recipientAddrs The destination address of the cross-chain transfer on BC.
     * @param amounts The amounts to transfer
     * @param refundAddrs The refund addresses that receive the refund funds while failed to cross-chain transfer
     * @param expireTime The expire time for these cross-chain transfers
     */
    function batchTransferOutBNB(
        address[] calldata recipientAddrs,
        uint256[] calldata amounts,
        address[] calldata refundAddrs,
        uint64 expireTime
    ) external payable override onlyInit returns (bool) {
        revert("deprecated");
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyGov {
        revert("deprecated");
    }

    function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external view override returns (address) {
        return bep2SymbolToContractAddr[bep2Symbol];
    }

    function getBep2SymbolByContractAddr(address contractAddr) external view override returns (bytes32) {
        return contractAddrToBEP2Symbol[contractAddr];
    }

    function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external override onlyTokenManager {
        revert("deprecated");
    }

    function unbindToken(bytes32 bep2Symbol, address contractAddr) external override onlyTokenManager {
        revert("deprecated");
    }

    function convertFromBep2Amount(uint256 amount, uint256 bep20TokenDecimals) internal pure returns (uint256) {
        if (bep20TokenDecimals > BEP2_TOKEN_DECIMALS) {
            return amount.mul(10 ** (bep20TokenDecimals - BEP2_TOKEN_DECIMALS));
        }
        return amount.div(10 ** (BEP2_TOKEN_DECIMALS - bep20TokenDecimals));
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
            mstore(add(bep2SymbolBytes, 32), bep2SymbolBytes32)
        }
        uint8 bep2SymbolLength = 0;
        for (uint8 j = 0; j < 32; ++j) {
            if (bep2SymbolBytes[j] != 0) {
                ++bep2SymbolLength;
            } else {
                break;
            }
        }
        bytes memory bep2Symbol = new bytes(bep2SymbolLength);
        for (uint8 j = 0; j < bep2SymbolLength; ++j) {
            bep2Symbol[j] = bep2SymbolBytes[j];
        }
        return string(bep2Symbol);
    }

    function withdrawStakingBNB(uint256 amount) external override returns (bool) {
        revert("deprecated");
    }
}
