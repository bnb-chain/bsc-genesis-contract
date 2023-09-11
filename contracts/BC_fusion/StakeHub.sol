// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./System.sol";

interface IBSCValidatorSet {
    struct Validator {
        address consensusAddress;
        address payable feeAddress;
        address BBCFeeAddress;
        uint64 votingPower;
        // only in state
        bool jailed;
        uint256 incoming;
    }
}

interface IStakePool {
    function balanceOf(address delegator) external view returns (uint256);
    function getPooledBNBByShares(uint256 sharesAmount) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function delegate(address delegator) external payable returns (uint256);
    function undelegate(address delegator, uint256 sharesAmount) external returns (uint256);
    function redelegate(address delegator, uint256 sharesAmount) external returns (uint256);
    function distributeReward() external payable;
    function slash(uint256 slashBnbAmount) external returns (uint256);
}

contract StakeHub is System, Initializable {
    /*----------------- constant -----------------*/
    uint256 public constant INIT_MIN_SELF_DELEGATION = 2000 ether;
    uint256 public constant INIT_MIN_DELEGATION_CHANGE = 1 ether;
    uint256 public constant INIT_MAX_ELECTED_VALIDATORS = 29;
    uint256 public constant INIT_DOWNTIME_SLASH_AMOUNT = 50 ether;
    uint256 public constant INIT_DOUBLE_SIGN_SLASH_AMOUNT = 10_000 ether;
    uint256 public constant INIT_DOWNTIME_JAIL_TIME = 172_800_000_000_000;
    uint256 public constant INIT_DOUBLE_SIGN_JAIL_TIME = 9_223_372_036_854_775_807;

    uint256 public constant BLS_PUBKEY_LENGTH = 48;
    uint256 public constant BLS_SIG_LENGTH = 96;

    /*----------------- storage -----------------*/
    uint8 private _initialized;
    bool private _stakingPaused;

    // stake params
    uint256 public minSelfDelegation;
    uint256 public minDelegationChange;
    uint256 public maxElectedValidators;

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
        bool jailed;
        address poolModule; // staking pool
        uint256 totalPooledBNB;
        uint256 totalShares;
        bytes voteAddress;
        Description description;
        Commission commission;
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
    //uint256 updateTime;

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

    /*----------------- modifiers -----------------*/
    modifier onlyInitialized() {
        require(_initialized != 0, "NOT_INITIALIZED");
        _;
    }

    modifier validatorExist(address validator) {
        require(validators[validator].poolModule != address(0), "VALIDATOR_NOT_EXIST");
        _;
    }

    /*----------------- init -----------------*/
    function initialize() public initializer {
        minSelfDelegation = INIT_MIN_SELF_DELEGATION;
        minDelegationChange = INIT_MIN_DELEGATION_CHANGE;
        maxElectedValidators = INIT_MAX_ELECTED_VALIDATORS;
        downtimeSlashAmount = INIT_DOWNTIME_SLASH_AMOUNT;
        doubleSignSlashAmount = INIT_DOUBLE_SIGN_SLASH_AMOUNT;
        downtimeJailTime = INIT_DOWNTIME_JAIL_TIME;
        doubleSignJailTime = INIT_DOUBLE_SIGN_JAIL_TIME;

        _initialized = 1;
    }

    /*----------------- external functions -----------------*/
    function createValidator(bytes calldata voteAddress, bytes calldata blsProof, Commission calldata commission, Description calldata description) external payable onlyInitialized {
        uint256 delegation = msg.value;
        require(delegation >= minSelfDelegation, "INVALID_SELF_DELEGATION");
        address validator = msg.sender;
        require(validators[validator].poolModule == address(0), "ALREADY_VALIDATOR");
        require(voteAddressToValidator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");
        require(commission.rate <= commission.maxRate, "INVALID_COMMISSION_RATE");
        require(commission.maxChangeRate <= commission.maxRate, "INVALID_MAX_CHANGE_RATE");

        // check vote address
        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        voteAddressToValidator[voteAddress] = validator;

        // deploy stake pool
        address poolModule = _deployStakePool(validator);
        totalPooledBNB += delegation;

        Validator storage valInfo = validators[validator];
        valInfo.consensusAddress = validator;
        valInfo.poolModule = poolModule;
        valInfo.totalPooledBNB = delegation;
        valInfo.totalShares = delegation;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;

        // update eligible validators
        _updateEligibleValidators(validator, delegation, voteAddress);
    }

    function editDescription(Description calldata description) external onlyInitialized validatorExist(msg.sender) {
        Validator storage valInfo = validators[msg.sender];
        valInfo.description = description;
    }

    function editVoteAddress(bytes calldata voteAddress, bytes calldata blsProof) external onlyInitialized validatorExist(msg.sender) {
        Validator storage valInfo = validators[msg.sender];
        require(voteAddressToValidator[voteAddress] == address(0), "DUPLICATE_VOTE_ADDRESS");

        require(_checkVoteAddress(voteAddress, blsProof), "INVALID_VOTE_ADDRESS");
        voteAddressToValidator[voteAddress] = msg.sender;
        valInfo.voteAddress = voteAddress;
    }

    function editCommissionRate(uint256 commissionRate) external onlyInitialized validatorExist(msg.sender) {
        Validator storage valInfo = validators[msg.sender];
        require(commissionRate <= valInfo.commission.maxRate, "INVALID_COMMISSION_RATE");

        if (commissionRate > valInfo.commission.rate) {
            require(commissionRate - valInfo.commission.rate <= valInfo.commission.maxChangeRate, "INVALID_MAX_CHANGE_RATE");
        } else {
            require(valInfo.commission.rate - commissionRate <= valInfo.commission.maxChangeRate, "INVALID_MAX_CHANGE_RATE");
        }

        valInfo.commission.rate = commissionRate;
    }

    function delegate(address validator) external payable onlyInitialized validatorExist(validator) {
        uint256 _bnbAmount = msg.value;
        require(_bnbAmount >= minDelegationChange, "INVALID_DELEGATION_AMOUNT");
        address delegator = msg.sender;
        Validator storage valInfo = validators[validator];
        address pool = valInfo.poolModule;
        if (valInfo.jailed || IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(validator)) < doubleSignSlashAmount) {
            // only self delegation
            require(delegator == validator, "ONLY_SELF_DELEGATION");
        }

        uint256 _shares = IStakePool(pool).delegate{value: _bnbAmount}(delegator);
        valInfo.totalShares += _shares;
        valInfo.totalPooledBNB += _bnbAmount;
        totalPooledBNB += _bnbAmount;

        _updateEligibleValidators(validator, valInfo.totalPooledBNB, valInfo.voteAddress);
    }

    function undelegate(address validator, uint256 _sharesAmount) public onlyInitialized validatorExist(validator) {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator storage valInfo = validators[validator];
        address pool = valInfo.poolModule;

        uint256 _bnbAmount = IStakePool(pool).undelegate(delegator, _sharesAmount);
        valInfo.totalShares -= _sharesAmount;
        valInfo.totalPooledBNB -= _bnbAmount;
        totalPooledBNB -= _bnbAmount;

        bytes memory voteAddr = valInfo.voteAddress;
        _updateEligibleValidators(validator, valInfo.totalPooledBNB, voteAddr);
    }

    function redelegate(address srcValidator, address dstValidator, uint256 _sharesAmount) public onlyInitialized validatorExist(srcValidator) validatorExist(dstValidator) {
        require(_sharesAmount > 0, "INVALID_SHARES_AMOUNT");

        address delegator = msg.sender;
        Validator storage srcValInfo = validators[srcValidator];
        Validator storage dstValInfo = validators[dstValidator];
        address srcPool = srcValInfo.poolModule;
        address dstPool = dstValInfo.poolModule;

        uint256 _bnbAmount = IStakePool(srcPool).redelegate(delegator, _sharesAmount);
        uint256 _newSharesAmount = IStakePool(dstPool).delegate{value: _bnbAmount}(delegator);

        srcValInfo.totalShares -= _sharesAmount;
        srcValInfo.totalPooledBNB -= _bnbAmount;
        dstValInfo.totalShares += _newSharesAmount;
        dstValInfo.totalPooledBNB += _bnbAmount;

        bytes memory srcValVoteAddr = srcValInfo.voteAddress;
        bytes memory dstValVoteAddr = dstValInfo.voteAddress;
        _updateEligibleValidators(srcValidator, srcValInfo.totalPooledBNB, srcValVoteAddr);
        _updateEligibleValidators(dstValidator, dstValInfo.totalPooledBNB, dstValVoteAddr);
    }

    /*----------------- system functions -----------------*/
    function distributeReward(address validator) external payable onlyInitialized onlyValidatorContract {
        Validator storage valInfo = validators[validator];
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        valInfo.totalPooledBNB += msg.value;
        totalPooledBNB += msg.value;

        IStakePool(valInfo.poolModule).distributeReward{value: msg.value}();
    }

    function getEligibleValidators() external view returns (IBSCValidatorSet.Validator[] memory, bytes[] memory) {
        return (eligibleValidators, eligibleValidatorVoteAddrs);
    }

    function downtimeSlash(address validator) external onlyInitialized onlySlash {
        Validator storage valInfo = validators[validator];
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        // check slash record
        bytes32 slashKey = _getSlashKey(validator, block.number, SlashType.DownTime);
        SlashRecord memory record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(downtimeSlashAmount);
        valInfo.totalPooledBNB -= slashAmount;
        valInfo.jailed = true;

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = block.number;
        record.jailUntil = block.timestamp + downtimeJailTime;
        record.slashType = SlashType.DownTime;
        slashRecords[slashKey] = record;
    }

    function maliciousVoteSlash(bytes calldata voteAddr) external onlyInitialized onlySlash {
        address validator = _getValidatorByVoteAddr(voteAddr);
        Validator storage valInfo = validators[validator];
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        // check slash record
        bytes32 slashKey = _getSlashKey(validator, block.number, SlashType.MaliciousVote);
        SlashRecord memory record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.totalPooledBNB -= slashAmount;
        valInfo.jailed = true;

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = block.number;
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashType = SlashType.MaliciousVote;
        slashRecords[slashKey] = record;
    }

    function doubleSignSlash(address validator) external onlyInitialized onlySlash {
        Validator storage valInfo = validators[validator];
        require(!valInfo.jailed, "VALIDATOR_JAILED");

        // check slash record
        bytes32 slashKey = _getSlashKey(validator, block.number, SlashType.DoubleSign);
        SlashRecord memory record = slashRecords[slashKey];
        require(record.slashHeight == 0, "SLASHED");

        // slash
        uint256 slashAmount = IStakePool(valInfo.poolModule).slash(doubleSignSlashAmount);
        valInfo.totalPooledBNB -= slashAmount;
        valInfo.jailed = true;

        // record
        record.slashAmount = slashAmount;
        record.slashHeight = block.number;
        record.jailUntil = block.timestamp + doubleSignJailTime;
        record.slashType = SlashType.MaliciousVote;
        slashRecords[slashKey] = record;
    }

    /*----------------- gov -----------------*/
    function pauseStaking() external onlyInitialized onlyGov {
        _stakingPaused = true;
    }

    function resumeStaking() external onlyInitialized onlyGov {
        _stakingPaused = false;
    }

    // TODO
    // update params

    /*----------------- view functions -----------------*/
    function getValidatorByVoteAddr(bytes calldata voteAddr) external view returns (address) {
        return _getValidatorByVoteAddr(voteAddr);
    }

    function isPaused() external view returns (bool) {
        return _stakingPaused;
    }

    /*----------------- internal functions -----------------*/
    function _getValidatorByVoteAddr(bytes calldata voteAddr) internal view returns (address) {
        return voteAddressToValidator[voteAddr];
    }

    function _getSlashKey(address valAddr, uint256 height, SlashType slashType) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(valAddr, height, slashType));
    }

    function _bytesConcat(bytes memory data, bytes memory _bytes, uint256 index, uint256 len) internal pure {
        for (uint i; i<len; ++i) {
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
            if iszero(staticcall(not(0), 0x66, add(input, 0x20), len, add(output, 0x20), 0x01)) {
                revert(0, 0)
            }
        }
        uint8 result = uint8(output[0]);
        if (result != uint8(1)) {
            return false;
        }
        return true;
    }

    function _deployStakePool(address validator) internal returns (address) {
        // TODO
        return address(0);
    }

    function _updateEligibleValidators(address validator, uint256 delegation, bytes memory voteAddress) internal {
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
