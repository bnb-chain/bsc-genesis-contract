// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./System.sol";

interface IGovBNB {
    function mint(address validator, address delegator, uint256 amount) external;
    function burn(address validator, address delegator, uint256 amount) external;
}

interface IBSCValidatorSet {
    struct Validator {
        address consensusAddress;
        address payable feeAddress;
        address BBCFeeAddress;
        uint64 votingPower;
        bool jailed;
        uint256 incoming;
    }
}

interface IStakePool {
    function initialize(address operatorAddress, string memory moniker) external payable;
    function claim(address delegator, uint256 requestNumber) external returns (uint256);
    function totalPooledBNB() external view returns (uint256);
    function getPooledBNBByShares(uint256 shares) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function delegate(address delegator) external payable returns (uint256);
    function undelegate(address delegator, uint256 shares) external returns (uint256);
    function unbond(address delegator, uint256 shares) external returns (uint256);
    function distributeReward(uint64 commissionRate) external payable;
    function slash(uint256 slashBnbAmount) external returns (uint256);
    function getSelfDelegationBNB() external view returns (uint256);
    function balanceOf(address delegator) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract StakeHub is System {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constant -----------------*/
    address public constant INIT_GOV_BNB = address(0xdead01); // TODO
    address public constant INIT_POOL_IMPLEMENTATION = address(0xdead02); // TODO
    uint256 public constant INIT_TRANSFER_GAS_LIMIT = 2300;
    uint256 public constant INIT_MIN_SELF_DELEGATION_BNB = 2000 ether;
    uint256 public constant INIT_MIN_DELEGATION_BNB_CHANGE = 1 ether;
    uint256 public constant INIT_MAX_ELECTED_VALIDATORS = 29;
    uint256 public constant INIT_UNBOND_PERIOD = 7 days;
    uint256 public constant INIT_DOWNTIME_SLASH_AMOUNT = 50 ether;
    uint256 public constant INIT_DOUBLE_SIGN_SLASH_AMOUNT = 10_000 ether;
    uint256 public constant INIT_DOWNTIME_JAIL_TIME = 2 days;
    uint256 public constant INIT_DOUBLE_SIGN_JAIL_TIME = 730 days; // 200 years
    uint256 public constant INIT_MAX_EVIDENCE_AGE = 21 days;

    uint256 public constant BLS_PUBKEY_LENGTH = 48;
    uint256 public constant BLS_SIG_LENGTH = 96;

    address public constant DEAD_ADDRESS = address(0xdead);

    /*----------------- storage -----------------*/
    uint8 private _initialized;
    bool private _stakingPaused;
    address private _proxyAdmin;

    address public govBNB;
    address public poolImplementation;
    uint256 public transferGasLimit;

    // stake params
    uint256 public minSelfDelegationBNB;
    uint256 public minDelegationBNBChange;
    uint256 public maxElectedValidators;
    uint256 public unbondPeriod;

    // slash params
    uint256 public downtimeSlashAmount;
    uint256 public doubleSignSlashAmount;
    uint256 public downtimeJailTime;
    uint256 public doubleSignJailTime;
    uint256 public maxEvidenceAge;

    // validator operator address set
    EnumerableSet.AddressSet private _validatorSet;
    // validator operator address => validator info
    mapping(address => Validator) private _validators;
    // validator vote address => validator operator address
    mapping(bytes => address) private _voteToOperator;
    // validator consensus address => validator operator address
    mapping(address => address) private _consensusToOperator;
    // slash key => slash record
    mapping(bytes32 => SlashRecord) private _slashRecords;

    IBSCValidatorSet.Validator[] private _eligibleValidators;
    bytes[] private _eligibleValidatorVoteAddrs;

    struct Validator {
        address consensusAddress;
        address operatorAddress;
        address poolModule;
        bytes voteAddress;
        Description description;
        Commission commission;
        bool jailed;
        uint256 jailUntil;
        uint256 updateTime;
        uint256[20] __reservedSlots;
    }

    struct Description {
        string moniker;
        string identity;
        string website;
        string details;
    }

    struct Commission {
        uint64 rate; // the commission rate charged to delegators(10000 is 100%)
        uint64 maxRate; // maximum commission rate which validator can ever charge
        uint64 maxChangeRate; // maximum daily increase of the validator commission
    }

    struct SlashRecord {
        uint256 jailUntil;
        uint256 slashAmount;
        uint248 slashHeight;
        SlashType slashType;
    }

    enum SlashType {
        DoubleSign,
        DownTime,
        MaliciousVote
    }

    /*----------------- events -----------------*/
    event ValidatorCreated(
        address indexed consensusAddress, address indexed operatorAddress, address indexed poolModule, bytes voteAddress
    );
    event ConsensusAddressEdited(
        address indexed operatorAddress, address indexed oldAddress, address indexed newAddress
    );
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event DescriptionEdited(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Redelegated(
        address indexed srcValidator,
        address indexed dstValidator,
        address indexed delegator,
        uint256 oldShares,
        uint256 newShares,
        uint256 bnbAmount
    );
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event ValidatorSlashed(
        address indexed operatorAddress,
        uint256 jailUntil,
        uint256 slashAmount,
        uint248 slashHeight,
        SlashType slashType
    );
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event StakingPaused();
    event StakingResumed();
    event paramChange(string key, bytes value);

    /*----------------- modifiers -----------------*/
    modifier onlyInitialized() {
        require(_initialized != 0, "NOT_INITIALIZED");
        _;
    }

    modifier validatorExist(address operatorAddress) {
        require(_validators[operatorAddress].poolModule != address(0), "VALIDATOR_NOT_EXIST");
        _;
    }

    modifier validatorNotJailed(address operatorAddress) {
        require(!_validators[operatorAddress].jailed, "VALIDATOR_JAILED");
        _;
    }

    modifier whenNotPaused() {
        require(!_stakingPaused, "STAKE_STOPPED");
        _;
    }

    modifier onlyZeroGasPrice() {
        require(tx.gasprice == 0, "gasprice is not zero");
        _;
    }

    receive() external payable { }

    /*----------------- init -----------------*/
    function initialize() public onlyCoinbase onlyZeroGasPrice {
        require(_initialized == 0, "ALREADY_INITIALIZED");
        govBNB = INIT_GOV_BNB;
        poolImplementation = INIT_POOL_IMPLEMENTATION;
        transferGasLimit = INIT_TRANSFER_GAS_LIMIT;
        _proxyAdmin = address(new ProxyAdmin());

        minSelfDelegationBNB = INIT_MIN_SELF_DELEGATION_BNB;
        minDelegationBNBChange = INIT_MIN_DELEGATION_BNB_CHANGE;
        maxElectedValidators = INIT_MAX_ELECTED_VALIDATORS;
        unbondPeriod = INIT_UNBOND_PERIOD;
        downtimeSlashAmount = INIT_DOWNTIME_SLASH_AMOUNT;
        doubleSignSlashAmount = INIT_DOUBLE_SIGN_SLASH_AMOUNT;
        downtimeJailTime = INIT_DOWNTIME_JAIL_TIME;
        doubleSignJailTime = INIT_DOUBLE_SIGN_JAIL_TIME;
        maxEvidenceAge = INIT_MAX_EVIDENCE_AGE;

        _initialized = 1;
    }

    /*----------------- external functions -----------------*/
    function createValidator(
        address consensusAddress,
        bytes calldata voteAddress,
        bytes calldata blsProof,
        Commission calldata commission,
        Description calldata description
    ) external payable onlyInitialized {
        // basic check
        uint256 delegation = msg.value;
        require(delegation >= minSelfDelegationBNB, "NOT_ENOUGH_SELF_DELEGATION");
        address operatorAddress = msg.sender;
        require(_validators[operatorAddress].poolModule == address(0), "VALIDATOR_EXISTED");
        require(_consensusToOperator[consensusAddress] == address(0), "DUPLICATE_CONSENSUS_ADDRESS");
        require(_checkMoniker(description.moniker), "INVALID_MONIKER");
        require(commission.rate <= commission.maxRate, "INVALID_COMMISSION_RATE");
        require(commission.maxChangeRate <= commission.maxRate, "INVALID_MAX_CHANGE_RATE");
        require(_voteToOperator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");

        // deploy stake pool
        address poolModule = _deployStakePool(operatorAddress, description.moniker);

        _validatorSet.add(operatorAddress);
        Validator storage valInfo = _validators[operatorAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = operatorAddress;
        valInfo.poolModule = poolModule;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;
        _consensusToOperator[consensusAddress] = operatorAddress;
        _voteToOperator[voteAddress] = operatorAddress;

        emit ValidatorCreated(consensusAddress, operatorAddress, poolModule, voteAddress);
    }

    function editConsensusAddress(address newConsensusAddress) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(newConsensusAddress != address(0), "INVALID_CONSENSUS_ADDRESS");
        require(_consensusToOperator[newConsensusAddress] == address(0), "DUPLICATE_CONSENSUS_ADDRESS");

        address oldConsensusAddress = valInfo.consensusAddress;
        delete _consensusToOperator[oldConsensusAddress];
        _consensusToOperator[newConsensusAddress] = operatorAddress;

        valInfo.consensusAddress = newConsensusAddress;
        valInfo.updateTime = block.timestamp;

        emit ConsensusAddressEdited(operatorAddress, oldConsensusAddress, newConsensusAddress);
    }

    function editCommissionRate(uint64 commissionRate) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(commissionRate <= valInfo.commission.maxRate, "INVALID_COMMISSION_RATE");

        uint256 changeRate = commissionRate >= valInfo.commission.rate
            ? commissionRate - valInfo.commission.rate
            : valInfo.commission.rate - commissionRate;
        require(changeRate <= valInfo.commission.maxChangeRate, "INVALID_COMMISSION_RATE");

        valInfo.commission.rate = commissionRate;
        valInfo.updateTime = block.timestamp;

        emit CommissionRateEdited(operatorAddress, commissionRate);
    }

    function editDescription(Description calldata description) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(_checkMoniker(description.moniker), "INVALID_MONIKER");

        valInfo.description = description;
        valInfo.updateTime = block.timestamp;

        emit DescriptionEdited(operatorAddress);
    }

    function editVoteAddress(
        bytes calldata newVoteAddress,
        bytes calldata blsProof
    ) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(_voteToOperator[newVoteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(_checkVoteAddress(newVoteAddress, blsProof), "INVALID_VOTE_ADDRESS");

        bytes memory oldVoteAddress = valInfo.voteAddress;
        delete _voteToOperator[oldVoteAddress];
        _voteToOperator[newVoteAddress] = operatorAddress;

        valInfo.voteAddress = newVoteAddress;
        valInfo.updateTime = block.timestamp;

        emit VoteAddressEdited(operatorAddress, newVoteAddress);
    }

    function unjail(address operatorAddress) public onlyInitialized validatorExist(operatorAddress) {
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.jailed, "NOT_JAILED");

        address pool = valInfo.poolModule;
        require(IStakePool(pool).getSelfDelegationBNB() >= minSelfDelegationBNB, "NOT_ENOUGH_SELF_DELEGATION");
        require(valInfo.jailUntil <= block.timestamp, "STILL_JAILED");

        valInfo.jailed = false;
        emit ValidatorUnjailed(operatorAddress);
    }

    function delegate(address operatorAddress)
        external
        payable
        onlyInitialized
        validatorExist(operatorAddress)
        whenNotPaused
    {
        uint256 bnbAmount = msg.value;
        require(bnbAmount >= minDelegationBNBChange, "INVALID_DELEGATION_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        address pool = valInfo.poolModule;
        require(_checkPoolImplementation(pool), "IMPLEMENTATION_NOT_MATCH");

        if (valInfo.jailed || IStakePool(pool).getSelfDelegationBNB() < minSelfDelegationBNB) {
            // only self delegation
            require(delegator == operatorAddress, "ONLY_SELF_DELEGATION");
        }

        uint256 shares = IStakePool(pool).delegate{ value: bnbAmount }(delegator);
        emit Delegated(operatorAddress, delegator, shares, bnbAmount);

        IGovBNB(govBNB).mint(operatorAddress, delegator, bnbAmount);
    }

    function undelegate(
        address operatorAddress,
        uint256 shares
    ) public onlyInitialized validatorExist(operatorAddress) whenNotPaused {
        require(shares > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        require(
            IStakePool(valInfo.poolModule).getPooledBNBByShares(shares) >= minDelegationBNBChange,
            "INVALID_UNDELEGATION_AMOUNT"
        );

        uint256 bnbAmount = IStakePool(valInfo.poolModule).undelegate(delegator, shares);
        emit Undelegated(operatorAddress, delegator, shares, bnbAmount);

        if (
            delegator == operatorAddress && IStakePool(valInfo.poolModule).getSelfDelegationBNB() < minSelfDelegationBNB
        ) {
            _validators[operatorAddress].jailed = true;
            _removeEligibleValidator(valInfo.consensusAddress);
            emit ValidatorJailed(operatorAddress);
        }

        IGovBNB(govBNB).burn(operatorAddress, delegator, bnbAmount);
    }

    function redelegate(
        address srcValidator,
        address dstValidator,
        uint256 shares
    )
        public
        onlyInitialized
        validatorExist(srcValidator)
        validatorExist(dstValidator)
        validatorNotJailed(dstValidator)
        whenNotPaused
    {
        require(shares > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory srcValInfo = _validators[srcValidator];
        Validator memory dstValInfo = _validators[dstValidator];
        require(
            IStakePool(srcValInfo.poolModule).getPooledBNBByShares(shares) >= minDelegationBNBChange,
            "INVALID_REDELEGATION_AMOUNT"
        );

        uint256 bnbAmount = IStakePool(srcValInfo.poolModule).unbond(delegator, shares);
        uint256 newShares = IStakePool(dstValInfo.poolModule).delegate{ value: bnbAmount }(delegator);
        emit Redelegated(srcValidator, dstValidator, delegator, shares, newShares, bnbAmount);

        IGovBNB(govBNB).burn(srcValidator, delegator, bnbAmount);
        IGovBNB(govBNB).mint(dstValidator, delegator, bnbAmount);
    }

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     */
    function claim(
        address operatorAddress,
        uint256 requestNumber
    ) external onlyInitialized validatorExist(operatorAddress) {
        uint256 bnbAmount = IStakePool(_validators[operatorAddress].poolModule).claim(msg.sender, requestNumber);
        emit Claimed(operatorAddress, msg.sender, bnbAmount);
    }

    function upgradePoolImplementation() external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        address poolProxy = valInfo.poolModule;
        require(!_checkPoolImplementation(poolProxy), "NO_NEED_TO_UPGRADE");
        ProxyAdmin(_proxyAdmin).upgrade(ITransparentUpgradeableProxy(poolProxy), poolImplementation);
    }

    /*----------------- system functions -----------------*/
    function distributeReward(address consensusAddress) external payable onlyInitialized onlyValidatorContract {
        address operatorAddress = _consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator memory valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        IStakePool(valInfo.poolModule).distributeReward{ value: msg.value }(valInfo.commission.rate);
        emit RewardDistributed(operatorAddress, msg.value);
    }

    /**
     * @dev Get new eligible validators from consensus engine
     */
    function updateEligibleValidators(
        address[] calldata validators,
        uint64[] calldata votingPowers
    ) external onlyInitialized onlyCoinbase onlyZeroGasPrice {
        uint256 newLength = validators.length;
        if (newLength == 0) {
            return;
        }
        uint256 oldLength = _eligibleValidators.length;
        if (oldLength > newLength) {
            for (uint256 i = newLength; i < oldLength; ++i) {
                _eligibleValidators.pop();
                _eligibleValidatorVoteAddrs.pop();
            }
        }

        uint256 j;
        for (uint256 i; i < newLength; ++i) {
            address consensusAddress = validators[i];
            address operatorAddress = _consensusToOperator[consensusAddress];
            if (operatorAddress == address(0)) {
                continue;
            }

            if (j >= oldLength) {
                _eligibleValidators.push(
                    IBSCValidatorSet.Validator({
                        consensusAddress: consensusAddress,
                        feeAddress: payable(0),
                        BBCFeeAddress: address(0),
                        votingPower: votingPowers[i],
                        jailed: false,
                        incoming: 0
                    })
                );
                _eligibleValidatorVoteAddrs.push(_validators[operatorAddress].voteAddress);
            } else {
                IBSCValidatorSet.Validator storage eVal = _eligibleValidators[j];
                eVal.consensusAddress = consensusAddress;
                eVal.votingPower = votingPowers[i];
                _eligibleValidatorVoteAddrs[j] = _validators[operatorAddress].voteAddress;
            }
            ++j;
        }
    }

    function downtimeSlash(address consensusAddress, uint256 height) external onlyInitialized onlySlash {
        address operatorAddress = _consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.DownTime);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(downtimeSlashAmount);
        valInfo.jailed = true;
        _removeEligibleValidator(consensusAddress);
        emit ValidatorJailed(operatorAddress);

        // record
        record.jailUntil = block.timestamp + downtimeJailTime;
        record.slashAmount = slashAmount;
        record.slashHeight = uint248(height);
        record.slashType = SlashType.DownTime;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(
            operatorAddress, record.jailUntil, record.slashAmount, record.slashHeight, SlashType.DownTime
        );
    }

    function maliciousVoteSlash(bytes calldata _voteAddr, uint256 height) external onlyInitialized onlySlash {
        address operatorAddress = _voteToOperator[_voteAddr];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.MaliciousVote);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;
        _removeEligibleValidator(valInfo.consensusAddress);
        emit ValidatorJailed(operatorAddress);

        // record
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashAmount = slashAmount;
        record.slashHeight = uint248(height);
        record.slashType = SlashType.MaliciousVote;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(
            operatorAddress, record.jailUntil, record.slashAmount, record.slashHeight, SlashType.MaliciousVote
        );
    }

    function doubleSignSlash(
        address consensusAddress,
        uint256 height,
        uint256 evidenceTime
    ) external onlyInitialized onlySlash {
        address operatorAddress = _consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        require(evidenceTime + maxEvidenceAge >= block.timestamp, "EVIDENCE_TOO_OLD");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.DoubleSign);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;
        _removeEligibleValidator(consensusAddress);
        emit ValidatorJailed(operatorAddress);

        // record
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashAmount = slashAmount;
        record.slashHeight = uint248(height);
        record.slashType = SlashType.MaliciousVote;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(
            operatorAddress, record.jailUntil, record.slashAmount, record.slashHeight, SlashType.DoubleSign
        );
    }

    /*----------------- gov -----------------*/
    function pauseStaking() external onlyInitialized onlyGov {
        _stakingPaused = true;
        emit StakingPaused();
    }

    function resumeStaking() external onlyInitialized onlyGov {
        _stakingPaused = false;
        emit StakingResumed();
    }

    function updateParam(string calldata key, bytes calldata value) external onlyInitialized onlyGov {
        if (_compareStrings(key, "poolImplementation")) {
            require(value.length == 20, "length of poolImplementation mismatch");
            address newImpl = _bytesToAddress(20, value);
            require(newImpl != address(0), "wrong pool implementation");
            poolImplementation = newImpl;
        } else if (_compareStrings(key, "transferGasLimit")) {
            require(value.length == 32, "length of transferGasLimit mismatch");
            uint256 newTransferGasLimit = _bytesToUint256(32, value);
            require(newTransferGasLimit >= 2300, "the transferGasLimit is out of range");
            transferGasLimit = newTransferGasLimit;
        } else if (_compareStrings(key, "minSelfDelegationBNB")) {
            require(value.length == 32, "length of minSelfDelegationBNB mismatch");
            uint256 newMinSelfDelegationBNB = _bytesToUint256(32, value);
            require(newMinSelfDelegationBNB >= 1000 ether, "the minSelfDelegationBNB is out of range");
            newMinSelfDelegationBNB = newMinSelfDelegationBNB;
        } else if (_compareStrings(key, "minDelegationBNBChange")) {
            require(value.length == 32, "length of minDelegationBNBChange mismatch");
            uint256 newMinDelegationBNBChange = _bytesToUint256(32, value);
            require(newMinDelegationBNBChange >= 1 ether, "the minDelegationBNBChange is out of range");
            minDelegationBNBChange = newMinDelegationBNBChange;
        } else if (_compareStrings(key, "maxElectedValidators")) {
            require(value.length == 32, "length of maxElectedValidators mismatch");
            uint256 newMaxElectedValidators = _bytesToUint256(32, value);
            require(newMaxElectedValidators >= 1, "the maxElectedValidators is out of range");
            maxElectedValidators = newMaxElectedValidators;
        } else if (_compareStrings(key, "unbondPeriod")) {
            require(value.length == 32, "length of unbondPeriod mismatch");
            uint256 newUnbondPeriod = _bytesToUint256(32, value);
            require(newUnbondPeriod >= 3 days, "the unbondPeriod is out of range");
            unbondPeriod = newUnbondPeriod;
        } else if (_compareStrings(key, "downtimeSlashAmount")) {
            require(value.length == 32, "length of downtimeSlashAmount mismatch");
            uint256 newDowntimeSlashAmount = _bytesToUint256(32, value);
            require(
                newDowntimeSlashAmount >= 5 ether && newDowntimeSlashAmount < doubleSignSlashAmount,
                "the downtimeSlashAmount is out of range"
            );
            downtimeSlashAmount = newDowntimeSlashAmount;
        } else if (_compareStrings(key, "doubleSignSlashAmount")) {
            require(value.length == 32, "length of doubleSignSlashAmount mismatch");
            uint256 newDoubleSignSlashAmount = _bytesToUint256(32, value);
            require(
                newDoubleSignSlashAmount >= 1000 ether && newDoubleSignSlashAmount > downtimeSlashAmount,
                "the doubleSignSlashAmount is out of range"
            );
            doubleSignSlashAmount = newDoubleSignSlashAmount;
        } else if (_compareStrings(key, "downtimeJailTime")) {
            require(value.length == 32, "length of downtimeJailTime mismatch");
            uint256 newDowntimeJailTime = _bytesToUint256(32, value);
            require(
                newDowntimeJailTime >= 2 days && newDowntimeJailTime < doubleSignJailTime,
                "the downtimeJailTime is out of range"
            );
            downtimeJailTime = newDowntimeJailTime;
        } else if (_compareStrings(key, "doubleSignJailTime")) {
            require(value.length == 32, "length of doubleSignJailTime mismatch");
            uint256 newDoubleSignJailTime = _bytesToUint256(32, value);
            require(
                newDoubleSignJailTime >= 100 days && newDoubleSignJailTime > downtimeJailTime,
                "the doubleSignJailTime is out of range"
            );
            doubleSignJailTime = newDoubleSignJailTime;
        } else if (_compareStrings(key, "maxEvidenceAge")) {
            require(value.length == 32, "length of maxEvidenceAge mismatch");
            uint256 newMaxEvidenceAge = _bytesToUint256(32, value);
            require(newMaxEvidenceAge >= 7 days, "the maxEvidenceAge is out of range");
            maxEvidenceAge = newMaxEvidenceAge;
        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    /*----------------- view functions -----------------*/
    function isPaused() external view returns (bool) {
        return _stakingPaused;
    }

    function getEligibleValidators() external view returns (IBSCValidatorSet.Validator[] memory, bytes[] memory) {
        return (_eligibleValidators, _eligibleValidatorVoteAddrs);
    }

    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        returns (address consensusAddress, address poolModule, bytes memory voteAddress, bool jailed, uint256 jailUntil)
    {
        Validator memory valInfo = _validators[operatorAddress];
        consensusAddress = valInfo.consensusAddress;
        poolModule = valInfo.poolModule;
        voteAddress = valInfo.voteAddress;
        jailed = valInfo.jailed;
        jailUntil = valInfo.jailUntil;
    }

    function getValidatorDescription(address operatorAddress) external view returns (Description memory) {
        return _validators[operatorAddress].description;
    }

    function getValidatorCommission(address operatorAddress) external view returns (Commission memory) {
        return _validators[operatorAddress].commission;
    }

    function getValidatorWithVotingPower(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory consensusAddrs, uint256[] memory votingPowers, uint256 totalLength) {
        limit = limit > 100 ? 100 : limit;
        totalLength = _validatorSet.length();
        if (offset >= totalLength) {
            return (consensusAddrs, votingPowers, totalLength);
        }

        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        consensusAddrs = new address[](count);
        votingPowers = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            address operatorAddress = _validatorSet.at(offset + i);
            Validator memory valInfo = _validators[operatorAddress];
            consensusAddrs[i] = valInfo.consensusAddress;
            address pool = valInfo.poolModule;
            votingPowers[i] = IStakePool(pool).totalPooledBNB();
        }
    }

    function getOperatorAddressByVoteAddress(bytes calldata voteAddress) external view returns (address) {
        return _voteToOperator[voteAddress];
    }

    function getOperatorAddressByConsensusAddress(address consensusAddress) external view returns (address) {
        return _consensusToOperator[consensusAddress];
    }

    function getSlashRecord(
        address operatorAddress,
        uint256 height,
        SlashType slashType
    ) external view returns (uint256 slashAmount, uint256 slashHeight, uint256 jailUntil) {
        bytes32 slashKey = _getSlashKey(operatorAddress, height, slashType);
        SlashRecord memory record = _slashRecords[slashKey];
        slashAmount = record.slashAmount;
        slashHeight = record.slashHeight;
        jailUntil = record.jailUntil;
    }

    /*----------------- internal functions -----------------*/
    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _bytesToUint256(uint256 _offset, bytes memory _input) internal pure returns (uint256 _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }

    function _bytesToAddress(uint256 _offset, bytes memory _input) internal pure returns (address _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }

    function _getSlashKey(
        address operatorAddress,
        uint256 height,
        SlashType slashType
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(operatorAddress, height, slashType));
    }

    function _checkMoniker(string memory moniker) internal pure returns (bool) {
        bytes memory bz = bytes(moniker);

        // 1. moniker length should be between 1 and 9
        if (bz.length == 0 || bz.length > 9) {
            return false;
        }

        // 2. first character should be uppercase
        if (uint8(bz[0]) < 65 || uint8(bz[0]) > 90) {
            return false;
        }

        // 3. only alphanumeric characters are allowed
        for (uint256 i = 1; i < bz.length; ++i) {
            // Check if the ASCII value of the character falls outside the range of alphanumeric characters
            if (
                (uint8(bz[i]) < 48 || uint8(bz[i]) > 57) && (uint8(bz[i]) < 65 || uint8(bz[i]) > 90)
                    && (uint8(bz[i]) < 97 || uint8(bz[i]) > 122)
            ) {
                // Character is a special character
                return false;
            }
        }

        // No special characters found
        return true;
    }

    function _checkVoteAddress(bytes calldata voteAddress, bytes calldata blsProof) internal view returns (bool) {
        require(voteAddress.length == BLS_PUBKEY_LENGTH, "INVALID_VOTE_ADDRESS");
        require(blsProof.length == BLS_SIG_LENGTH, "INVALID_BLS_PROOF");

        // get msg hash
        bytes32 msgHash = keccak256(abi.encodePacked(voteAddress, bscChainID));
        bytes memory msgBz = new bytes(32);
        assembly {
            mstore(add(msgBz, 32), msgHash)
        }

        // call the precompiled contract to verify the BLS signature
        // the precompiled contract's address is 0x66
        bytes memory input = bytes.concat(msgBz, blsProof, voteAddress); // length: 32 + 96 + 48 = 176
        bytes memory output = new bytes(1);
        assembly {
            let len := mload(input)
            if iszero(staticcall(not(0), 0x66, add(input, 0x20), len, add(output, 0x20), 0x01)) { revert(0, 0) }
        }
        uint8 result = uint8(output[0]);
        if (result != uint8(1)) {
            return false;
        }
        return true;
    }

    function _deployStakePool(address operatorAddress, string memory moniker) internal returns (address) {
        address poolProxy = address(new TransparentUpgradeableProxy(poolImplementation, _proxyAdmin, ""));
        IStakePool(poolProxy).initialize{ value: msg.value }(operatorAddress, moniker);

        return poolProxy;
    }

    function _checkPoolImplementation(address poolProxy) internal view returns (bool) {
        return ITransparentUpgradeableProxy(poolProxy).implementation() == poolImplementation;
    }

    function _removeEligibleValidator(address consensusAddress) internal {
        uint256 length = _eligibleValidators.length;
        for (uint256 i; i < length; ++i) {
            if (_eligibleValidators[i].consensusAddress == consensusAddress) {
                for (uint256 j = i + 1; j < length; ++j) {
                    _eligibleValidators[j - 1] = _eligibleValidators[j];
                    _eligibleValidatorVoteAddrs[j - 1] = _eligibleValidatorVoteAddrs[j];
                }
                _eligibleValidators.pop();
                _eligibleValidatorVoteAddrs.pop();
                break;
            }
        }
    }
}
