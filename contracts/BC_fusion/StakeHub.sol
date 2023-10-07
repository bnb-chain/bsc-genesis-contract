// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./System.sol";

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
    function initialize(address validator, uint256 minSelfDelegationBNB) external payable;
    function claim(address delegator, uint256 requestNumber) external returns (uint256);
    function getTotalPooledBNB() external view returns (uint256);
    function getPooledBNBByShares(uint256 sharesAmount) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function delegate(address delegator) external payable returns (uint256);
    function undelegate(address delegator, uint256 sharesAmount) external returns (uint256);
    function unbond(address delegator, uint256 sharesAmount) external returns (uint256);
    function distributeReward(uint256 commissionRate) external payable;
    function slash(uint256 slashBnbAmount) external returns (uint256);
    function getSecurityDepositBNB() external view returns (uint256);
    function lockToGovernance(address from, uint256 sharesAmount) external returns (uint256);
    function balanceOf(address delegator) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract StakeHub is System {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constant -----------------*/
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

    /*----------------- storage -----------------*/
    uint8 private _initialized;
    bool private _stakingPaused;

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
    mapping(bytes => address) public voteToOperator;
    // validator consensus address => validator operator address
    mapping(address => address) public consensusToOperator;
    // validator operator address => withdraw security fund request
    mapping(address => WithdrawRequest) public withdrawRequests;
    // slash key => slash record
    mapping(bytes32 => SlashRecord) public slashRecords;

    IBSCValidatorSet.Validator[] public eligibleValidators;
    bytes[] public eligibleValidatorVoteAddrs;

    struct Validator {
        address consensusAddress;
        address operatorAddress;
        address poolModule;
        bytes voteAddress;
        Description description;
        Commission commission;
        uint256 updateTime;
        bool jailed;
        uint256 jailUntil;
        uint256[20] slots;
    }

    struct Description {
        string moniker;
        string identity;
        string website;
        string details;
    }

    struct Commission {
        uint256 rate; // the commission rate charged to delegators(10000 is 100%)
        uint256 maxRate; // maximum commission rate which validator can ever charge
        uint256 maxChangeRate; // maximum daily increase of the validator commission
    }

    struct WithdrawRequest {
        uint256 sharesAmount;
        uint256 unlockTime;
    }

    struct SlashRecord {
        uint256 slashAmount;
        uint256 slashHeight;
        uint256 jailUntil;
        SlashType slashType;
    }

    enum SlashType {
        DoubleSign,
        DownTime,
        MaliciousVote
    }

    enum UpdateDirection {
        Up,
        Down
    }

    /*----------------- events -----------------*/
    event ValidatorCreated(address indexed consensusAddress, address indexed operatorAddress, address indexed poolModule, bytes voteAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint256 commissionRate);
    event ConsensusAddressEdited(address indexed oldAddress, address indexed newAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event DescriptionEdited(address indexed operatorAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event Redelegated(address indexed srcValidator, address indexed dstValidator, address indexed delegator, uint256 bnbAmount);
    event ValidatorSlashed(address indexed operatorAddress, uint256 slashAmount, uint256 slashHeight, uint256 jailUntil, SlashType slashType);
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event SecurityFundWithdrawRequested(address indexed operatorAddress, uint256 sharesAmount);
    event SecurityFundClaimed(address indexed operatorAddress, uint256 sharesAmount);
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

    modifier validatorNotJailed(address validator) {
        require(!_validators[validator].jailed, "VALIDATOR_JAILED");
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

    /*----------------- init -----------------*/
    function initialize() public {
        require(_initialized == 0, "ALREADY_INITIALIZED");
        transferGasLimit = INIT_TRANSFER_GAS_LIMIT;

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
    function createValidator(address consensusAddress, bytes calldata voteAddress, bytes calldata blsProof, Commission calldata commission, Description calldata description) external payable onlyInitialized {
        uint256 delegation = msg.value;
        require(delegation >= minSelfDelegationBNB, "INVALID_SELF_DELEGATION");
        address operatorAddress = msg.sender;
        require(_validators[operatorAddress].poolModule == address(0), "ALREADY_VALIDATOR");
        require(voteToOperator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(commission.rate <= commission.maxRate, "INVALID_COMMISSION_RATE");
        require(commission.maxChangeRate <= commission.maxRate, "INVALID_MAX_CHANGE_RATE");

        // check vote address
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        voteToOperator[voteAddress] = operatorAddress;

        // deploy stake pool
        address poolModule = _deployStakePool(operatorAddress);

        _validatorSet.add(operatorAddress);
        Validator storage valInfo = _validators[operatorAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = operatorAddress;
        valInfo.poolModule = poolModule;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;
        consensusToOperator[consensusAddress] = operatorAddress;

        emit ValidatorCreated(consensusAddress, operatorAddress, poolModule, voteAddress);
    }

    function editConsensusAddress(address newConsensus) external onlyInitialized validatorExist(msg.sender) {
        require(newConsensus != address(0), "INVALID_CONSENSUS_ADDRESS");
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");

        address oldConsensus = valInfo.consensusAddress;
        delete consensusToOperator[oldConsensus];

        valInfo.operatorAddress = newConsensus;
        valInfo.updateTime = block.timestamp;

        emit ConsensusAddressEdited(oldConsensus, newConsensus);
    }

    function editDescription(Description calldata description) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];

        valInfo.description = description;
        valInfo.updateTime = block.timestamp;

        emit DescriptionEdited(operatorAddress);
    }

    function editVoteAddress(bytes calldata newVoteAddress, bytes calldata blsProof) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(voteToOperator[newVoteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(_checkVoteAddress(newVoteAddress, blsProof), "INVALID_VOTE_ADDRESS");

        bytes memory oldVoteAddress = valInfo.voteAddress;
        delete voteToOperator[oldVoteAddress];

        voteToOperator[newVoteAddress] = operatorAddress;
        valInfo.voteAddress = newVoteAddress;
        valInfo.updateTime = block.timestamp;

        emit VoteAddressEdited(operatorAddress, newVoteAddress);
    }

    function editCommissionRate(address validator, uint256 commissionRate) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(commissionRate <= valInfo.commission.maxRate, "INVALID_COMMISSION_RATE");

        if (commissionRate > valInfo.commission.rate) {
            require(commissionRate - valInfo.commission.rate <= valInfo.commission.maxChangeRate, "INVALID_MAX_CHANGE_RATE");
        } else {
            require(valInfo.commission.rate - commissionRate <= valInfo.commission.maxChangeRate, "INVALID_MAX_CHANGE_RATE");
        }

        valInfo.commission.rate = commissionRate;
        valInfo.updateTime = block.timestamp;

        emit CommissionRateEdited(operatorAddress, commissionRate);
    }

    /**
     * @dev `validator` is the validator's operator address
     */
    function unjail(address validator) public onlyInitialized validatorExist(validator) {
        Validator storage valInfo = _validators[validator];
        require(valInfo.jailed, "NOT_JAILED");

        address pool = valInfo.poolModule;
        require(IStakePool(pool).getSecurityDepositBNB() >= minSelfDelegationBNB, "NOT_ENOUGH_SELF_DELEGATION");
        require(valInfo.jailUntil <= block.timestamp, "STILL_JAILED");

        valInfo.jailed = false;

        emit ValidatorUnjailed(validator);
    }

    function delegate(address validator) external payable onlyInitialized validatorExist(validator) whenNotPaused {
        uint256 _bnbAmount = msg.value;
        require(_bnbAmount >= minDelegationBNBChange, "INVALID_DELEGATION_AMOUNT");
        address delegator = msg.sender;
        Validator memory valInfo = _validators[validator];

        if (valInfo.jailed || IStakePool(valInfo.poolModule).getSecurityDepositBNB() < minSelfDelegationBNB) {
            // only self delegation
            require(delegator == validator, "ONLY_SELF_DELEGATION");
        }

        emit Delegated(validator, delegator, _bnbAmount);
    }

    function undelegate(address validator, uint256 _sharesAmount) public onlyInitialized validatorExist(validator) whenNotPaused {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = _validators[validator];
        uint256 _bnbAmount = IStakePool(valInfo.poolModule).undelegate(delegator, _sharesAmount);

        emit Undelegated(validator, delegator, _bnbAmount);
    }

    function redelegate(address srcValidator, address dstValidator, uint256 _sharesAmount) public onlyInitialized validatorExist(srcValidator) validatorExist(dstValidator) validatorNotJailed(dstValidator) whenNotPaused {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory srcValInfo = _validators[srcValidator];
        Validator memory dstValInfo = _validators[dstValidator];

        uint256 _bnbAmount = IStakePool(srcValInfo.poolModule).unbond(delegator, _sharesAmount);
        IStakePool(dstValInfo.poolModule).delegate{value: _bnbAmount}(delegator);

        emit Redelegated(srcValidator, dstValidator, delegator, _bnbAmount);
    }

    function submitSecurityFundWithdrawRequest(uint256 _sharesAmount) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        require(withdrawRequests[operatorAddress].sharesAmount == 0, "REQUEST_EXIST");
        require(IStakePool(valInfo.poolModule).balanceOf(address(this)) >= _sharesAmount, "NOT_ENOUGH_SHARES");

        withdrawRequests[operatorAddress] = WithdrawRequest({sharesAmount: _sharesAmount, unlockTime: block.timestamp + 1 days});
        emit SecurityFundWithdrawRequested(operatorAddress, _sharesAmount);

        uint256 afterBalance = IStakePool(valInfo.poolModule).getSecurityDepositBNB() - _sharesAmount;
        if (afterBalance < minSelfDelegationBNB) {
            valInfo.jailed = true;
            emit ValidatorJailed(operatorAddress);
        }
    }

    function claimSecurityFund() external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        WithdrawRequest memory request = withdrawRequests[operatorAddress];
        require(request.unlockTime <= block.timestamp, "NOT_UNLOCKED");

        uint256 _sharesAmount = request.sharesAmount;
        require(_sharesAmount > 0, "REQUEST_NOT_EXIST");

        emit SecurityFundClaimed(msg.sender, _sharesAmount);
        delete withdrawRequests[operatorAddress];

        IStakePool(_validators[operatorAddress].poolModule).transfer(msg.sender, _sharesAmount);
    }

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     * `validator` is the validator's operator address
     */
    function claim(address validator, uint256 requestNumber) external onlyInitialized validatorExist(validator) {
        uint256 _bnbAmount = IStakePool(_validators[validator].poolModule).claim(msg.sender, requestNumber);

        emit Claimed(validator, msg.sender, _bnbAmount);
    }

    /*----------------- system functions -----------------*/
    function distributeReward(address consensusAddress) external payable onlyInitialized onlyValidatorContract {
        address operatorAddress = consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator memory valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        IStakePool(valInfo.poolModule).distributeReward{value: msg.value}(valInfo.commission.rate);
    }

    /**
     * @dev Get new eligible validators from consensus engine
     */
    function updateEligibleValidators(address[] calldata validators, uint64[] calldata votingPowers) external onlyInitialized onlyCoinbase onlyZeroGasPrice {
        uint256 newLength = validators.length;
        if (newLength == 0) {
            return;
        }
        uint256 oldLength = eligibleValidators.length;
        if (oldLength > newLength) {
            for (uint256 i = newLength; i < oldLength; ++i) {
                eligibleValidators.pop();
                eligibleValidatorVoteAddrs.pop();
            }
        }

        uint256 j;
        for (uint256 i; i < newLength; ++i) {
            address consensusAddress = validators[i];
            address operatorAddress = consensusToOperator[consensusAddress];
            if (operatorAddress == address(0)) {
                continue;
            }

            if (j >= oldLength) {
                eligibleValidators.push(IBSCValidatorSet.Validator({consensusAddress: consensusAddress, feeAddress: payable(0), BBCFeeAddress: address(0), votingPower: votingPowers[i], jailed: false, incoming: 0}));
                eligibleValidatorVoteAddrs.push(_validators[operatorAddress].voteAddress);
            } else {
                IBSCValidatorSet.Validator storage eVal = eligibleValidators[j];
                eVal.consensusAddress = consensusAddress;
                eVal.votingPower = votingPowers[i];
                eligibleValidatorVoteAddrs[j] = _validators[operatorAddress].voteAddress;
            }
            ++j;
        }
    }

    function downtimeSlash(address consensusAddress, uint256 height) external onlyInitialized onlySlash {
        address operatorAddress = consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.DownTime);
        SlashRecord storage record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(downtimeSlashAmount);
        valInfo.jailed = true;
        emit ValidatorJailed(operatorAddress);

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = height;
        record.jailUntil = block.timestamp + downtimeJailTime;
        record.slashType = SlashType.DownTime;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(operatorAddress, slashAmount, height, record.jailUntil, SlashType.DownTime);
    }

    function maliciousVoteSlash(bytes calldata _voteAddr, uint256 height) external onlyInitialized onlySlash {
        address operatorAddress = voteToOperator[_voteAddr];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.MaliciousVote);
        SlashRecord storage record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;
        emit ValidatorJailed(operatorAddress);

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = height;
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashType = SlashType.MaliciousVote;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(operatorAddress, slashAmount, height, record.jailUntil, SlashType.MaliciousVote);
    }

    function doubleSignSlash(address consensusAddress, uint256 height, uint256 evidenceTime) external onlyInitialized onlySlash {
        address operatorAddress = consensusToOperator[consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = _validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        require(evidenceTime + maxEvidenceAge >= block.timestamp, "EVIDENCE_TOO_OLD");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.DoubleSign);
        SlashRecord storage record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;
        emit ValidatorJailed(operatorAddress);

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = height;
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashType = SlashType.MaliciousVote;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }

        emit ValidatorSlashed(operatorAddress, slashAmount, height, record.jailUntil, SlashType.DoubleSign);
    }

    function lockToGovernance(address operatorAddress, address from, uint256 _sharesAmount) external onlyInitialized onlyGovernance validatorExist(operatorAddress) validatorNotJailed(operatorAddress) returns (uint256) {
        address pool = _validators[operatorAddress].poolModule;

        return IStakePool(pool).lockToGovernance(from, _sharesAmount);
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
        // TODO: add all params
        if (_compareStrings(key, "minSelfDelegationBNB")) {
            require(value.length == 32, "length of minSelfDelegationBNB mismatch");
            uint256 newMinSelfDelegationBNB = _bytesToUint256(32, value);
            require(newMinSelfDelegationBNB >= 1000 ether, "the minSelfDelegationBNB is out of range");
            newMinSelfDelegationBNB = newMinSelfDelegationBNB;
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
        return (eligibleValidators, eligibleValidatorVoteAddrs);
    }

    function getValidatorBasicInfo(address operatorAddress) external view returns (address consensusAddress, address poolModule, bytes memory voteAddress, bool jailed, uint256 jailUntil) {
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

    function getValidatorWithVotingPower(uint256 offset, uint256 limit) external view returns (address[] memory consensusAddrs, uint256[] memory votingPowers) {
        uint256 length = _validatorSet.length();
        if (offset >= length) {
            return (consensusAddrs, votingPowers);
        }

        uint256 count = length - offset;
        if (count > limit) {
            count = limit;
        }

        consensusAddrs = new address[](count);
        votingPowers = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            address operatorAddress = _validatorSet.at(offset + i);
            Validator memory valInfo = _validators[operatorAddress];
            consensusAddrs[i] = valInfo.consensusAddress;
            address pool = valInfo.poolModule;
            votingPowers[i] = IStakePool(pool).getTotalPooledBNB();
        }
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

    function _getSlashKey(address valAddr, uint256 height, SlashType slashType) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(valAddr, height, slashType));
    }

    function _bytesConcat(bytes memory data, bytes memory _bytes, uint256 index, uint256 len) internal pure {
        for (uint256 i; i < len; ++i) {
            data[index++] = _bytes[i];
        }
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

        // assemble input data
        bytes memory input = new bytes(176);
        _bytesConcat(input, msgBz, 0, 32);
        _bytesConcat(input, blsProof, 32, 96);
        _bytesConcat(input, voteAddress, 128, 48);

        // call the precompiled contract to verify the BLS signature
        // the precompiled contract's address is 0x66
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

    function _deployStakePool(address validator) internal returns (address) {
        address poolProxy = address(new TransparentUpgradeableProxy(poolImplementation, STAKE_HUB_ADDR, ""));
        IStakePool(poolProxy).initialize{value: msg.value}(validator, minSelfDelegationBNB);

        return poolProxy;
    }
}