pragma solidity 0.6.4;

import "../System.sol";
import "../interface/0.6.x/IApplication.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../interface/0.6.x/IStaking.sol";
import "../lib/0.6.x/SafeMath.sol";

contract Staking is IStaking, System, IParamSubscriber, IApplication {
    using SafeMath for uint256;

    uint256 public constant TEN_DECIMALS = 1e10;

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

    mapping(uint256 => bytes32) packageQueue; // index => package's hash  // @dev deprecated
    mapping(address => uint256) delegateInFly; // delegator => delegate request in fly
    mapping(address => uint256) undelegateInFly; // delegator => undelegate request in fly
    mapping(address => uint256) redelegateInFly; // delegator => redelegate request in fly

    uint256 internal leftIndex;  // @dev deprecated
    uint256 internal rightIndex;  // @dev deprecated
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
    event rewardClaimed(address indexed delegator, uint256 amount);

    event delegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 relayerFee);  // @dev deprecated
    event undelegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 relayerFee);  // @dev deprecated
    event redelegateSubmitted(
        address indexed delegator,
        address indexed validatorSrc,
        address indexed validatorDst,
        uint256 amount,
        uint256 relayerFee
    );  // @dev deprecated
    event rewardReceived(address indexed delegator, uint256 amount);  // @dev deprecated
    event undelegatedReceived(address indexed delegator, address indexed validator, uint256 amount);  // @dev deprecated
    event undelegatedClaimed(address indexed delegator, uint256 amount);
    event delegateSuccess(address indexed delegator, address indexed validator, uint256 amount);  // @dev deprecated
    event undelegateSuccess(address indexed delegator, address indexed validator, uint256 amount);  // @dev deprecated
    event redelegateSuccess(address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount);  // @dev deprecated
    event delegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);  // @dev deprecated
    event undelegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);  // @dev deprecated
    event redelegateFailed(
        address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount, uint8 errCode
    );  // @dev deprecated
    event paramChange(string key, bytes value);  // @dev deprecated
    event failedSynPackage(uint8 indexed eventType, uint256 errCode);  // @dev deprecated
    event crashResponse(uint8 indexed eventType);  // @dev deprecated

    receive() external payable { }

    /*----------------- Implement cross chain app -----------------*/
    function handleSynPackage(
        uint8,
        bytes calldata msgBytes
    ) external override onlyCrossChainContract initParams returns (bytes memory) {
        revert("deprecated");
    }

    function handleAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract initParams {
        revert("deprecated");
    }

    function handleFailAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract initParams {
        revert("deprecated");
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
        revert("deprecated");
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

    /*----------------- Param update -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        revert("deprecated");
    }
}
