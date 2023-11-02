// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./System.sol";
import "./lib/Utils.sol";

interface IGovBNB {
    function sync(address[] calldata validatorPools, address account) external;
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

    function jailValidator(address consensusAddress) external;
    function updateValidatorSetV2(Validator[] calldata validators, bytes[] calldata voteAddrs) external;
}

interface IStakeCredit {
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
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constant -----------------*/
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

    uint256 public numOfJailed;

    IBSCValidatorSet.Validator[] private _eligibleValidators;
    bytes[] private _eligibleValidatorVoteAddrs;

    struct Validator {
        address consensusAddress;
        address operatorAddress;
        address creditContract;
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
        address indexed consensusAddress,
        address indexed operatorAddress,
        address indexed creditContract,
        bytes voteAddress
    );
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
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
    event RewardDistributeFailed(address indexed operatorAddress, bytes failReason);
    event ValidatorSlashed(
        address indexed operatorAddress,
        uint256 jailUntil,
        uint256 slashAmount,
        uint248 slashHeight,
        SlashType slashType
    );
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorEmptyJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event StakingPaused();
    event StakingResumed();

    /*----------------- modifiers -----------------*/
    modifier validatorExist(address operatorAddress) {
        require(_validators[operatorAddress].creditContract != address(0), "VALIDATOR_NOT_EXIST");
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

    receive() external payable { }

    /*----------------- init -----------------*/
    function initialize() public onlyCoinbase onlyZeroGasPrice {
        require(_initialized == 0, "ALREADY_INITIALIZED");

        transferGasLimit = 2300;

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
    ) external payable whenNotPaused {
        // basic check
        address operatorAddress = msg.sender;
        require(_validators[operatorAddress].creditContract == address(0), "VALIDATOR_EXISTED");
        require(_consensusToOperator[consensusAddress] == address(0), "DUPLICATE_CONSENSUS_ADDRESS");
        require(_voteToOperator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");

        uint256 delegation = msg.value;
        require(delegation >= minSelfDelegationBNB, "NOT_ENOUGH_SELF_DELEGATION");

        require(commission.rate <= commission.maxRate, "INVALID_COMMISSION_RATE");
        require(commission.maxChangeRate <= commission.maxRate, "INVALID_MAX_CHANGE_RATE");
        require(_checkMoniker(description.moniker), "INVALID_MONIKER");
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");

        // deploy stake pool
        address creditContract = _deployStakeCredit(operatorAddress, description.moniker);

        _validatorSet.add(operatorAddress);
        Validator storage valInfo = _validators[operatorAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = operatorAddress;
        valInfo.creditContract = creditContract;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;
        _consensusToOperator[consensusAddress] = operatorAddress;
        _voteToOperator[voteAddress] = operatorAddress;

        emit ValidatorCreated(consensusAddress, operatorAddress, creditContract, voteAddress);
    }

    function editConsensusAddress(address newConsensusAddress) external whenNotPaused validatorExist(msg.sender) {
        require(newConsensusAddress != address(0), "INVALID_CONSENSUS_ADDRESS");
        require(_consensusToOperator[newConsensusAddress] == address(0), "DUPLICATE_CONSENSUS_ADDRESS");

        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");

        valInfo.consensusAddress = newConsensusAddress;
        valInfo.updateTime = block.timestamp;
        _consensusToOperator[newConsensusAddress] = operatorAddress;

        emit ConsensusAddressEdited(operatorAddress, newConsensusAddress);
    }

    function editCommissionRate(uint64 commissionRate) external whenNotPaused validatorExist(msg.sender) {
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

    function editDescription(Description calldata description) external whenNotPaused validatorExist(msg.sender) {
        require(_checkMoniker(description.moniker), "INVALID_MONIKER");

        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");

        valInfo.description = description;
        valInfo.updateTime = block.timestamp;

        emit DescriptionEdited(operatorAddress);
    }

    function editVoteAddress(
        bytes calldata newVoteAddress,
        bytes calldata blsProof
    ) external whenNotPaused validatorExist(msg.sender) {
        require(_checkVoteAddress(newVoteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        require(_voteToOperator[newVoteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");

        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");

        valInfo.voteAddress = newVoteAddress;
        valInfo.updateTime = block.timestamp;
        _voteToOperator[newVoteAddress] = operatorAddress;

        emit VoteAddressEdited(operatorAddress, newVoteAddress);
    }

    function unjail(address operatorAddress) public whenNotPaused validatorExist(operatorAddress) {
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.jailed, "NOT_JAILED");

        require(
            IStakeCredit(valInfo.creditContract).getSelfDelegationBNB() >= minSelfDelegationBNB,
            "NOT_ENOUGH_SELF_DELEGATION"
        );
        require(valInfo.jailUntil <= block.timestamp, "STILL_JAILED");

        valInfo.jailed = false;
        numOfJailed -= 1;
        emit ValidatorUnjailed(operatorAddress);
    }

    function delegate(address operatorAddress) external payable whenNotPaused validatorExist(operatorAddress) {
        uint256 bnbAmount = msg.value;
        require(bnbAmount >= minDelegationBNBChange, "INVALID_DELEGATION_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];

        if (valInfo.jailed) {
            // only self delegation
            require(delegator == operatorAddress, "ONLY_SELF_DELEGATION");
        }

        uint256 shares = IStakeCredit(valInfo.creditContract).delegate{ value: bnbAmount }(delegator);
        emit Delegated(operatorAddress, delegator, shares, bnbAmount);

        _sync(valInfo.creditContract, delegator);
    }

    function undelegate(address operatorAddress, uint256 shares) public whenNotPaused validatorExist(operatorAddress) {
        require(shares > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        uint256 bnbAmount = IStakeCredit(valInfo.creditContract).undelegate(delegator, shares);
        emit Undelegated(operatorAddress, delegator, shares, bnbAmount);

        if (delegator == operatorAddress) {
            _checkValidatorSelfDelegation(operatorAddress);
        }

        _sync(valInfo.creditContract, delegator);
    }

    function redelegate(
        address srcValidator,
        address dstValidator,
        uint256 shares
    ) public whenNotPaused validatorExist(srcValidator) validatorExist(dstValidator) validatorNotJailed(dstValidator) {
        require(shares > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory srcValInfo = _validators[srcValidator];
        Validator memory dstValInfo = _validators[dstValidator];
        require(
            IStakeCredit(srcValInfo.creditContract).getPooledBNBByShares(shares) >= minDelegationBNBChange,
            "INVALID_REDELEGATION_AMOUNT"
        );

        if (dstValInfo.jailed) {
            // only self delegation
            require(delegator == dstValidator, "ONLY_SELF_DELEGATION");
        }

        uint256 bnbAmount = IStakeCredit(srcValInfo.creditContract).unbond(delegator, shares);
        uint256 newShares = IStakeCredit(dstValInfo.creditContract).delegate{ value: bnbAmount }(delegator);
        emit Redelegated(srcValidator, dstValidator, delegator, shares, newShares, bnbAmount);

        if (delegator == srcValidator) {
            _checkValidatorSelfDelegation(srcValidator);
        }

        address[] memory _pools = new address[](2);
        _pools[0] = srcValInfo.creditContract;
        _pools[1] = dstValInfo.creditContract;
        IGovBNB(GOV_TOKEN_ADDR).sync(_pools, delegator);
    }

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     */
    function claim(
        address operatorAddress,
        uint256 requestNumber
    ) external whenNotPaused validatorExist(operatorAddress) {
        uint256 bnbAmount = IStakeCredit(_validators[operatorAddress].creditContract).claim(msg.sender, requestNumber);
        emit Claimed(operatorAddress, msg.sender, bnbAmount);
    }

    function sync(address[] calldata operatorAddresses, address account) external whenNotPaused {
        uint256 _length = operatorAddresses.length;
        address[] memory validatorPools = new address[](_length);
        address _pool;
        for (uint256 i = 0; i < _length; ++i) {
            _pool = _validators[operatorAddresses[i]].creditContract;
            require(_pool != address(0), "validator not exist");
            validatorPools[i] = _pool;
        }

        IGovBNB(GOV_TOKEN_ADDR).sync(validatorPools, account);
    }

    /*----------------- system functions -----------------*/
    function distributeReward(address consensusAddress) external payable onlyValidatorContract {
        address operatorAddress = _consensusToOperator[consensusAddress];
        Validator memory valInfo = _validators[operatorAddress];
        if (valInfo.creditContract == address(0) || valInfo.jailed) {
            emit RewardDistributeFailed(operatorAddress, "INVALID_VALIDATOR");
            return;
        }

        try IStakeCredit(valInfo.creditContract).distributeReward{ value: msg.value }(valInfo.commission.rate) {
            emit RewardDistributed(operatorAddress, msg.value);
        } catch Error(string memory reason) {
            emit RewardDistributeFailed(operatorAddress, bytes(reason));
        } catch (bytes memory lowLevelData) {
            emit RewardDistributeFailed(operatorAddress, lowLevelData);
        }
    }

    /**
     * @dev Get new eligible validators from consensus engine
     */
    function updateEligibleValidators(
        address[] calldata validators,
        uint64[] calldata votingPowers
    ) external onlyCoinbase onlyZeroGasPrice {
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

        // update validator set
        IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).updateValidatorSetV2(_eligibleValidators, _eligibleValidatorVoteAddrs);
    }

    function downtimeSlash(address consensusAddress) external onlySlash {
        address operatorAddress = _consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.creditContract != address(0), "VALIDATOR_NOT_EXIST");

        // slash
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(downtimeSlashAmount);
        _jailValidator(valInfo);

        uint256 jailUntil = block.timestamp + downtimeJailTime;
        if (valInfo.jailUntil < jailUntil) {
            valInfo.jailUntil = jailUntil;
        }

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, uint248(block.number), SlashType.DownTime);

        _sync(valInfo.creditContract, operatorAddress);
    }

    function maliciousVoteSlash(bytes calldata _voteAddr, uint256 height) external onlySlash {
        address operatorAddress = _voteToOperator[_voteAddr];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.creditContract != address(0), "VALIDATOR_NOT_EXIST");

        // slash
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(doubleSignSlashAmount);
        _jailValidator(valInfo);

        SlashRecord storage record = _updateSlashRecord(operatorAddress, slashAmount, height, SlashType.MaliciousVote);
        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(
            operatorAddress, record.jailUntil, record.slashAmount, record.slashHeight, SlashType.MaliciousVote
        );

        _sync(valInfo.creditContract, operatorAddress);
    }

    function doubleSignSlash(address consensusAddress, uint256 height, uint256 evidenceTime) external onlySlash {
        address operatorAddress = _consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.creditContract != address(0), "VALIDATOR_NOT_EXIST");
        require(evidenceTime + maxEvidenceAge >= block.timestamp, "EVIDENCE_TOO_OLD");

        // slash
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(doubleSignSlashAmount);
        _jailValidator(valInfo);

        SlashRecord storage record = _updateSlashRecord(operatorAddress, slashAmount, height, SlashType.DoubleSign);
        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(
            operatorAddress, record.jailUntil, record.slashAmount, record.slashHeight, SlashType.DoubleSign
        );

        _sync(valInfo.creditContract, operatorAddress);
    }

    /*----------------- gov -----------------*/
    function pauseStaking() external onlyGov {
        _stakingPaused = true;
        emit StakingPaused();
    }

    function resumeStaking() external onlyGov {
        _stakingPaused = false;
        emit StakingResumed();
    }

    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("transferGasLimit")) {
            require(value.length == 32, "length of transferGasLimit mismatch");
            uint256 newTransferGasLimit = value.bytesToUint256(32);
            require(newTransferGasLimit >= 2300, "the transferGasLimit is out of range");
            transferGasLimit = newTransferGasLimit;
        } else if (key.compareStrings("minSelfDelegationBNB")) {
            require(value.length == 32, "length of minSelfDelegationBNB mismatch");
            uint256 newMinSelfDelegationBNB = value.bytesToUint256(32);
            require(newMinSelfDelegationBNB >= 1000 ether, "the minSelfDelegationBNB is out of range");
            newMinSelfDelegationBNB = newMinSelfDelegationBNB;
        } else if (key.compareStrings("minDelegationBNBChange")) {
            require(value.length == 32, "length of minDelegationBNBChange mismatch");
            uint256 newMinDelegationBNBChange = value.bytesToUint256(32);
            require(newMinDelegationBNBChange >= 1 ether, "the minDelegationBNBChange is out of range");
            minDelegationBNBChange = newMinDelegationBNBChange;
        } else if (key.compareStrings("maxElectedValidators")) {
            require(value.length == 32, "length of maxElectedValidators mismatch");
            uint256 newMaxElectedValidators = value.bytesToUint256(32);
            require(newMaxElectedValidators >= 1, "the maxElectedValidators is out of range");
            maxElectedValidators = newMaxElectedValidators;
        } else if (key.compareStrings("unbondPeriod")) {
            require(value.length == 32, "length of unbondPeriod mismatch");
            uint256 newUnbondPeriod = value.bytesToUint256(32);
            require(newUnbondPeriod >= 3 days, "the unbondPeriod is out of range");
            unbondPeriod = newUnbondPeriod;
        } else if (key.compareStrings("downtimeSlashAmount")) {
            require(value.length == 32, "length of downtimeSlashAmount mismatch");
            uint256 newDowntimeSlashAmount = value.bytesToUint256(32);
            require(
                newDowntimeSlashAmount >= 5 ether && newDowntimeSlashAmount < doubleSignSlashAmount,
                "the downtimeSlashAmount is out of range"
            );
            downtimeSlashAmount = newDowntimeSlashAmount;
        } else if (key.compareStrings("doubleSignSlashAmount")) {
            require(value.length == 32, "length of doubleSignSlashAmount mismatch");
            uint256 newDoubleSignSlashAmount = value.bytesToUint256(32);
            require(
                newDoubleSignSlashAmount >= 1000 ether && newDoubleSignSlashAmount > downtimeSlashAmount,
                "the doubleSignSlashAmount is out of range"
            );
            doubleSignSlashAmount = newDoubleSignSlashAmount;
        } else if (key.compareStrings("downtimeJailTime")) {
            require(value.length == 32, "length of downtimeJailTime mismatch");
            uint256 newDowntimeJailTime = value.bytesToUint256(32);
            require(
                newDowntimeJailTime >= 2 days && newDowntimeJailTime < doubleSignJailTime,
                "the downtimeJailTime is out of range"
            );
            downtimeJailTime = newDowntimeJailTime;
        } else if (key.compareStrings("doubleSignJailTime")) {
            require(value.length == 32, "length of doubleSignJailTime mismatch");
            uint256 newDoubleSignJailTime = value.bytesToUint256(32);
            require(
                newDoubleSignJailTime >= 100 days && newDoubleSignJailTime > downtimeJailTime,
                "the doubleSignJailTime is out of range"
            );
            doubleSignJailTime = newDoubleSignJailTime;
        } else if (key.compareStrings("maxEvidenceAge")) {
            require(value.length == 32, "length of maxEvidenceAge mismatch");
            uint256 newMaxEvidenceAge = value.bytesToUint256(32);
            require(newMaxEvidenceAge >= 7 days, "the maxEvidenceAge is out of range");
            maxEvidenceAge = newMaxEvidenceAge;
        } else {
            require(false, "unknown param");
        }
        emit ParamChange(key, value);
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
        returns (
            address consensusAddress,
            address creditContract,
            bytes memory voteAddress,
            bool jailed,
            uint256 jailUntil
        )
    {
        Validator memory valInfo = _validators[operatorAddress];
        consensusAddress = valInfo.consensusAddress;
        creditContract = valInfo.creditContract;
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
        totalLength = _validatorSet.length();
        if (offset >= totalLength) {
            return (consensusAddrs, votingPowers, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        consensusAddrs = new address[](count);
        votingPowers = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            address operatorAddress = _validatorSet.at(offset + i);
            Validator memory valInfo = _validators[operatorAddress];
            consensusAddrs[i] = valInfo.consensusAddress;
            votingPowers[i] = valInfo.jailed ? 0 : IStakeCredit(valInfo.creditContract).totalPooledBNB();
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
    function _getSlashKey(
        address operatorAddress,
        uint256 height,
        SlashType slashType
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(operatorAddress, height, slashType));
    }

    function _sync(address validatorPool, address account) private {
        address[] memory _pools = new address[](1);
        _pools[0] = validatorPool;
        IGovBNB(GOV_TOKEN_ADDR).sync(_pools, account);
    }

    function _checkMoniker(string memory moniker) internal pure returns (bool) {
        bytes memory bz = bytes(moniker);

        // 1. moniker length should be between 3 and 9
        if (bz.length < 3 || bz.length > 9) {
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
        bytes32 msgHash = keccak256(abi.encodePacked(voteAddress, block.chainid));
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

    function _deployStakeCredit(address operatorAddress, string memory moniker) internal returns (address) {
        address creditProxy = address(new TransparentUpgradeableProxy(STAKE_CREDIT_ADDR, DEAD_ADDRESS, ""));
        IStakeCredit(creditProxy).initialize{ value: msg.value }(operatorAddress, moniker);

        return creditProxy;
    }

    function _checkValidatorSelfDelegation(address operatorAddress) internal {
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.jailed) {
            return;
        }
        if (IStakeCredit(valInfo.creditContract).getSelfDelegationBNB() < minSelfDelegationBNB) {
            _jailValidator(valInfo);
            // need to inform validator set contract to remove the validator
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).jailValidator(valInfo.consensusAddress);
        }
    }

    function _updateSlashRecord(
        address operatorAddress,
        uint256 slashAmount,
        uint256 height,
        SlashType slashType
    ) internal returns (SlashRecord storage) {
        bytes32 slashKey = _getSlashKey(operatorAddress, height, slashType);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashAmount = slashAmount;
        record.slashHeight = uint248(height);
        record.slashType = slashType;

        return record;
    }

    function _jailValidator(Validator storage valInfo) internal {
        // keep the last eligible validator
        bool isLast = (numOfJailed >= _validatorSet.length() - 1);
        if (isLast) {
            emit ValidatorEmptyJailed(valInfo.operatorAddress);
            return;
        }

        if (!valInfo.jailed) {
            valInfo.jailed = true;
            numOfJailed += 1;
        }

        emit ValidatorJailed(valInfo.operatorAddress);
    }
}
