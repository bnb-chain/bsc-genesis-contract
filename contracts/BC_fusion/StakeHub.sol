// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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
    function getPooledBNBByShares(uint256 sharesAmount) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function delegate(address delegator) external payable returns (uint256);
    function undelegate(address delegator, uint256 sharesAmount) external returns (uint256);
    function unbond(address delegator, uint256 sharesAmount) external returns (uint256);
    function distributeReward() external payable;
    function slash(uint256 slashBnbAmount) external returns (uint256);
    function getSecurityDepositBNB() external view returns (uint256);
    function lockToGovernance(address from, uint256 sharesAmount) external returns (uint256);
    function balanceOf(address delegator) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract StakeHub is System {
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

    // validator operator address => validator info
    mapping(address => Validator) public validators;
    // validator vote address => validator operator address
    mapping(bytes => address) public voteToOperator;
    // validator consensus address => validator operator address
    mapping(address => address) public consensusToOperator;
    // validator operator address => withdraw security fund request
    mapping(address => WithdrawRequest) private _withdrawRequests;
    // slash key => slash record
    mapping(bytes32 => SlashRecord) private _slashRecords;

    IBSCValidatorSet.Validator[] public eligibleValidators;
    mapping(address => uint256) public eligibleValidatorIndices; // validator address => index+1 in eligibleValidators
    uint256[] public eligibleValidatorVotingPowers;
    bytes[] public eligibleValidatorVoteAddrs;

    struct Validator {
        address consensusAddress;
        address operatorAddress;
        bool jailed;
        address poolModule;
        bytes voteAddress;
        Description description;
        Commission commission;
        uint256 updateTime;
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
        uint256 rate; // the commission rate charged to delegators
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
        require(validators[operatorAddress].poolModule != address(0), "VALIDATOR_NOT_EXIST");
        _;
    }

    modifier validatorNotJailed(address validator) {
        require(!validators[validator].jailed, "VALIDATOR_JAILED");
        _;
    }

    modifier whenNotPaused() {
        require(!_stakingPaused, "STAKE_STOPPED");
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
        require(validators[operatorAddress].poolModule == address(0), "ALREADY_VALIDATOR");
        require(voteToOperator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(commission.rate <= commission.maxRate, "INVALID_COMMISSION_RATE");
        require(commission.maxChangeRate <= commission.maxRate, "INVALID_MAX_CHANGE_RATE");

        // check vote address
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        voteToOperator[voteAddress] = operatorAddress;

        // deploy stake pool
        address poolModule = _deployStakePool(operatorAddress);

        Validator storage valInfo = validators[operatorAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = operatorAddress;
        valInfo.poolModule = poolModule;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;
        consensusToOperator[consensusAddress] = operatorAddress;

        emit ValidatorCreated(consensusAddress, operatorAddress, poolModule, voteAddress);

        // update eligible validators
        _updateEligibleValidators(UpdateDirection.Up, operatorAddress, voteAddress);
    }

    function editConsensusAddress(address newConsensus) external onlyInitialized validatorExist(msg.sender) {
        require(newConsensus != address(0), "INVALID_CONSENSUS_ADDRESS");
        address operatorAddress = msg.sender;
        Validator storage valInfo = validators[operatorAddress];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");

        address oldConsensus = valInfo.consensusAddress;
        delete consensusToOperator[oldConsensus];

        valInfo.operatorAddress = newConsensus;
        valInfo.updateTime = block.timestamp;

        emit ConsensusAddressEdited(oldConsensus, newConsensus);
    }

    function editDescription(Description calldata description) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = validators[operatorAddress];

        valInfo.description = description;
        valInfo.updateTime = block.timestamp;

        emit DescriptionEdited(operatorAddress);
    }

    function editVoteAddress(bytes calldata newVoteAddress, bytes calldata blsProof) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator storage valInfo = validators[operatorAddress];
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
        Validator storage valInfo = validators[operatorAddress];
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
        Validator storage valInfo = validators[validator];
        require(valInfo.jailed, "NOT_JAILED");

        address pool = valInfo.poolModule;
        require(IStakePool(pool).getSecurityDepositBNB() >= minSelfDelegationBNB, "NOT_ENOUGH_SELF_DELEGATION");
        require(valInfo.jailUntil <= block.timestamp, "STILL_JAILED");

        valInfo.jailed = false;

        emit ValidatorUnjailed(validator);

        _updateEligibleValidators(UpdateDirection.Up, validator, valInfo.voteAddress);
    }

    function delegate(address validator) external payable onlyInitialized validatorExist(validator) whenNotPaused {
        uint256 _bnbAmount = msg.value;
        require(_bnbAmount >= minDelegationBNBChange, "INVALID_DELEGATION_AMOUNT");
        address delegator = msg.sender;
        Validator memory valInfo = validators[validator];

        if (valInfo.jailed || IStakePool(valInfo.poolModule).getSecurityDepositBNB() < minSelfDelegationBNB) {
            // only self delegation
            require(delegator == validator, "ONLY_SELF_DELEGATION");
        }

        emit Delegated(validator, delegator, _bnbAmount);

        _updateEligibleValidators(UpdateDirection.Up, validator, valInfo.voteAddress);
    }

    function undelegate(address validator, uint256 _sharesAmount) public onlyInitialized validatorExist(validator) whenNotPaused {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = validators[validator];
        uint256 _bnbAmount = IStakePool(valInfo.poolModule).undelegate(delegator, _sharesAmount);

        emit Undelegated(validator, delegator, _bnbAmount);

        _updateEligibleValidators(UpdateDirection.Down, validator, valInfo.voteAddress);
    }

    function redelegate(address srcValidator, address dstValidator, uint256 _sharesAmount) public onlyInitialized validatorExist(srcValidator) validatorExist(dstValidator) validatorNotJailed(dstValidator) whenNotPaused {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory srcValInfo = validators[srcValidator];
        Validator memory dstValInfo = validators[dstValidator];

        uint256 _bnbAmount = IStakePool(srcValInfo.poolModule).unbond(delegator, _sharesAmount);
        IStakePool(dstValInfo.poolModule).delegate{value: _bnbAmount}(delegator);

        emit Redelegated(srcValidator, dstValidator, delegator, _bnbAmount);

        bytes memory srcValVoteAddr = srcValInfo.voteAddress;
        bytes memory dstValVoteAddr = dstValInfo.voteAddress;
        _updateEligibleValidators(UpdateDirection.Down, srcValidator, srcValVoteAddr);
        _updateEligibleValidators(UpdateDirection.Up, dstValidator, dstValVoteAddr);
    }

    function submitSecurityFundWithdrawRequest(uint256 _sharesAmount) external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        Validator memory valInfo = validators[operatorAddress];
        require(_withdrawRequests[operatorAddress].sharesAmount == 0, "REQUEST_EXIST");
        require(IStakePool(valInfo.poolModule).balanceOf(address(this)) >= _sharesAmount, "NOT_ENOUGH_SHARES");

        _withdrawRequests[operatorAddress] = WithdrawRequest({sharesAmount: _sharesAmount, unlockTime: block.timestamp + 1 days});
        emit SecurityFundWithdrawRequested(operatorAddress, _sharesAmount);

        uint256 afterBalance = IStakePool(valInfo.poolModule).getSecurityDepositBNB() - _sharesAmount;
        if (afterBalance < minSelfDelegationBNB) {
            valInfo.jailed = true;
            _removeEligibleValidator(operatorAddress);
            emit ValidatorJailed(operatorAddress);
        }
    }

    function claimSecurityFund() external onlyInitialized validatorExist(msg.sender) {
        address operatorAddress = msg.sender;
        WithdrawRequest memory request = _withdrawRequests[operatorAddress];
        require(request.unlockTime <= block.timestamp, "NOT_UNLOCKED");

        uint256 _sharesAmount = request.sharesAmount;
        require(_sharesAmount > 0, "REQUEST_NOT_EXIST");

        emit SecurityFundClaimed(msg.sender, _sharesAmount);
        delete _withdrawRequests[operatorAddress];

        IStakePool(validators[operatorAddress].poolModule).transfer(msg.sender, _sharesAmount);
    }

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     * `validator` is the validator's operator address
     */
    function claim(address validator, uint256 requestNumber) external onlyInitialized validatorExist(validator) {
        uint256 _bnbAmount = IStakePool(validators[validator].poolModule).claim(msg.sender, requestNumber);

        emit Claimed(validator, msg.sender, _bnbAmount);
    }

    /*----------------- system functions -----------------*/
    function distributeReward(address _consensusAddress) external payable onlyInitialized onlyValidatorContract {
        address validator = consensusToOperator[_consensusAddress];
        require(validator != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator memory valInfo = validators[validator];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        IStakePool(valInfo.poolModule).distributeReward{value: msg.value}();
    }

    function getEligibleValidators() external view returns (IBSCValidatorSet.Validator[] memory, bytes[] memory) {
        return (eligibleValidators, eligibleValidatorVoteAddrs);
    }

    function downtimeSlash(address _consensusAddress, uint256 height) external onlyInitialized onlySlash {
        address operatorAddress = consensusToOperator[_consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.DownTime);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(downtimeSlashAmount);
        valInfo.jailed = true;
        _removeEligibleValidator(operatorAddress);
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
        address operatorAddress = _getValidatorByVoteAddr(_voteAddr);
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.MaliciousVote);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;
        _removeEligibleValidator(operatorAddress);
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

    function doubleSignSlash(address _consensusAddress, uint256 height, uint256 evidenceTime) external onlyInitialized onlySlash {
        address operatorAddress = consensusToOperator[_consensusAddress];
        require(operatorAddress != address(0), "INVALID_CONSENSUS_ADDRESS"); // should never happen
        Validator storage valInfo = validators[operatorAddress];
        require(valInfo.poolModule != address(0), "VALIDATOR_NOT_EXIST");

        require(evidenceTime + maxEvidenceAge >= block.timestamp, "EVIDENCE_TOO_OLD");

        // check slash record
        bytes32 slashKey = _getSlashKey(operatorAddress, height, SlashType.DoubleSign);
        SlashRecord storage record = _slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;
        _removeEligibleValidator(operatorAddress);
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
        address pool = validators[operatorAddress].poolModule;

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
    function getValidatorByVoteAddr(bytes calldata voteAddr) external view returns (address) {
        return _getValidatorByVoteAddr(voteAddr);
    }

    function isPaused() external view returns (bool) {
        return _stakingPaused;
    }

    function isValidatorActive(address operatorAddress) external view validatorExist(operatorAddress) returns (bool) {
        return !validators[operatorAddress].jailed;
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

    function _getValidatorByVoteAddr(bytes calldata voteAddr) internal view returns (address) {
        return voteToOperator[voteAddr];
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

    function _updateEligibleValidators(UpdateDirection direction, address operatorAddress, bytes memory voteAddress) internal {
        address pool = validators[operatorAddress].poolModule;
        address consensusAddress = validators[operatorAddress].consensusAddress;
        uint256 _votingPower = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).totalSupply());

        // remove extra validators
        if (eligibleValidators.length > maxElectedValidators) {
            for (uint256 i = maxElectedValidators; i < eligibleValidators.length; ++i) {
                delete eligibleValidatorIndices[eligibleValidators[i].consensusAddress];
                delete eligibleValidators[i];
                delete eligibleValidatorVotingPowers[i];
                delete eligibleValidatorVoteAddrs[i];
            }
        }

        uint256 index = eligibleValidatorIndices[consensusAddress];
        // move existing eligible validator
        if (index != 0) {
            if (direction == UpdateDirection.Up && index > 1) {
                uint256 newIndex = index;
                // find the new index
                for (uint256 i = index - 2; i >= 0; --i) {
                    if (eligibleValidatorVotingPowers[i] > _votingPower) {
                        break;
                    } else if (eligibleValidatorVotingPowers[i] == _votingPower) {
                        if (eligibleValidators[i].consensusAddress < consensusAddress) {
                            newIndex = i + 2;
                        } else {
                            newIndex = i + 1;
                        }
                        break;
                    } else {
                        newIndex = i + 1;
                    }
                }

                if (newIndex < index) {
                    // move to the new index
                    for (uint256 i = index - 1; i >= newIndex; --i) {
                        eligibleValidators[i] = eligibleValidators[i - 1];
                        eligibleValidatorVotingPowers[i] = eligibleValidatorVotingPowers[i - 1];
                        eligibleValidatorVoteAddrs[i] = eligibleValidatorVoteAddrs[i - 1];
                        eligibleValidatorIndices[eligibleValidators[i].consensusAddress] = i + 1;
                    }
                    eligibleValidators[newIndex - 1] = IBSCValidatorSet.Validator({consensusAddress: consensusAddress, feeAddress: payable(0), BBCFeeAddress: payable(0), votingPower: uint64(_votingPower), jailed: false, incoming: 0});
                    eligibleValidatorVotingPowers[newIndex - 1] = _votingPower;
                    eligibleValidatorVoteAddrs[newIndex - 1] = voteAddress;
                    eligibleValidatorIndices[consensusAddress] = newIndex;
                }
            } else if (direction == UpdateDirection.Down && index < eligibleValidators.length) {
                uint256 newIndex = index;
                // find the new index
                for (uint256 i = index; i < eligibleValidators.length; ++i) {
                    if (eligibleValidatorVotingPowers[i] < _votingPower) {
                        break;
                    } else if (eligibleValidatorVotingPowers[i] == _votingPower) {
                        if (eligibleValidators[i].consensusAddress > consensusAddress) {
                            newIndex = i;
                        } else {
                            newIndex = i + 1;
                        }
                        break;
                    } else {
                        newIndex = i + 1;
                    }
                }

                if (newIndex > index) {
                    // move to the new index
                    for (uint256 i = index - 1; i < newIndex - 1; ++i) {
                        eligibleValidators[i] = eligibleValidators[i + 1];
                        eligibleValidatorVotingPowers[i] = eligibleValidatorVotingPowers[i + 1];
                        eligibleValidatorVoteAddrs[i] = eligibleValidatorVoteAddrs[i + 1];
                        eligibleValidatorIndices[eligibleValidators[i].consensusAddress] = i + 1;
                    }
                    eligibleValidators[newIndex - 1] = IBSCValidatorSet.Validator({consensusAddress: consensusAddress, feeAddress: payable(0), BBCFeeAddress: payable(0), votingPower: uint64(_votingPower), jailed: false, incoming: 0});
                    eligibleValidatorVotingPowers[newIndex - 1] = _votingPower;
                    eligibleValidatorVoteAddrs[newIndex - 1] = voteAddress;
                    eligibleValidatorIndices[consensusAddress] = newIndex;
                }
            }
            return;
        }

        // add new eligible validator
        if (direction == UpdateDirection.Up) {
            if (eligibleValidators.length < maxElectedValidators) {
                eligibleValidators.push(IBSCValidatorSet.Validator({consensusAddress: address(0), feeAddress: payable(0), BBCFeeAddress: payable(0), votingPower: 0, jailed: false, incoming: 0}));
                eligibleValidatorVotingPowers.push(0);
                eligibleValidatorVoteAddrs.push(bytes(""));
            }

            uint256 newIndex = eligibleValidators.length + 1;
            for (uint256 i = eligibleValidators.length - 1; i >= 0; --i) {
                if (eligibleValidatorVotingPowers[i] > _votingPower) {
                    break;
                } else if (eligibleValidatorVotingPowers[i] == _votingPower) {
                    if (eligibleValidators[i].consensusAddress < consensusAddress) {
                        newIndex = i + 2;
                    } else {
                        newIndex = i + 1;
                    }
                    break;
                } else {
                    newIndex = i + 1;
                }
            }

            if (newIndex <= eligibleValidators.length) {
                // move to the new index
                for (uint256 i = eligibleValidators.length - 1; i >= newIndex; --i) {
                    delete eligibleValidatorIndices[eligibleValidators[i].consensusAddress];
                    eligibleValidators[i] = eligibleValidators[i - 1];
                    eligibleValidatorVotingPowers[i] = eligibleValidatorVotingPowers[i - 1];
                    eligibleValidatorVoteAddrs[i] = eligibleValidatorVoteAddrs[i - 1];
                    eligibleValidatorIndices[eligibleValidators[i].consensusAddress] = i + 1;
                }
                eligibleValidators[newIndex - 1] = IBSCValidatorSet.Validator({consensusAddress: consensusAddress, feeAddress: payable(0), BBCFeeAddress: payable(0), votingPower: uint64(_votingPower), jailed: false, incoming: 0});
                eligibleValidatorVotingPowers[newIndex - 1] = _votingPower;
                eligibleValidatorVoteAddrs[newIndex - 1] = voteAddress;
                eligibleValidatorIndices[consensusAddress] = newIndex;
            }
        }
    }

    function _removeEligibleValidator(address operatorAddress) internal {
        address consensusAddress = validators[operatorAddress].consensusAddress;
        if (eligibleValidatorIndices[consensusAddress] != 0) {
            uint256 index = eligibleValidatorIndices[consensusAddress] - 1;
            for (uint256 i = index; i < eligibleValidators.length - 1; ++i) {
                delete eligibleValidatorIndices[eligibleValidators[i].consensusAddress];
                eligibleValidators[i] = eligibleValidators[i + 1];
                eligibleValidatorVotingPowers[i] = eligibleValidatorVotingPowers[i + 1];
                eligibleValidatorVoteAddrs[i] = eligibleValidatorVoteAddrs[i + 1];
                eligibleValidatorIndices[eligibleValidators[i].consensusAddress] = i + 1;
            }
            delete eligibleValidatorIndices[consensusAddress];
        }
    }
}
