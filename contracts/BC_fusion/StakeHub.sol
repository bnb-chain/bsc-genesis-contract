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
    function balanceOf(address delegator) external view returns (uint256);
    function claim(address delegator, uint256 requestNumber) external;
    function getPooledBNBByShares(uint256 sharesAmount) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function delegate(address delegator) external payable returns (uint256);
    function undelegate(address delegator, uint256 sharesAmount) external returns (uint256);
    function redelegate(address delegator, uint256 sharesAmount) external returns (uint256);
    function distributeReward() external payable;
    function slash(uint256 slashBnbAmount) external returns (uint256);
    function getSelfDelegation() external view returns (uint256);
    function getSelfDelegationBNB() external view returns (uint256);
    function lockToGovernance(address from, uint256 sharesAmount) external returns (uint256);
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

    // validator address => validator info
    mapping(address => Validator) public validators;
    // validator vote address => validator address
    mapping(bytes => address) public voteAddressToValidator;
    // slash key => slash record
    mapping(bytes32 => SlashRecord) public slashRecords;

    uint256 public totalPooledBNB;

    IBSCValidatorSet.Validator[] public eligibleValidators;
    uint256[] public eligibleValidatorDelegatedAmounts;
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

    enum SlashType {
        DoubleSign,
        DownTime,
        MaliciousVote
    }

    struct SlashRecord {
        uint256 slashAmount;
        uint256 slashHeight;
        uint256 jailUntil;
        SlashType slashType;
    }

    event paramChange(string key, bytes value);

    /*----------------- modifiers -----------------*/
    modifier onlyInitialized() {
        require(_initialized != 0, "NOT_INITIALIZED");
        _;
    }

    modifier validatorExist(address validator) {
        require(validators[validator].poolModule != address(0), "VALIDATOR_NOT_EXIST");
        _;
    }

    modifier validatorNotJailed(address validator) {
        require(!validators[validator].jailed, "VALIDATOR_JAILED");
        _;
    }

    modifier onlyOperator(address validator) {
        require(validators[validator].poolModule != address(0), "VALIDATOR_NOT_EXIST");
        if (msg.sender != validator) {
            require(msg.sender == validators[validator].operatorAddress, "NOT_OPERATOR");
        }
        _;
    }

    modifier whenNotPaused() {
        require(!_stakingPaused, "STAKE_STOPPED");
        _;
    }

    /*----------------- init -----------------*/
    function initialize() public {
        transferGasLimit = INIT_TRANSFER_GAS_LIMIT;

        minSelfDelegationBNB = INIT_MIN_SELF_DELEGATION_BNB;
        minDelegationBNBChange = INIT_MIN_DELEGATION_BNB_CHANGE;
        maxElectedValidators = INIT_MAX_ELECTED_VALIDATORS;
        unbondPeriod = INIT_UNBOND_PERIOD;
        downtimeSlashAmount = INIT_DOWNTIME_SLASH_AMOUNT;
        doubleSignSlashAmount = INIT_DOUBLE_SIGN_SLASH_AMOUNT;
        downtimeJailTime = INIT_DOWNTIME_JAIL_TIME;
        doubleSignJailTime = INIT_DOUBLE_SIGN_JAIL_TIME;

        _initialized = 1;
    }

    /*----------------- external functions -----------------*/
    function createValidator(address consensusAddress, bytes calldata voteAddress, bytes calldata blsProof, Commission calldata commission, Description calldata description) external payable onlyInitialized {
        uint256 delegation = msg.value;
        require(delegation >= minSelfDelegationBNB, "INVALID_SELF_DELEGATION");
        require(validators[consensusAddress].poolModule == address(0), "ALREADY_VALIDATOR");
        require(voteAddressToValidator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(commission.rate <= commission.maxRate, "INVALID_COMMISSION_RATE");
        require(commission.maxChangeRate <= commission.maxRate, "INVALID_MAX_CHANGE_RATE");

        // check vote address
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        voteAddressToValidator[voteAddress] = consensusAddress;

        // deploy stake pool
        address poolModule = _deployStakePool(consensusAddress);

        Validator storage valInfo = validators[consensusAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = msg.sender;
        valInfo.poolModule = poolModule;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;

        // update eligible validators
        _updateEligibleValidators(consensusAddress, voteAddress);
    }

    function editOperator(address validator, address newOperator) external onlyInitialized onlyOperator(validator) {
        require(newOperator != address(0), "INVALID_OPERATOR");
        Validator storage valInfo = validators[validator];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        valInfo.operatorAddress = newOperator;
        valInfo.updateTime = block.timestamp;
    }

    function editDescription(address validator, Description calldata description) external onlyInitialized onlyOperator(validator) {
        Validator storage valInfo = validators[msg.sender];

        valInfo.description = description;
        valInfo.updateTime = block.timestamp;
    }

    function editVoteAddress(address validator, bytes calldata voteAddress, bytes calldata blsProof) external onlyInitialized onlyOperator(validator) {
        Validator storage valInfo = validators[msg.sender];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(voteAddressToValidator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        voteAddressToValidator[voteAddress] = msg.sender;
        valInfo.voteAddress = voteAddress;
        valInfo.updateTime = block.timestamp;
    }

    function editCommissionRate(address validator, uint256 commissionRate) external onlyInitialized validatorExist(validator) {
        Validator storage valInfo = validators[msg.sender];
        require(valInfo.updateTime + 1 days <= block.timestamp, "UPDATE_TOO_FREQUENTLY");
        require(commissionRate <= valInfo.commission.maxRate, "INVALID_COMMISSION_RATE");

        if (commissionRate > valInfo.commission.rate) {
            require(commissionRate - valInfo.commission.rate <= valInfo.commission.maxChangeRate, "INVALID_MAX_CHANGE_RATE");
        } else {
            require(valInfo.commission.rate - commissionRate <= valInfo.commission.maxChangeRate, "INVALID_MAX_CHANGE_RATE");
        }

        valInfo.commission.rate = commissionRate;
        valInfo.updateTime = block.timestamp;
    }

    function unjail(address validator) public onlyInitialized validatorExist(validator) {
        Validator storage valInfo = validators[validator];
        require(valInfo.jailed, "NOT_JAILED");

        address pool = valInfo.poolModule;
        require(IStakePool(pool).getSelfDelegationBNB() >= doubleSignSlashAmount, "NOT_ENOUGH_SELF_DELEGATION");
        require(valInfo.jailUntil <= block.timestamp, "STILL_JAILED");

        valInfo.jailed = false;
    }

    function delegate(address validator) external payable onlyInitialized validatorExist(validator) validatorNotJailed(validator) whenNotPaused {
        uint256 _bnbAmount = msg.value;
        require(_bnbAmount >= minDelegationBNBChange, "INVALID_DELEGATION_AMOUNT");
        address delegator = msg.sender;
        Validator memory valInfo = validators[validator];
        if (IStakePool(valInfo.poolModule).getSelfDelegation() < minSelfDelegationBNB) {
            // only self delegation
            require(delegator == validator, "ONLY_SELF_DELEGATION");
        }

        _updateEligibleValidators(validator, valInfo.voteAddress);
    }

    function undelegate(address validator, uint256 _sharesAmount) public onlyInitialized validatorExist(validator) whenNotPaused {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory valInfo = validators[validator];

        if (delegator == validator && IStakePool(valInfo.poolModule).getSelfDelegationBNB() < doubleSignSlashAmount) {
            validators[validator].jailed = true;
        }

        _updateEligibleValidators(validator, valInfo.voteAddress);
    }

    function redelegate(address srcValidator, address dstValidator, uint256 _sharesAmount) public onlyInitialized validatorExist(srcValidator) validatorExist(dstValidator) validatorNotJailed(dstValidator) whenNotPaused {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator memory srcValInfo = validators[srcValidator];
        Validator memory dstValInfo = validators[dstValidator];

        uint256 _bnbAmount = IStakePool(srcValInfo.poolModule).redelegate(delegator, _sharesAmount);
        IStakePool(dstValInfo.poolModule).delegate{value: _bnbAmount}(delegator);

        bytes memory srcValVoteAddr = srcValInfo.voteAddress;
        bytes memory dstValVoteAddr = dstValInfo.voteAddress;
        _updateEligibleValidators(srcValidator, srcValVoteAddr);
        _updateEligibleValidators(dstValidator, dstValVoteAddr);
    }

    function claim(address validator, uint256 requestNumber) external onlyInitialized validatorExist(validator) {
        IStakePool(validators[validator].poolModule).claim(msg.sender, requestNumber);
    }

    /*----------------- system functions -----------------*/
    function distributeReward(address validator) external payable onlyInitialized onlyValidatorContract validatorNotJailed(validator) {
        IStakePool(validators[validator].poolModule).distributeReward{value: msg.value}();
    }

    function getEligibleValidators() external view returns (IBSCValidatorSet.Validator[] memory, bytes[] memory) {
        return (eligibleValidators, eligibleValidatorVoteAddrs);
    }

    function downtimeSlash(address validator, uint256 height) external onlyInitialized onlySlash {
        Validator storage valInfo = validators[validator];

        // check slash record
        bytes32 slashKey = _getSlashKey(validator, height, SlashType.DownTime);
        SlashRecord storage record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(downtimeSlashAmount);
        valInfo.jailed = true;

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = height;
        record.jailUntil = block.timestamp + downtimeJailTime;
        record.slashType = SlashType.DownTime;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }
    }

    function maliciousVoteSlash(bytes calldata voteAddr, uint256 height) external onlyInitialized onlySlash {
        address validator = _getValidatorByVoteAddr(voteAddr);
        Validator storage valInfo = validators[validator];

        // check slash record
        bytes32 slashKey = _getSlashKey(validator, height, SlashType.MaliciousVote);
        SlashRecord storage record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = height;
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashType = SlashType.MaliciousVote;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }
    }

    function doubleSignSlash(address validator, uint256 height) external onlyInitialized onlySlash {
        Validator storage valInfo = validators[validator];

        // check slash record
        bytes32 slashKey = _getSlashKey(validator, height, SlashType.DoubleSign);
        SlashRecord storage record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.jailed = true;

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = height;
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashType = SlashType.MaliciousVote;

        if (valInfo.jailUntil < record.jailUntil) {
            valInfo.jailUntil = record.jailUntil;
        }
    }

    function lockToGovernance(address validator, address from, uint256 _sharesAmount) external onlyInitialized onlyGovernance validatorExist(validator) validatorNotJailed(validator) returns (uint256) {
        address pool = validators[validator].poolModule;

        return IStakePool(pool).lockToGovernance(from, _sharesAmount);
    }

    /*----------------- gov -----------------*/
    function pauseStaking() external onlyInitialized onlyGov {
        _stakingPaused = true;
    }

    function resumeStaking() external onlyInitialized onlyGov {
        _stakingPaused = false;
    }

    function updateParam(string calldata key, bytes calldata value) external onlyInitialized onlyGov {
        // TODO: add all params
        if (_compareStrings(key, "minSelfDelegationBNB")) {
            require(value.length == 32, "length of expireTimeSecondGap mismatch");
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

    function isValidatorActive(address validator) external view validatorExist(validator) returns (bool) {
        return !validators[validator].jailed;
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
        return voteAddressToValidator[voteAddr];
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

    function _updateEligibleValidators(address validator, bytes memory voteAddress) internal {
        uint256 delegation = IStakePool(validators[validator].poolModule).balanceOf(validator);
        if (eligibleValidators.length > maxElectedValidators) {
            for (uint256 i = maxElectedValidators; i < eligibleValidators.length; ++i) {
                delete eligibleValidators[i];
                delete eligibleValidatorDelegatedAmounts[i];
                delete eligibleValidatorVoteAddrs[i];
            }
        } else if (eligibleValidators.length < maxElectedValidators) {
            eligibleValidators.push(IBSCValidatorSet.Validator({consensusAddress: address(0), feeAddress: payable(0), BBCFeeAddress: payable(0), votingPower: 0, jailed: false, incoming: 0}));
            eligibleValidatorDelegatedAmounts.push(0);
            eligibleValidatorVoteAddrs.push(bytes(""));
        }

        for (uint256 i; i < eligibleValidators.length; ++i) {
            if (delegation > eligibleValidatorDelegatedAmounts[i]) {
                uint256 endIdx = eligibleValidators.length - 1;
                for (uint256 j = i; j < eligibleValidators.length; ++j) {
                    if (eligibleValidators[j].consensusAddress == validator) {
                        endIdx = j;
                        break;
                    }
                }
                for (uint256 k = endIdx; k > i; --k) {
                    eligibleValidators[k] = eligibleValidators[k - 1];
                    eligibleValidatorDelegatedAmounts[k] = eligibleValidatorDelegatedAmounts[k - 1];
                    eligibleValidatorVoteAddrs[k] = eligibleValidatorVoteAddrs[k - 1];
                }
                eligibleValidators[i] = IBSCValidatorSet.Validator({consensusAddress: validator, feeAddress: payable(0), BBCFeeAddress: payable(0), votingPower: uint64(delegation), jailed: false, incoming: 0});
                eligibleValidatorDelegatedAmounts[i] = delegation;
                eligibleValidatorVoteAddrs[i] = voteAddress;
                break;
            }
        }
    }
}
