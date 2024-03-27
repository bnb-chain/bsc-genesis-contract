pragma solidity 0.6.4;

import "./System.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IStaking.sol";
import "./interface/ITokenHub.sol";
import "./lib/BytesToTypes.sol";
import "./lib/BytesLib.sol";
import "./lib/CmnPkg.sol";
import "./lib/Memory.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./lib/SafeMath.sol";

contract Staking is IStaking, System, IParamSubscriber, IApplication {
    using SafeMath for uint256;
    using RLPEncode for *;
    using RLPDecode for *;

    // Cross Stake Event type
    uint8 public constant EVENT_DELEGATE = 0x01;
    uint8 public constant EVENT_UNDELEGATE = 0x02;
    uint8 public constant EVENT_REDELEGATE = 0x03;
    uint8 public constant EVENT_DISTRIBUTE_REWARD = 0x04;
    uint8 public constant EVENT_DISTRIBUTE_UNDELEGATED = 0x05;

    // ack package status code
    uint8 public constant CODE_FAILED = 0;
    uint8 public constant CODE_SUCCESS = 1;

    // Error code
    uint32 public constant ERROR_WITHDRAW_BNB = 101;

    uint256 public constant TEN_DECIMALS = 1e10;
    uint256 public constant LOCK_TIME = 8 days; // 8*24*3600 second

    uint256 public constant INIT_RELAYER_FEE = 16 * 1e15;
    uint256 public constant INIT_BSC_RELAYER_FEE = 1 * 1e16;
    uint256 public constant INIT_MIN_DELEGATION = 100 * 1e18;
    uint256 public constant INIT_TRANSFER_GAS = 2300;

    uint256 public relayerFee;
    uint256 public bSCRelayerFee;
    uint256 public minDelegation;

    mapping(address => uint256) delegated; // delegator => totalAmount
    mapping(address => mapping(address => uint256)) delegatedOfValidator; // delegator => validator => amount
    mapping(address => uint256) distributedReward; // delegator => reward
    mapping(address => mapping(address => uint256)) pendingUndelegateTime; // delegator => validator => minTime
    mapping(address => uint256) undelegated; // delegator => totalUndelegated
    mapping(address => mapping(address => mapping(address => uint256))) pendingRedelegateTime; // delegator => srcValidator => dstValidator => minTime

    mapping(uint256 => bytes32) packageQueue; // index => package's hash
    mapping(address => uint256) delegateInFly; // delegator => delegate request in fly
    mapping(address => uint256) undelegateInFly; // delegator => undelegate request in fly
    mapping(address => uint256) redelegateInFly; // delegator => redelegate request in fly

    uint256 internal leftIndex;
    uint256 internal rightIndex;
    uint8 internal locked;

    uint256 public transferGas; // this param is newly added after the hardfork on testnet. It need to be initialed by governed

    modifier noReentrant() {
        require(locked != 2, "No re-entrancy");
        locked = 2;
        _;
        locked = 1;
    }

    modifier tenDecimalPrecision(uint256 amount) {
        require(msg.value % TEN_DECIMALS == 0 && amount % TEN_DECIMALS == 0, "precision loss in conversion");
        _;
    }

    modifier initParams() {
        if (!alreadyInit) {
            relayerFee = INIT_RELAYER_FEE;
            bSCRelayerFee = INIT_BSC_RELAYER_FEE;
            minDelegation = INIT_MIN_DELEGATION;
            transferGas = INIT_TRANSFER_GAS;
            alreadyInit = true;
        }
        _;
    }

    /*----------------- Events -----------------*/
    event delegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 relayerFee);
    event undelegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 relayerFee);
    event redelegateSubmitted(
        address indexed delegator,
        address indexed validatorSrc,
        address indexed validatorDst,
        uint256 amount,
        uint256 relayerFee
    );
    event rewardReceived(address indexed delegator, uint256 amount);
    event rewardClaimed(address indexed delegator, uint256 amount);
    event undelegatedReceived(address indexed delegator, address indexed validator, uint256 amount);
    event undelegatedClaimed(address indexed delegator, uint256 amount);
    event delegateSuccess(address indexed delegator, address indexed validator, uint256 amount);
    event undelegateSuccess(address indexed delegator, address indexed validator, uint256 amount);
    event redelegateSuccess(address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount);
    event delegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
    event undelegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
    event redelegateFailed(
        address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount, uint8 errCode
    );
    event paramChange(string key, bytes value);
    event failedSynPackage(uint8 indexed eventType, uint256 errCode);
    event crashResponse(uint8 indexed eventType);

    receive() external payable { }

    /*----------------- Implement cross chain app -----------------*/
    function handleSynPackage(
        uint8,
        bytes calldata msgBytes
    ) external override onlyCrossChainContract initParams returns (bytes memory) {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        uint8 eventType = uint8(iter.next().toUint());
        uint32 resCode;
        bytes memory ackPackage;
        if (eventType == EVENT_DISTRIBUTE_REWARD) {
            (resCode, ackPackage) = _handleDistributeRewardSynPackage(iter);
        } else if (eventType == EVENT_DISTRIBUTE_UNDELEGATED) {
            (resCode, ackPackage) = _handleDistributeUndelegatedSynPackage(iter);
        } else {
            revert("unknown event type");
        }

        if (resCode != CODE_OK) {
            emit failedSynPackage(eventType, resCode);
        }
        return ackPackage;
    }

    function handleAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract initParams {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        uint8 status;
        uint8 errCode;
        bytes memory packBytes;
        bool success;
        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                status = uint8(iter.next().toUint());
            } else if (idx == 1) {
                errCode = uint8(iter.next().toUint());
            } else if (idx == 2) {
                packBytes = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        require(_checkPackHash(packBytes), "wrong pack hash");
        iter = packBytes.toRLPItem().iterator();
        uint8 eventType = uint8(iter.next().toUint());
        RLPDecode.Iterator memory paramIter;
        if (iter.hasNext()) {
            paramIter = iter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("empty ack package");
        }
        if (eventType == EVENT_DELEGATE) {
            _handleDelegateAckPackage(paramIter, status, errCode);
        } else if (eventType == EVENT_UNDELEGATE) {
            _handleUndelegateAckPackage(paramIter, status, errCode);
        } else if (eventType == EVENT_REDELEGATE) {
            _handleRedelegateAckPackage(paramIter, status, errCode);
        } else {
            revert("unknown event type");
        }
    }

    function handleFailAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract initParams {
        require(_checkPackHash(msgBytes), "wrong pack hash");
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        uint8 eventType = uint8(iter.next().toUint());
        RLPDecode.Iterator memory paramIter;
        if (iter.hasNext()) {
            paramIter = iter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("empty fail ack package");
        }
        if (eventType == EVENT_DELEGATE) {
            _handleDelegateFailAckPackage(paramIter);
        } else if (eventType == EVENT_UNDELEGATE) {
            _handleUndelegateFailAckPackage(paramIter);
        } else if (eventType == EVENT_REDELEGATE) {
            _handleRedelegateFailAckPackage(paramIter);
        } else {
            revert("unknown event type");
        }
        return;
    }

    /*----------------- External functions -----------------*/
    /**
     * @dev Deprecated after fusion
     */
    function delegate(address, uint256) external payable override {
        revert("not supported");
    }

    /**
     * @dev Undelegate BNB from BC to BSC
     *
     * @param validator BC validator encoded address the user delegated
     * @param amount BNB amount the user undelegates
     */
    function undelegate(
        address validator,
        uint256 amount
    ) external payable override noReentrant tenDecimalPrecision(amount) initParams {
        require(msg.value >= relayerFee, "not enough relay fee");
        if (amount < minDelegation) {
            require(amount == delegatedOfValidator[msg.sender][validator], "invalid amount");
            require(amount > bSCRelayerFee, "not enough funds");
        }
        require(block.timestamp >= pendingUndelegateTime[msg.sender][validator], "pending undelegation exist");
        uint256 remainBalance = delegatedOfValidator[msg.sender][validator].sub(amount, "not enough funds");
        if (remainBalance != 0) {
            require(remainBalance > bSCRelayerFee, "insufficient balance after undelegate");
        }

        uint256 convertedAmount = amount.div(TEN_DECIMALS); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
        uint256 _relayerFee = msg.value;
        uint256 oracleRelayerFee = _relayerFee.sub(bSCRelayerFee);

        bytes[] memory elements = new bytes[](3);
        elements[0] = msg.sender.encodeAddress();
        elements[1] = validator.encodeAddress();
        elements[2] = convertedAmount.encodeUint();
        bytes memory msgBytes = _RLPEncode(EVENT_UNDELEGATE, elements.encodeList());
        packageQueue[rightIndex] = keccak256(msgBytes);
        ++rightIndex;
        undelegateInFly[msg.sender] += 1;

        pendingUndelegateTime[msg.sender][validator] = block.timestamp.add(LOCK_TIME);

        ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(
            CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee.div(TEN_DECIMALS)
        );
        payable(TOKEN_HUB_ADDR).transfer(oracleRelayerFee);
        payable(SYSTEM_REWARD_ADDR).transfer(bSCRelayerFee);

        emit undelegateSubmitted(msg.sender, validator, amount, oracleRelayerFee);
    }

    /**
     * @dev Deprecated after fusion
     */
    function redelegate(address, address, uint256) external payable override {
        revert("not supported");
    }

    /**
     * @dev claim delegated reward from BC staking
     *
     */
    function claimReward() external override noReentrant returns (uint256 amount) {
        amount = distributedReward[msg.sender];
        require(amount > 0, "no pending reward");

        distributedReward[msg.sender] = 0;
        (bool success,) = msg.sender.call{ gas: transferGas, value: amount }("");
        require(success, "transfer failed");
        emit rewardClaimed(msg.sender, amount);
    }

    /**
     * @dev claim undelegated BNB from BC staking
     *
     */
    function claimUndelegated() external override noReentrant returns (uint256 amount) {
        amount = undelegated[msg.sender];
        require(amount > 0, "no undelegated funds");

        undelegated[msg.sender] = 0;
        (bool success,) = msg.sender.call{ gas: transferGas, value: amount }("");
        require(success, "transfer failed");
        emit undelegatedClaimed(msg.sender, amount);
    }

    function getDelegated(address delegator, address validator) external view override returns (uint256) {
        return delegatedOfValidator[delegator][validator];
    }

    function getTotalDelegated(address delegator) external view override returns (uint256) {
        return delegated[delegator];
    }

    function getDistributedReward(address delegator) external view override returns (uint256) {
        return distributedReward[delegator];
    }

    function getPendingRedelegateTime(
        address delegator,
        address valSrc,
        address valDst
    ) external view override returns (uint256) {
        return pendingRedelegateTime[delegator][valSrc][valDst];
    }

    function getUndelegated(address delegator) external view override returns (uint256) {
        return undelegated[delegator];
    }

    function getPendingUndelegateTime(address delegator, address validator) external view override returns (uint256) {
        return pendingUndelegateTime[delegator][validator];
    }

    function getRelayerFee() external view override returns (uint256) {
        return relayerFee;
    }

    function getMinDelegation() external view override returns (uint256) {
        return minDelegation;
    }

    function getRequestInFly(address delegator) external view override returns (uint256[3] memory) {
        uint256[3] memory request;
        request[0] = delegateInFly[delegator];
        request[1] = undelegateInFly[delegator];
        request[2] = redelegateInFly[delegator];
        return request;
    }

    /*----------------- Internal functions -----------------*/
    function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns (bytes memory output) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = eventType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        output = elements.encodeList();
    }

    function _encodeRefundPackage(
        uint8 eventType,
        address recipient,
        uint256 amount,
        uint32 errorCode
    ) internal pure returns (uint32, bytes memory) {
        amount = amount.div(TEN_DECIMALS);
        bytes[] memory elements = new bytes[](4);
        elements[0] = eventType.encodeUint();
        elements[1] = recipient.encodeAddress();
        elements[2] = amount.encodeUint();
        elements[3] = errorCode.encodeUint();
        bytes memory packageBytes = elements.encodeList();
        return (errorCode, packageBytes);
    }

    function _checkPackHash(bytes memory packBytes) internal returns (bool) {
        bytes32 revHash = keccak256(packBytes);
        bytes32 expHash = packageQueue[leftIndex];
        if (revHash != expHash) {
            return false;
        }
        delete packageQueue[leftIndex];
        ++leftIndex;
        return true;
    }

    /*----------------- Param update -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        if (Memory.compareStrings(key, "relayerFee")) {
            require(value.length == 32, "length of relayerFee mismatch");
            uint256 newRelayerFee = BytesToTypes.bytesToUint256(32, value);
            require(newRelayerFee < minDelegation, "the relayerFee must be less than minDelegation");
            require(newRelayerFee > bSCRelayerFee, "the relayerFee must be more than BSCRelayerFee");
            require(newRelayerFee % TEN_DECIMALS == 0, "the relayerFee mod ten decimals must be zero");
            relayerFee = newRelayerFee;
        } else if (Memory.compareStrings(key, "bSCRelayerFee")) {
            require(value.length == 32, "length of bSCRelayerFee mismatch");
            uint256 newBSCRelayerFee = BytesToTypes.bytesToUint256(32, value);
            require(newBSCRelayerFee != 0, "the BSCRelayerFee must not be zero");
            require(newBSCRelayerFee < relayerFee, "the BSCRelayerFee must be less than relayerFee");
            require(newBSCRelayerFee % TEN_DECIMALS == 0, "the BSCRelayerFee mod ten decimals must be zero");
            bSCRelayerFee = newBSCRelayerFee;
        } else if (Memory.compareStrings(key, "minDelegation")) {
            require(value.length == 32, "length of minDelegation mismatch");
            uint256 newMinDelegation = BytesToTypes.bytesToUint256(32, value);
            require(newMinDelegation > relayerFee, "the minDelegation must be greater than relayerFee");
            minDelegation = newMinDelegation;
        } else if (Memory.compareStrings(key, "transferGas")) {
            require(value.length == 32, "length of transferGas mismatch");
            uint256 newTransferGas = BytesToTypes.bytesToUint256(32, value);
            require(newTransferGas > 0, "the transferGas cannot be zero");
            transferGas = newTransferGas;
        } else {
            revert("unknown param");
        }
        emit paramChange(key, value);
    }

    /*----------------- Handle cross-chain package -----------------*/
    function _handleDelegateAckPackage(RLPDecode.Iterator memory paramIter, uint8 status, uint8 errCode) internal {
        bool success;
        uint256 idx;
        address delegator;
        address validator;
        uint256 bcAmount;
        while (paramIter.hasNext()) {
            if (idx == 0) {
                delegator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                validator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                bcAmount = uint256(paramIter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 amount = bcAmount.mul(TEN_DECIMALS);
        delegateInFly[delegator] -= 1;
        if (status == CODE_SUCCESS) {
            require(errCode == 0, "wrong status");
            delegated[delegator] = delegated[delegator].add(amount);
            delegatedOfValidator[delegator][validator] = delegatedOfValidator[delegator][validator].add(amount);

            emit delegateSuccess(delegator, validator, amount);
        } else if (status == CODE_FAILED) {
            undelegated[delegator] = undelegated[delegator].add(amount);
            require(ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(amount), "withdraw bnb failed");

            emit delegateFailed(delegator, validator, amount, errCode);
        } else {
            revert("wrong status");
        }
    }

    function _handleDelegateFailAckPackage(RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;
        address delegator;
        address validator;
        uint256 bcAmount;
        while (paramIter.hasNext()) {
            if (idx == 0) {
                delegator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                validator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                bcAmount = uint256(paramIter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 amount = bcAmount.mul(TEN_DECIMALS);
        delegateInFly[delegator] -= 1;
        undelegated[delegator] = undelegated[delegator].add(amount);
        require(ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(amount), "withdraw bnb failed");

        emit crashResponse(EVENT_DELEGATE);
    }

    function _handleUndelegateAckPackage(RLPDecode.Iterator memory paramIter, uint8 status, uint8 errCode) internal {
        bool success;
        uint256 idx;
        address delegator;
        address validator;
        uint256 bcAmount;
        while (paramIter.hasNext()) {
            if (idx == 0) {
                delegator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                validator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                bcAmount = uint256(paramIter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 amount = bcAmount.mul(TEN_DECIMALS);
        undelegateInFly[delegator] -= 1;
        if (status == CODE_SUCCESS) {
            require(errCode == 0, "wrong status");
            delegated[delegator] = delegated[delegator].sub(amount);
            delegatedOfValidator[delegator][validator] = delegatedOfValidator[delegator][validator].sub(amount);
            pendingUndelegateTime[delegator][validator] = block.timestamp.add(LOCK_TIME);

            emit undelegateSuccess(delegator, validator, amount);
        } else if (status == CODE_FAILED) {
            pendingUndelegateTime[delegator][validator] = 0;
            emit undelegateFailed(delegator, validator, amount, errCode);
        } else {
            revert("wrong status");
        }
    }

    function _handleUndelegateFailAckPackage(RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;
        address delegator;
        address validator;
        uint256 bcAmount;
        while (paramIter.hasNext()) {
            if (idx == 0) {
                delegator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                validator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                bcAmount = uint256(paramIter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        undelegateInFly[delegator] -= 1;
        pendingUndelegateTime[delegator][validator] = 0;

        emit crashResponse(EVENT_UNDELEGATE);
    }

    function _handleRedelegateAckPackage(RLPDecode.Iterator memory paramIter, uint8 status, uint8 errCode) internal {
        bool success;
        uint256 idx;
        address delegator;
        address valSrc;
        address valDst;
        uint256 bcAmount;
        while (paramIter.hasNext()) {
            if (idx == 0) {
                delegator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                valSrc = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                valDst = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 3) {
                bcAmount = uint256(paramIter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 amount = bcAmount.mul(TEN_DECIMALS);
        redelegateInFly[delegator] -= 1;
        if (status == CODE_SUCCESS) {
            require(errCode == 0, "wrong status");
            delegatedOfValidator[delegator][valSrc] = delegatedOfValidator[delegator][valSrc].sub(amount);
            delegatedOfValidator[delegator][valDst] = delegatedOfValidator[delegator][valDst].add(amount);
            pendingRedelegateTime[delegator][valSrc][valDst] = block.timestamp.add(LOCK_TIME);
            pendingRedelegateTime[delegator][valDst][valSrc] = block.timestamp.add(LOCK_TIME);

            emit redelegateSuccess(delegator, valSrc, valDst, amount);
        } else if (status == CODE_FAILED) {
            pendingRedelegateTime[delegator][valSrc][valDst] = 0;
            pendingRedelegateTime[delegator][valDst][valSrc] = 0;
            emit redelegateFailed(delegator, valSrc, valDst, amount, errCode);
        } else {
            revert("wrong status");
        }
    }

    function _handleRedelegateFailAckPackage(RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;
        address delegator;
        address valSrc;
        address valDst;
        uint256 bcAmount;
        while (paramIter.hasNext()) {
            if (idx == 0) {
                delegator = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                valSrc = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                valDst = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 3) {
                bcAmount = uint256(paramIter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        redelegateInFly[delegator] -= 1;
        pendingRedelegateTime[delegator][valSrc][valDst] = 0;
        pendingRedelegateTime[delegator][valDst][valSrc] = 0;

        emit crashResponse(EVENT_REDELEGATE);
    }

    function _handleDistributeRewardSynPackage(RLPDecode.Iterator memory iter)
        internal
        returns (uint32, bytes memory)
    {
        bool success;
        uint256 idx;
        address recipient;
        uint256 amount;
        while (iter.hasNext()) {
            if (idx == 0) {
                recipient = address(uint160(iter.next().toAddress()));
            } else if (idx == 1) {
                amount = uint256(iter.next().toUint());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        bool ok = ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(amount);
        if (!ok) {
            return _encodeRefundPackage(EVENT_DISTRIBUTE_REWARD, recipient, amount, ERROR_WITHDRAW_BNB);
        }

        distributedReward[recipient] = distributedReward[recipient].add(amount);

        emit rewardReceived(recipient, amount);
        return (CODE_OK, new bytes(0));
    }

    function _handleDistributeUndelegatedSynPackage(RLPDecode.Iterator memory iter)
        internal
        returns (uint32, bytes memory)
    {
        bool success;
        uint256 idx;
        address recipient;
        address validator;
        uint256 amount;
        bool isAutoUndelegate;
        while (iter.hasNext()) {
            if (idx == 0) {
                recipient = address(uint160(iter.next().toAddress()));
            } else if (idx == 1) {
                validator = address(uint160(iter.next().toAddress()));
            } else if (idx == 2) {
                amount = uint256(iter.next().toUint());
                success = true;
            } else if (idx == 3) {
                isAutoUndelegate = iter.next().toBoolean();
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        bool ok = ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(amount);
        if (!ok) {
            return _encodeRefundPackage(EVENT_DISTRIBUTE_UNDELEGATED, recipient, amount, ERROR_WITHDRAW_BNB);
        }

        pendingUndelegateTime[recipient][validator] = 0;
        undelegated[recipient] = undelegated[recipient].add(amount);

        // this is to address the issue that the contract state will not being updated
        // when the Beacon Chain system undelegate all the funds after second sunset upgrade
        if (isAutoUndelegate) {
            delegated[recipient] = delegated[recipient].sub(amount);
            delegatedOfValidator[recipient][validator] = delegatedOfValidator[recipient][validator].sub(amount);
            emit undelegateSuccess(recipient, validator, amount);
        }

        emit undelegatedReceived(recipient, validator, amount);
        return (CODE_OK, new bytes(0));
    }
}
