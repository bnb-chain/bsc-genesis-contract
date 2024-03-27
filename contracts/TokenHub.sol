pragma solidity 0.6.4;

import "./interface/IBEP20.sol";
import "./interface/ITokenHub.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/ISystemReward.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./lib/BytesToTypes.sol";
import "./lib/Memory.sol";
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
        uint64 expireTime;
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
        uint64 expireTime;
    }

    // BSC to BC
    struct TransferInRefundPackage {
        bytes32 bep2TokenSymbol;
        uint256 refundAmount;
        address refundAddr;
        uint32 status;
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    struct LockInfo {
        uint256 amount;
        uint256 unlockAt;
    }

    // transfer in channel
    uint8 public constant TRANSFER_IN_SUCCESS = 0;
    uint8 public constant TRANSFER_IN_FAILURE_TIMEOUT = 1;
    uint8 public constant TRANSFER_IN_FAILURE_UNBOUND_TOKEN = 2;
    uint8 public constant TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE = 3;
    uint8 public constant TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT = 4;
    uint8 public constant TRANSFER_IN_FAILURE_UNKNOWN = 5;

    uint256 public constant MAX_BEP2_TOTAL_SUPPLY = 9000000000000000000;
    uint8 public constant MINIMUM_BEP20_SYMBOL_LEN = 2;
    uint8 public constant MAXIMUM_BEP20_SYMBOL_LEN = 8;
    uint8 public constant BEP2_TOKEN_DECIMALS = 8;
    bytes32 public constant BEP2_TOKEN_SYMBOL_FOR_BNB =
        0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
    uint256 public constant MAX_GAS_FOR_CALLING_BEP20 = 50000;
    uint256 public constant MAX_GAS_FOR_TRANSFER_BNB = 10000;

    uint256 public constant INIT_MINIMUM_RELAY_FEE = 2e15;
    uint256 public constant REWARD_UPPER_LIMIT = 1e18;
    uint256 public constant TEN_DECIMALS = 1e10;

    uint256 public relayFee;

    mapping(address => uint256) public bep20ContractDecimals;
    mapping(address => bytes32) private contractAddrToBEP2Symbol;
    mapping(bytes32 => address) private bep2SymbolToContractAddr;

    // BEP-171: Security Enhancement for Cross-Chain Module
    uint256 public constant INIT_BNB_LARGE_TRANSFER_LIMIT = 10000 ether;
    uint256 public constant INIT_LOCK_PERIOD = 12 hours;
    // the lock period for large cross-chain transfer
    uint256 public lockPeriod;
    // the lock Period for token recover
    uint256 public constant LOCK_PERIOD_FOR_TOKEN_RECOVER = 7 days;
    // token address => largeTransferLimit amount, address(0) means BNB
    mapping(address => uint256) public largeTransferLimitMap;
    // token address => recipient address => lockedAmount + unlockAt, address(0) means BNB
    mapping(address => mapping(address => LockInfo)) public lockInfoMap;
    uint8 internal reentryLock;

    event transferInSuccess(address bep20Addr, address refundAddr, uint256 amount);
    event transferOutSuccess(address bep20Addr, address senderAddr, uint256 amount, uint256 relayFee);
    event refundSuccess(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
    event refundFailure(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
    event rewardTo(address to, uint256 amount);
    event receiveDeposit(address from, uint256 amount);
    event unexpectedPackage(uint8 channelId, bytes msgBytes);
    event paramChange(string key, bytes value);

    // BEP-171: Security Enhancement for Cross-Chain Module
    event LargeTransferLocked(address indexed tokenAddr, address indexed recipient, uint256 amount, uint256 unlockAt);
    event WithdrawUnlockedToken(address indexed tokenAddr, address indexed recipient, uint256 amount);
    event CancelTransfer(address indexed tokenAddr, address indexed attacker, uint256 amount);
    event LargeTransferLimitSet(address indexed tokenAddr, address indexed owner, uint256 largeTransferLimit);

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
        uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
        if (actualAmount > REWARD_UPPER_LIMIT) {
            return 0;
        }
        if (actualAmount > 0) {
            to.transfer(actualAmount);
            emit rewardTo(to, actualAmount);
        }
        return actualAmount;
    }

    function claimMigrationFund(uint256 amount) external onlyStakeHub returns (bool) {
        if (address(this).balance >= amount) {
            payable(STAKE_HUB_ADDR).transfer(amount);
            return true;
        }
        return false;
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
        if (channelId == TRANSFER_IN_CHANNELID) {
            return handleTransferInSynPackage(msgBytes);
        } else {
            // should not happen
            require(false, "unrecognized syn package");
            return new bytes(0);
        }
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
        if (channelId == TRANSFER_OUT_CHANNELID) {
            handleTransferOutAckPackage(msgBytes);
        } else {
            emit unexpectedPackage(channelId, msgBytes);
        }
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
        if (channelId == TRANSFER_OUT_CHANNELID) {
            handleTransferOutFailAckPackage(msgBytes);
        } else {
            emit unexpectedPackage(channelId, msgBytes);
        }
    }

    function decodeTransferInSynPackage(bytes memory msgBytes)
        internal
        pure
        returns (TransferInSynPackage memory, bool)
    {
        TransferInSynPackage memory transInSynPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                transInSynPkg.bep2TokenSymbol = bytes32(iter.next().toUint());
            } else if (idx == 1) {
                transInSynPkg.contractAddr = iter.next().toAddress();
            } else if (idx == 2) {
                transInSynPkg.amount = iter.next().toUint();
            } else if (idx == 3) {
                transInSynPkg.recipient = ((iter.next().toAddress()));
            } else if (idx == 4) {
                transInSynPkg.refundAddr = iter.next().toAddress();
            } else if (idx == 5) {
                transInSynPkg.expireTime = uint64(iter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        return (transInSynPkg, success);
    }

    function encodeTransferInRefundPackage(TransferInRefundPackage memory transInAckPkg)
        internal
        pure
        returns (bytes memory)
    {
        bytes[] memory elements = new bytes[](4);
        elements[0] = uint256(transInAckPkg.bep2TokenSymbol).encodeUint();
        elements[1] = transInAckPkg.refundAmount.encodeUint();
        elements[2] = transInAckPkg.refundAddr.encodeAddress();
        elements[3] = uint256(transInAckPkg.status).encodeUint();
        return elements.encodeList();
    }

    function handleTransferInSynPackage(bytes memory msgBytes) internal returns (bytes memory) {
        (TransferInSynPackage memory transInSynPkg, bool success) = decodeTransferInSynPackage(msgBytes);
        require(success, "unrecognized transferIn package");
        uint32 resCode = doTransferIn(transInSynPkg);
        if (resCode != TRANSFER_IN_SUCCESS) {
            uint256 bep2Amount =
                convertToBep2Amount(transInSynPkg.amount, bep20ContractDecimals[transInSynPkg.contractAddr]);
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
        if (transInSynPkg.contractAddr == address(0x0)) {
            if (block.timestamp > transInSynPkg.expireTime) {
                return TRANSFER_IN_FAILURE_TIMEOUT;
            }
            if (address(this).balance < transInSynPkg.amount) {
                return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
            }

            // BEP-171: Security Enhancement for Cross-Chain Module
            if (!_checkAndLockTransferIn(transInSynPkg)) {
                // directly transfer to the recipient
                (bool success,) =
                    transInSynPkg.recipient.call{ gas: MAX_GAS_FOR_TRANSFER_BNB, value: transInSynPkg.amount }("");
                if (!success) {
                    return TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT;
                }
            }

            emit transferInSuccess(transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount);
            return TRANSFER_IN_SUCCESS;
        } else {
            if (block.timestamp > transInSynPkg.expireTime) {
                return TRANSFER_IN_FAILURE_TIMEOUT;
            }
            if (contractAddrToBEP2Symbol[transInSynPkg.contractAddr] != transInSynPkg.bep2TokenSymbol) {
                return TRANSFER_IN_FAILURE_UNBOUND_TOKEN;
            }
            uint256 actualBalance =
                IBEP20(transInSynPkg.contractAddr).balanceOf{ gas: MAX_GAS_FOR_CALLING_BEP20 }(address(this));
            if (actualBalance < transInSynPkg.amount) {
                return TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE;
            }

            // BEP-171: Security Enhancement for Cross-Chain Module
            if (!_checkAndLockTransferIn(transInSynPkg)) {
                bool success = IBEP20(transInSynPkg.contractAddr).transfer{ gas: MAX_GAS_FOR_CALLING_BEP20 }(
                    transInSynPkg.recipient, transInSynPkg.amount
                );
                if (!success) {
                    return TRANSFER_IN_FAILURE_UNKNOWN;
                }
            }

            emit transferInSuccess(transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount);
            return TRANSFER_IN_SUCCESS;
        }
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    function setLargeTransferLimit(
        address bep20Token,
        uint256 largeTransferLimit
    ) external onlyTokenOwner(bep20Token) {
        require(largeTransferLimit > 0, "zero limit not allowed");
        require(contractAddrToBEP2Symbol[bep20Token] != bytes32(0x00), "not bound");
        largeTransferLimitMap[bep20Token] = largeTransferLimit;

        emit LargeTransferLimitSet(bep20Token, msg.sender, largeTransferLimit);
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
        LockInfo storage lockInfo = lockInfoMap[tokenAddress][attacker];
        require(lockInfo.amount > 0, "no locked amount");

        uint256 _amount = lockInfo.amount;
        lockInfo.amount = 0;

        emit CancelTransfer(tokenAddress, attacker, _amount);
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    function _checkAndLockTransferIn(TransferInSynPackage memory transInSynPkg) internal returns (bool isLocked) {
        // check if BEP-171 params init
        if (largeTransferLimitMap[address(0x0)] == 0 && lockPeriod == 0) {
            largeTransferLimitMap[address(0x0)] = INIT_BNB_LARGE_TRANSFER_LIMIT;
            lockPeriod = INIT_LOCK_PERIOD;
        }

        // check if it is over large transfer limit
        uint256 _limit = largeTransferLimitMap[transInSynPkg.contractAddr];
        if (_limit == 0 || transInSynPkg.amount < _limit) {
            return false;
        }

        // it is over the large transfer limit
        // add time lock to recipient
        LockInfo storage lockInfo = lockInfoMap[transInSynPkg.contractAddr][transInSynPkg.recipient];
        lockInfo.amount = lockInfo.amount.add(transInSynPkg.amount);
        lockInfo.unlockAt = block.timestamp + lockPeriod;

        emit LargeTransferLocked(
            transInSynPkg.contractAddr, transInSynPkg.recipient, transInSynPkg.amount, lockInfo.unlockAt
        );
        return true;
    }

    function decodeTransferOutAckPackage(bytes memory msgBytes)
        internal
        pure
        returns (TransferOutAckPackage memory, bool)
    {
        TransferOutAckPackage memory transOutAckPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                transOutAckPkg.contractAddr = iter.next().toAddress();
            } else if (idx == 1) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutAckPkg.refundAmounts = new uint256[](list.length);
                for (uint256 index = 0; index < list.length; ++index) {
                    transOutAckPkg.refundAmounts[index] = list[index].toUint();
                }
            } else if (idx == 2) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutAckPkg.refundAddrs = new address[](list.length);
                for (uint256 index = 0; index < list.length; ++index) {
                    transOutAckPkg.refundAddrs[index] = list[index].toAddress();
                }
            } else if (idx == 3) {
                transOutAckPkg.status = uint32(iter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        return (transOutAckPkg, success);
    }

    function handleTransferOutAckPackage(bytes memory msgBytes) internal {
        (TransferOutAckPackage memory transOutAckPkg, bool decodeSuccess) = decodeTransferOutAckPackage(msgBytes);
        require(decodeSuccess, "unrecognized transferOut ack package");
        doRefund(transOutAckPkg);
    }

    function doRefund(TransferOutAckPackage memory transOutAckPkg) internal {
        if (transOutAckPkg.contractAddr == address(0x0)) {
            for (uint256 index = 0; index < transOutAckPkg.refundAmounts.length; ++index) {
                (bool success,) = transOutAckPkg.refundAddrs[index].call{
                    gas: MAX_GAS_FOR_TRANSFER_BNB,
                    value: transOutAckPkg.refundAmounts[index]
                }("");
                if (!success) {
                    emit refundFailure(
                        transOutAckPkg.contractAddr,
                        transOutAckPkg.refundAddrs[index],
                        transOutAckPkg.refundAmounts[index],
                        transOutAckPkg.status
                    );
                } else {
                    emit refundSuccess(
                        transOutAckPkg.contractAddr,
                        transOutAckPkg.refundAddrs[index],
                        transOutAckPkg.refundAmounts[index],
                        transOutAckPkg.status
                    );
                }
            }
        } else {
            for (uint256 index = 0; index < transOutAckPkg.refundAmounts.length; ++index) {
                bool success = IBEP20(transOutAckPkg.contractAddr).transfer{ gas: MAX_GAS_FOR_CALLING_BEP20 }(
                    transOutAckPkg.refundAddrs[index], transOutAckPkg.refundAmounts[index]
                );
                if (success) {
                    emit refundSuccess(
                        transOutAckPkg.contractAddr,
                        transOutAckPkg.refundAddrs[index],
                        transOutAckPkg.refundAmounts[index],
                        transOutAckPkg.status
                    );
                } else {
                    emit refundFailure(
                        transOutAckPkg.contractAddr,
                        transOutAckPkg.refundAddrs[index],
                        transOutAckPkg.refundAmounts[index],
                        transOutAckPkg.status
                    );
                }
            }
        }
    }

    function decodeTransferOutSynPackage(bytes memory msgBytes)
        internal
        pure
        returns (TransferOutSynPackage memory, bool)
    {
        TransferOutSynPackage memory transOutSynPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                transOutSynPkg.bep2TokenSymbol = bytes32(iter.next().toUint());
            } else if (idx == 1) {
                transOutSynPkg.contractAddr = iter.next().toAddress();
            } else if (idx == 2) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutSynPkg.amounts = new uint256[](list.length);
                for (uint256 index = 0; index < list.length; ++index) {
                    transOutSynPkg.amounts[index] = list[index].toUint();
                }
            } else if (idx == 3) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutSynPkg.recipients = new address[](list.length);
                for (uint256 index = 0; index < list.length; ++index) {
                    transOutSynPkg.recipients[index] = list[index].toAddress();
                }
            } else if (idx == 4) {
                RLPDecode.RLPItem[] memory list = iter.next().toList();
                transOutSynPkg.refundAddrs = new address[](list.length);
                for (uint256 index = 0; index < list.length; ++index) {
                    transOutSynPkg.refundAddrs[index] = list[index].toAddress();
                }
            } else if (idx == 5) {
                transOutSynPkg.expireTime = uint64(iter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        return (transOutSynPkg, success);
    }

    function handleTransferOutFailAckPackage(bytes memory msgBytes) internal {
        (TransferOutSynPackage memory transOutSynPkg, bool decodeSuccess) = decodeTransferOutSynPackage(msgBytes);
        require(decodeSuccess, "unrecognized transferOut syn package");
        TransferOutAckPackage memory transOutAckPkg;
        transOutAckPkg.contractAddr = transOutSynPkg.contractAddr;
        transOutAckPkg.refundAmounts = transOutSynPkg.amounts;
        uint256 bep20TokenDecimals = bep20ContractDecimals[transOutSynPkg.contractAddr];
        for (uint256 idx = 0; idx < transOutSynPkg.amounts.length; ++idx) {
            transOutSynPkg.amounts[idx] = convertFromBep2Amount(transOutSynPkg.amounts[idx], bep20TokenDecimals);
        }
        transOutAckPkg.refundAddrs = transOutSynPkg.refundAddrs;
        transOutAckPkg.status = TRANSFER_IN_FAILURE_UNKNOWN;
        doRefund(transOutAckPkg);
    }

    function encodeTransferOutSynPackage(TransferOutSynPackage memory transOutSynPkg)
        internal
        pure
        returns (bytes memory)
    {
        bytes[] memory elements = new bytes[](6);

        elements[0] = uint256(transOutSynPkg.bep2TokenSymbol).encodeUint();
        elements[1] = transOutSynPkg.contractAddr.encodeAddress();

        uint256 batchLength = transOutSynPkg.amounts.length;

        bytes[] memory amountsElements = new bytes[](batchLength);
        for (uint256 index = 0; index < batchLength; ++index) {
            amountsElements[index] = transOutSynPkg.amounts[index].encodeUint();
        }
        elements[2] = amountsElements.encodeList();

        bytes[] memory recipientsElements = new bytes[](batchLength);
        for (uint256 index = 0; index < batchLength; ++index) {
            recipientsElements[index] = transOutSynPkg.recipients[index].encodeAddress();
        }
        elements[3] = recipientsElements.encodeList();

        bytes[] memory refundAddrsElements = new bytes[](batchLength);
        for (uint256 index = 0; index < batchLength; ++index) {
            refundAddrsElements[index] = transOutSynPkg.refundAddrs[index].encodeAddress();
        }
        elements[4] = refundAddrsElements.encodeList();

        elements[5] = uint256(transOutSynPkg.expireTime).encodeUint();
        return elements.encodeList();
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
        require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
        require(
            recipientAddrs.length == refundAddrs.length,
            "Length of recipientAddrs doesn't equal to length of refundAddrs"
        );
        require(expireTime >= block.timestamp + 120, "expireTime must be two minutes later");
        require(msg.value % TEN_DECIMALS == 0, "invalid received BNB amount: precision loss in amount conversion");
        uint256 batchLength = amounts.length;
        uint256 totalAmount = 0;
        uint256 rewardForRelayer;
        uint256[] memory convertedAmounts = new uint256[](batchLength);
        for (uint256 i = 0; i < batchLength; ++i) {
            require(amounts[i] % TEN_DECIMALS == 0, "invalid transfer amount: precision loss in amount conversion");
            totalAmount = totalAmount.add(amounts[i]);
            convertedAmounts[i] = amounts[i].div(TEN_DECIMALS);
        }
        require(
            msg.value >= totalAmount.add(relayFee.mul(batchLength)),
            "received BNB amount should be no less than the sum of transfer BNB amount and relayFee"
        );
        rewardForRelayer = msg.value.sub(totalAmount);

        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage({
            bep2TokenSymbol: BEP2_TOKEN_SYMBOL_FOR_BNB,
            contractAddr: address(0x00),
            amounts: convertedAmounts,
            recipients: recipientAddrs,
            refundAddrs: refundAddrs,
            expireTime: expireTime
        });
        ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(
            TRANSFER_OUT_CHANNELID, encodeTransferOutSynPackage(transOutSynPkg), rewardForRelayer.div(TEN_DECIMALS)
        );
        emit transferOutSuccess(address(0x0), msg.sender, totalAmount, rewardForRelayer);
        return true;
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyGov {
        require(value.length == 32, "expected value length is 32");
        string memory localKey = key;
        bytes memory localValue = value;
        bytes32 bytes32Key;
        assembly {
            bytes32Key := mload(add(localKey, 32))
        }
        if (bytes32Key == bytes32(0x72656c6179466565000000000000000000000000000000000000000000000000)) {
            // relayFee
            uint256 newRelayFee;
            assembly {
                newRelayFee := mload(add(localValue, 32))
            }
            require(newRelayFee <= 1e18 && newRelayFee % (TEN_DECIMALS) == 0, "the relayFee out of range");
            relayFee = newRelayFee;
        } else if (Memory.compareStrings(key, "largeTransferLockPeriod")) {
            uint256 newLockPeriod = BytesToTypes.bytesToUint256(32, value);
            require(newLockPeriod <= 1 weeks, "lock period too long");
            lockPeriod = newLockPeriod;
        } else if (Memory.compareStrings(key, "bnbLargeTransferLimit")) {
            uint256 newBNBLargeTransferLimit = BytesToTypes.bytesToUint256(32, value);
            require(newBNBLargeTransferLimit >= 100 ether, "bnb large transfer limit too small");
            largeTransferLimitMap[address(0x0)] = newBNBLargeTransferLimit;
        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external view override returns (address) {
        return bep2SymbolToContractAddr[bep2Symbol];
    }

    function getBep2SymbolByContractAddr(address contractAddr) external view override returns (bytes32) {
        return contractAddrToBEP2Symbol[contractAddr];
    }

    function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external override onlyTokenManager {
        bep2SymbolToContractAddr[bep2Symbol] = contractAddr;
        contractAddrToBEP2Symbol[contractAddr] = bep2Symbol;
        bep20ContractDecimals[contractAddr] = decimals;
    }

    function unbindToken(bytes32 bep2Symbol, address contractAddr) external override onlyTokenManager {
        delete bep2SymbolToContractAddr[bep2Symbol];
        delete contractAddrToBEP2Symbol[contractAddr];
        delete bep20ContractDecimals[contractAddr];
    }

    function isMiniBEP2Token(bytes32 symbol) internal pure returns (bool) {
        bytes memory symbolBytes = new bytes(32);
        assembly {
            mstore(add(symbolBytes, 32), symbol)
        }
        uint8 symbolLength = 0;
        for (uint8 j = 0; j < 32; ++j) {
            if (symbolBytes[j] != 0) {
                ++symbolLength;
            } else {
                break;
            }
        }
        if (symbolLength < MINIMUM_BEP20_SYMBOL_LEN + 5) {
            return false;
        }
        if (symbolBytes[symbolLength - 5] != 0x2d) {
            // '-'
            return false;
        }
        if (symbolBytes[symbolLength - 1] != "M") {
            // ABC-XXXM
            return false;
        }
        return true;
    }

    function convertToBep2Amount(uint256 amount, uint256 bep20TokenDecimals) internal pure returns (uint256) {
        if (bep20TokenDecimals > BEP2_TOKEN_DECIMALS) {
            return amount.div(10 ** (bep20TokenDecimals - BEP2_TOKEN_DECIMALS));
        }
        return amount.mul(10 ** (BEP2_TOKEN_DECIMALS - bep20TokenDecimals));
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
        require(msg.sender == STAKING_CONTRACT_ADDR, "only staking system contract can call this function");
        if (amount != 0) {
            payable(STAKING_CONTRACT_ADDR).transfer(amount);
        }
        return true;
    }
}
