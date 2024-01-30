// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./System.sol";
import "./lib/Utils.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/ICrossChain.sol";
import "./interface/IGovToken.sol";
import "./interface/IStakeCredit.sol";
import "./interface/ITokenHub.sol";
import "./lib/RLPDecode.sol";

contract StakeHub is System, Initializable {
    using RLPDecode for *;
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constants -----------------*/
    uint256 private constant BLS_PUBKEY_LENGTH = 48;
    uint256 private constant BLS_SIG_LENGTH = 96;

    address public constant DEAD_ADDRESS = address(0xdEaD);
    uint256 public constant LOCK_AMOUNT = 1 ether;
    uint256 public constant REDELEGATE_FEE_RATE_BASE = 10000; // 100%

    uint256 public constant BREATHE_BLOCK_INTERVAL = 1 days;

    //TODO: set to the correct bytes of abi.encode({{BCExistingConsensusAddresses}}) and abi.encode({{BCExistingVoteAddresses}}) when landing on mainnet and testnet
    // this will be set to proper value after the first sunset hardfork on Beacon Chain
    bytes private constant INIT_BC_CONSENSUS_ADDRESSES =
        hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000";
    bytes private constant INIT_BC_VOTE_ADDRESSES =
        hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000";

    /*----------------- errors -----------------*/
    // @notice signature: 0xd7485e8f
    error StakeHubPaused();
    // @notice signature: 0xb1d02c3d
    error InBlackList();
    // @notice signature: 0xf2771a99
    error OnlyAssetProtector();
    // @notice signature: 0x5f28f62b
    error ValidatorExisted();
    // @notice signature: 0xfdf4600b
    error ValidatorNotExist();
    // @notice signature: 0x4b6b857d
    error ValidatorNotJailed();
    // @notice signature: 0x3cdeb0ea
    error DuplicateConsensusAddress();
    // @notice signature: 0x11fdb947
    error DuplicateVoteAddress();
    // @notice signature: 0xc0bf4143
    error DuplicateMoniker();
    // @notice signature: 0x2f64097e
    error SelfDelegationNotEnough();
    // @notice signature: 0xdc81db85
    error InvalidCommission();
    // @notice signature: 0x5dba5ad7
    error InvalidMoniker();
    // @notice signature: 0x2c8fc796
    error InvalidVoteAddress();
    // @notice signature: 0xca40c236
    error InvalidConsensusAddress();
    // @notice signature: 0x3f259b7a
    error UpdateTooFrequently();
    // @notice signature: 0x5c32dd9c
    error JailTimeNotExpired();
    // @notice signature: 0xdc6f0bdd
    error DelegationAmountTooSmall();
    // @notice signature: 0x64689203
    error OnlySelfDelegation();
    // @notice signature: 0x9811e0c7
    error ZeroShares();
    // @notice signature: 0xf0e3e629
    error SameValidator();
    // @notice signature: 0xbd52fcdb
    error NoMoreFelonyAllowed();
    // @notice signature: 0x37233762
    error AlreadySlashed();
    // @notice signature: 0x90b8ec18
    error TransferFailed();
    // @notice signature: 0x41abc801
    error InvalidRequest();
    // @notice signature: 0x1898eb6b
    error VoteAddressExpired();
    // @notice signature: 0xc2aee074
    error ConsensusAddressExpired();
    // @notice signature: 0x0d7b78d4
    error InvalidSynPackage();

    /*----------------- storage -----------------*/
    bool private _paused;
    uint8 private _isReceivingFund;
    uint256 public transferGasLimit;

    // stake params
    uint256 public minSelfDelegationBNB;
    uint256 public minDelegationBNBChange;
    uint256 public maxElectedValidators;
    uint256 public unbondPeriod;
    uint256 public redelegateFeeRate;

    // slash params
    uint256 public downtimeSlashAmount;
    uint256 public felonySlashAmount;
    uint256 public downtimeJailTime;
    uint256 public felonyJailTime;

    // validator operator address set
    EnumerableSet.AddressSet private _validatorSet;
    // validator operator address => validator info
    mapping(address => Validator) private _validators;
    // validator moniker set(hash of the moniker)
    mapping(bytes32 => bool) private _monikerSet;
    // validator consensus address => validator operator address
    mapping(address => address) public consensusToOperator;
    // validator consensus address => expiry date
    mapping(address => uint256) public consensusExpiration;
    // validator vote address => validator operator address
    mapping(bytes => address) public voteToOperator;
    // validator vote address => expiry date
    mapping(bytes => uint256) public voteExpiration;

    // legacy addresses of BC
    mapping(address => bool) private _legacyConsensusAddress;
    mapping(bytes => bool) private _legacyVoteAddress;

    // total number of current jailed validators
    uint256 public numOfJailed;
    // max number of jailed validators between breathe block(only for malicious vote and double sign)
    uint256 public maxFelonyBetweenBreatheBlock;
    // index(timestamp / breatheBlockInterval) => number of malicious vote and double sign slash
    mapping(uint256 => uint256) private _felonyMap;
    // slash key => slash jail time
    mapping(bytes32 => uint256) private _felonyRecords;

    address public assetProtector;
    mapping(address => bool) public blackList;

    /*----------------- structs and events -----------------*/
    struct StakeMigrationPackage {
        address operatorAddress; // the operator address of the target validator to delegate to
        address delegator; // the beneficiary of the delegation
        address refundAddress; // the Beacon Chain address to refund the fund if migration failed
        uint256 amount; // the amount of BNB to be migrated(decimal: 18)
    }

    enum StakeMigrationRespCode {
        MIGRATE_SUCCESS,
        CLAIM_FUND_FAILED,
        VALIDATOR_NOT_EXISTED,
        VALIDATOR_JAILED
    }

    struct Validator {
        address consensusAddress;
        address operatorAddress;
        address creditContract;
        uint256 createdTime;
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

    enum SlashType {
        DoubleSign,
        DownTime,
        MaliciousVote
    }

    event ValidatorCreated(
        address indexed consensusAddress,
        address indexed operatorAddress,
        address indexed creditContract,
        bytes voteAddress
    );
    event StakeCreditInitialized(address indexed operatorAddress, address indexed creditContract);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint64 newCommissionRate);
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
        address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, SlashType slashType
    );
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorEmptyJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event Paused();
    event Resumed();
    event MigrateSuccess(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event MigrateFailed(
        address indexed operatorAddress, address indexed delegator, uint256 bnbAmount, StakeMigrationRespCode respCode
    );
    event unexpectedPackage(uint8 channelId, bytes msgBytes);

    /*----------------- modifiers -----------------*/
    modifier validatorExist(address operatorAddress) {
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExist();
        _;
    }

    modifier whenNotPaused() {
        if (_paused) revert StakeHubPaused();
        _;
    }

    modifier onlyAssetProtector() {
        if (msg.sender != assetProtector) revert OnlyAssetProtector();
        _;
    }

    modifier notInBlackList() {
        if (blackList[msg.sender]) revert InBlackList();
        _;
    }

    receive() external payable {
        // to prevent BNB from being lost
        if (_isReceivingFund != 1) revert();
    }

    /**
     * @dev this function is invoked by BSC Parlia consensus engine during the hard fork
     */
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        transferGasLimit = 5000;
        minSelfDelegationBNB = 2_000 ether;
        minDelegationBNBChange = 1 ether;
        maxElectedValidators = 45;
        unbondPeriod = 7 days;
        redelegateFeeRate = 2;
        downtimeSlashAmount = 10 ether;
        felonySlashAmount = 200 ether;
        downtimeJailTime = 2 days;
        felonyJailTime = 30 days;
        maxFelonyBetweenBreatheBlock = 2;

        address[] memory bcConsensusAddress;
        bytes[] memory bcVoteAddress;
        bcConsensusAddress = abi.decode(INIT_BC_CONSENSUS_ADDRESSES, (address[]));
        bcVoteAddress = abi.decode(INIT_BC_VOTE_ADDRESSES, (bytes[]));
        for (uint256 i; i < bcConsensusAddress.length; ++i) {
            _legacyConsensusAddress[bcConsensusAddress[i]] = true;
        }
        for (uint256 i; i < bcVoteAddress.length; ++i) {
            _legacyVoteAddress[bcVoteAddress[i]] = true;
        }

        // TODO
        // Different address will be set depending on the environment
        assetProtector = DEAD_ADDRESS;
    }

    /*----------------- Implement cross chain app -----------------*/
    function handleSynPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract returns (bytes memory) {
        (StakeMigrationPackage memory migrationPkg, bool decodeSuccess) = _decodeMigrationSynPackage(msgBytes);
        if (!decodeSuccess) revert InvalidSynPackage();

        if (migrationPkg.amount == 0) {
            return new bytes(0);
        }

        // claim fund from TokenHub
        _isReceivingFund = 1;
        bool claimSuccess = ITokenHub(TOKEN_HUB_ADDR).claimMigrationFund(migrationPkg.amount);
        if (!claimSuccess) {
            emit MigrateFailed(
                migrationPkg.operatorAddress,
                migrationPkg.delegator,
                migrationPkg.amount,
                StakeMigrationRespCode.CLAIM_FUND_FAILED
            );
            _isReceivingFund = 0;
            return msgBytes;
        }
        _isReceivingFund = 0;

        StakeMigrationRespCode respCode = _doMigration(migrationPkg);

        if (respCode == StakeMigrationRespCode.MIGRATE_SUCCESS) {
            return new bytes(0);
        } else {
            emit MigrateFailed(migrationPkg.operatorAddress, migrationPkg.delegator, migrationPkg.amount, respCode);
            return msgBytes;
        }
    }

    function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract {
        // should not happen
        emit unexpectedPackage(channelId, msgBytes);
    }

    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract {
        // should not happen
        emit unexpectedPackage(channelId, msgBytes);
    }

    /*----------------- external functions -----------------*/
    /**
     * @param consensusAddress the consensus address of the validator
     * @param voteAddress the vote address of the validator
     * @param blsProof the bls proof of the vote address
     * @param commission the commission of the validator
     * @param description the description of the validator
     */
    function createValidator(
        address consensusAddress,
        bytes calldata voteAddress,
        bytes calldata blsProof,
        Commission calldata commission,
        Description calldata description
    ) external payable whenNotPaused notInBlackList {
        // basic check
        address operatorAddress = msg.sender;
        if (_validatorSet.contains(operatorAddress)) revert ValidatorExisted();
        if (consensusToOperator[consensusAddress] != address(0) || _legacyConsensusAddress[consensusAddress]) {
            revert DuplicateConsensusAddress();
        }
        if (voteToOperator[voteAddress] != address(0) || _legacyVoteAddress[voteAddress]) {
            revert DuplicateVoteAddress();
        }
        bytes32 monikerHash = keccak256(abi.encodePacked(description.moniker));
        if (_monikerSet[monikerHash]) revert DuplicateMoniker();

        uint256 delegation = msg.value;
        if (delegation < minSelfDelegationBNB + LOCK_AMOUNT) revert SelfDelegationNotEnough();

        if (consensusAddress == address(0)) revert InvalidConsensusAddress();
        if (
            commission.maxRate > 5_000 || commission.rate > commission.maxRate
                || commission.maxChangeRate > commission.maxRate
        ) revert InvalidCommission();
        if (!_checkMoniker(description.moniker)) revert InvalidMoniker();
        // proof-of-possession verify
        if (!_checkVoteAddress(voteAddress, blsProof)) revert InvalidVoteAddress();

        // deploy stake credit proxy contract
        address creditContract = _deployStakeCredit(operatorAddress, description.moniker);

        _validatorSet.add(operatorAddress);
        _monikerSet[monikerHash] = true;
        Validator storage valInfo = _validators[operatorAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = operatorAddress;
        valInfo.creditContract = creditContract;
        valInfo.createdTime = block.timestamp;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;
        consensusToOperator[consensusAddress] = operatorAddress;
        voteToOperator[voteAddress] = operatorAddress;

        emit ValidatorCreated(consensusAddress, operatorAddress, creditContract, voteAddress);
        emit Delegated(operatorAddress, operatorAddress, delegation, delegation);

        IGovToken(GOV_TOKEN_ADDR).sync(creditContract, operatorAddress);
    }

    /**
     * @param newConsensusAddress the new consensus address of the validator
     */
    function editConsensusAddress(address newConsensusAddress)
        external
        whenNotPaused
        notInBlackList
        validatorExist(msg.sender)
    {
        if (newConsensusAddress == address(0)) revert InvalidConsensusAddress();
        if (consensusToOperator[newConsensusAddress] != address(0) || _legacyConsensusAddress[newConsensusAddress]) {
            revert DuplicateConsensusAddress();
        }

        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        consensusExpiration[valInfo.consensusAddress] = block.timestamp;
        valInfo.consensusAddress = newConsensusAddress;
        valInfo.updateTime = block.timestamp;
        consensusToOperator[newConsensusAddress] = operatorAddress;

        emit ConsensusAddressEdited(operatorAddress, newConsensusAddress);
    }

    /**
     * @param commissionRate the new commission rate of the validator
     */
    function editCommissionRate(uint64 commissionRate)
        external
        whenNotPaused
        notInBlackList
        validatorExist(msg.sender)
    {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        if (commissionRate > valInfo.commission.maxRate) revert InvalidCommission();
        uint256 changeRate = commissionRate >= valInfo.commission.rate
            ? commissionRate - valInfo.commission.rate
            : valInfo.commission.rate - commissionRate;
        if (changeRate > valInfo.commission.maxChangeRate) revert InvalidCommission();

        valInfo.commission.rate = commissionRate;
        valInfo.updateTime = block.timestamp;

        emit CommissionRateEdited(operatorAddress, commissionRate);
    }

    /**
     * @notice the moniker of the validator will be ignored as it is not editable
     * @param description the new description of the validator
     */
    function editDescription(Description memory description)
        external
        whenNotPaused
        notInBlackList
        validatorExist(msg.sender)
    {
        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        description.moniker = valInfo.description.moniker;
        valInfo.description = description;
        valInfo.updateTime = block.timestamp;

        emit DescriptionEdited(operatorAddress);
    }

    /**
     * @param newVoteAddress the new vote address of the validator
     * @param blsProof the bls proof of the vote address
     */
    function editVoteAddress(
        bytes calldata newVoteAddress,
        bytes calldata blsProof
    ) external whenNotPaused notInBlackList validatorExist(msg.sender) {
        // proof-of-possession verify
        if (!_checkVoteAddress(newVoteAddress, blsProof)) revert InvalidVoteAddress();
        if (voteToOperator[newVoteAddress] != address(0) || _legacyVoteAddress[newVoteAddress]) {
            revert DuplicateVoteAddress();
        }

        address operatorAddress = msg.sender;
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        voteExpiration[valInfo.voteAddress] = block.timestamp;
        valInfo.voteAddress = newVoteAddress;
        valInfo.updateTime = block.timestamp;
        voteToOperator[newVoteAddress] = operatorAddress;

        emit VoteAddressEdited(operatorAddress, newVoteAddress);
    }

    /**
     * @param operatorAddress the operator address of the validator to be unjailed
     */
    function unjail(address operatorAddress) external whenNotPaused notInBlackList validatorExist(operatorAddress) {
        Validator storage valInfo = _validators[operatorAddress];
        if (!valInfo.jailed) revert ValidatorNotJailed();

        if (IStakeCredit(valInfo.creditContract).getPooledBNB(operatorAddress) < minSelfDelegationBNB) {
            revert SelfDelegationNotEnough();
        }
        if (valInfo.jailUntil > block.timestamp) revert JailTimeNotExpired();

        valInfo.jailed = false;
        numOfJailed -= 1;
        emit ValidatorUnjailed(operatorAddress);
    }

    /**
     * @param operatorAddress the operator address of the validator to be delegated to
     * @param delegateVotePower whether to delegate vote power to the validator
     */
    function delegate(
        address operatorAddress,
        bool delegateVotePower
    ) external payable whenNotPaused notInBlackList validatorExist(operatorAddress) {
        uint256 bnbAmount = msg.value;
        if (bnbAmount < minDelegationBNBChange) revert DelegationAmountTooSmall();

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        if (valInfo.jailed && delegator != operatorAddress) revert OnlySelfDelegation();

        uint256 shares = IStakeCredit(valInfo.creditContract).delegate{ value: bnbAmount }(delegator);
        emit Delegated(operatorAddress, delegator, shares, bnbAmount);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, delegator);
        if (delegateVotePower) {
            IGovToken(GOV_TOKEN_ADDR).delegateVote(delegator, operatorAddress);
        }
    }

    /**
     * @dev Undelegate BNB from a validator, fund is only claimable few days later
     * @param operatorAddress the operator address of the validator to be undelegated from
     * @param shares the shares to be undelegated
     */
    function undelegate(
        address operatorAddress,
        uint256 shares
    ) external whenNotPaused notInBlackList validatorExist(operatorAddress) {
        if (shares == 0) revert ZeroShares();

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];

        uint256 bnbAmount = IStakeCredit(valInfo.creditContract).undelegate(delegator, shares);
        emit Undelegated(operatorAddress, delegator, shares, bnbAmount);

        if (delegator == operatorAddress) {
            _checkValidatorSelfDelegation(operatorAddress);
        }

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, delegator);
    }

    /**
     * @param srcValidator the operator address of the validator to be redelegated from
     * @param dstValidator the operator address of the validator to be redelegated to
     * @param shares the shares to be redelegated
     * @param delegateVotePower whether to delegate vote power to the dstValidator
     */
    function redelegate(
        address srcValidator,
        address dstValidator,
        uint256 shares,
        bool delegateVotePower
    ) external whenNotPaused notInBlackList validatorExist(srcValidator) validatorExist(dstValidator) {
        if (shares == 0) revert ZeroShares();
        if (srcValidator == dstValidator) revert SameValidator();

        address delegator = msg.sender;
        Validator memory srcValInfo = _validators[srcValidator];
        Validator memory dstValInfo = _validators[dstValidator];
        if (dstValInfo.jailed && delegator != dstValidator) revert OnlySelfDelegation();

        _isReceivingFund = 1;
        uint256 bnbAmount = IStakeCredit(srcValInfo.creditContract).unbond(delegator, shares);
        if (bnbAmount < minDelegationBNBChange) revert DelegationAmountTooSmall();
        // check if the srcValidator has enough self delegation
        if (
            delegator == srcValidator
                && IStakeCredit(srcValInfo.creditContract).getPooledBNB(srcValidator) < minSelfDelegationBNB
        ) {
            revert SelfDelegationNotEnough();
        }

        uint256 feeCharge = bnbAmount * redelegateFeeRate / REDELEGATE_FEE_RATE_BASE;
        (bool success,) = dstValInfo.creditContract.call{ value: feeCharge }("");
        if (!success) revert TransferFailed();

        bnbAmount -= feeCharge;
        uint256 newShares = IStakeCredit(dstValInfo.creditContract).delegate{ value: bnbAmount }(delegator);
        _isReceivingFund = 0;
        emit Redelegated(srcValidator, dstValidator, delegator, shares, newShares, bnbAmount);

        address[] memory stakeCredits = new address[](2);
        stakeCredits[0] = srcValInfo.creditContract;
        stakeCredits[1] = dstValInfo.creditContract;
        IGovToken(GOV_TOKEN_ADDR).syncBatch(stakeCredits, delegator);
        if (delegateVotePower) {
            IGovToken(GOV_TOKEN_ADDR).delegateVote(delegator, dstValidator);
        }
    }

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     * @param operatorAddress the operator address of the validator
     * @param requestNumber the request number of the undelegation. 0 means claim all
     */
    function claim(address operatorAddress, uint256 requestNumber) external whenNotPaused notInBlackList {
        _claim(operatorAddress, requestNumber);
    }

    /**
     * @dev Claim the undelegated BNB from the pools after unbondPeriod
     * @param operatorAddresses the operator addresses of the validator
     * @param requestNumbers numbers of the undelegation requests. 0 means claim all
     */
    function claimBatch(
        address[] calldata operatorAddresses,
        uint256[] calldata requestNumbers
    ) external whenNotPaused notInBlackList {
        if (operatorAddresses.length != requestNumbers.length) revert InvalidRequest();
        for (uint256 i; i < operatorAddresses.length; ++i) {
            _claim(operatorAddresses[i], requestNumbers[i]);
        }
    }

    /**
     * @dev Sync the gov tokens of validators in operatorAddresses
     * @param operatorAddresses the operator addresses of the validators
     * @param account the account to sync gov tokens to
     */
    function syncGovToken(
        address[] calldata operatorAddresses,
        address account
    ) external whenNotPaused notInBlackList {
        uint256 _length = operatorAddresses.length;
        address[] memory stakeCredits = new address[](_length);
        address credit;
        for (uint256 i = 0; i < _length; ++i) {
            if (!_validatorSet.contains(operatorAddresses[i])) revert ValidatorNotExist(); // should never happen
            credit = _validators[operatorAddresses[i]].creditContract;
            stakeCredits[i] = credit;
        }

        IGovToken(GOV_TOKEN_ADDR).syncBatch(stakeCredits, account);
    }

    /*----------------- system functions -----------------*/
    /**
     * @dev This function will be called by consensus engine. So it should never revert.
     */
    function distributeReward(address consensusAddress) external payable onlyValidatorContract {
        address operatorAddress = consensusToOperator[consensusAddress];
        Validator memory valInfo = _validators[operatorAddress];
        if (valInfo.creditContract == address(0) || valInfo.jailed) {
            emit RewardDistributeFailed(operatorAddress, "INVALID_VALIDATOR");
            return;
        }

        IStakeCredit(valInfo.creditContract).distributeReward{ value: msg.value }(valInfo.commission.rate);
        emit RewardDistributed(operatorAddress, msg.value);
    }

    /**
     * @dev Downtime slash. Only the `SlashIndicator` contract can call this function.
     */
    function downtimeSlash(address consensusAddress) external onlySlash {
        address operatorAddress = consensusToOperator[consensusAddress];
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExist(); // should never happen
        Validator storage valInfo = _validators[operatorAddress];

        // slash
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(downtimeSlashAmount);
        uint256 jailUntil = block.timestamp + downtimeJailTime;
        _jailValidator(valInfo, jailUntil);

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, SlashType.DownTime);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @dev Malicious vote slash. Only the `SlashIndicator` contract can call this function.
     */
    function maliciousVoteSlash(bytes calldata voteAddress) external onlySlash whenNotPaused {
        address operatorAddress = voteToOperator[voteAddress];
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExist(); // should never happen
        Validator storage valInfo = _validators[operatorAddress];

        uint256 index = block.timestamp / BREATHE_BLOCK_INTERVAL;
        // This is to prevent many honest validators being slashed at the same time because of implementation bugs
        if (_felonyMap[index] >= maxFelonyBetweenBreatheBlock) revert NoMoreFelonyAllowed();
        _felonyMap[index] += 1;

        // check if the voteAddress has already expired
        if (voteExpiration[voteAddress] != 0 && voteExpiration[voteAddress] + BREATHE_BLOCK_INTERVAL < block.timestamp)
        {
            revert VoteAddressExpired();
        }

        // slash
        (bool canSlash, uint256 jailUntil) = _checkFelonyRecord(operatorAddress, SlashType.MaliciousVote);
        if (!canSlash) revert AlreadySlashed();
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(felonySlashAmount);
        _jailValidator(valInfo, jailUntil);

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, SlashType.MaliciousVote);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @dev Double sign slash. Only the `SlashIndicator` contract can call this function.
     */
    function doubleSignSlash(address consensusAddress) external onlySlash whenNotPaused {
        address operatorAddress = consensusToOperator[consensusAddress];
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExist(); // should never happen
        Validator storage valInfo = _validators[operatorAddress];

        uint256 index = block.timestamp / BREATHE_BLOCK_INTERVAL;
        // This is to prevent many honest validators being slashed at the same time because of implementation bugs
        if (_felonyMap[index] >= maxFelonyBetweenBreatheBlock) revert NoMoreFelonyAllowed();
        _felonyMap[index] += 1;

        // check if the consensusAddress has already expired
        if (
            consensusExpiration[consensusAddress] != 0
                && consensusExpiration[consensusAddress] + BREATHE_BLOCK_INTERVAL < block.timestamp
        ) {
            revert ConsensusAddressExpired();
        }

        // slash
        (bool canSlash, uint256 jailUntil) = _checkFelonyRecord(operatorAddress, SlashType.DoubleSign);
        if (!canSlash) revert AlreadySlashed();
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(felonySlashAmount);
        _jailValidator(valInfo, jailUntil);

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, SlashType.DoubleSign);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @dev Pause the whole system in emergency
     */
    function pause() external onlyAssetProtector {
        _paused = true;
        emit Paused();
    }

    /**
     * @dev Resume the whole system
     */
    function resume() external onlyAssetProtector {
        _paused = false;
        emit Resumed();
    }

    /**
     * @dev Add an address to the black list
     */
    function addToBlackList(address account) external onlyAssetProtector {
        blackList[account] = true;
    }

    /**
     * @dev Remove an address from the black list
     */
    function removeFromBlackList(address account) external onlyAssetProtector {
        blackList[account] = false;
    }

    /**
     * @param key the key of the param
     * @param value the value of the param
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("transferGasLimit")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newTransferGasLimit = value.bytesToUint256(32);
            if (newTransferGasLimit < 2300 || newTransferGasLimit > 10_000) revert InvalidValue(key, value);
            transferGasLimit = newTransferGasLimit;
        } else if (key.compareStrings("minSelfDelegationBNB")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMinSelfDelegationBNB = value.bytesToUint256(32);
            if (newMinSelfDelegationBNB < 1000 ether || newMinSelfDelegationBNB > 100_000 ether) revert InvalidValue(key, value);
            minSelfDelegationBNB = newMinSelfDelegationBNB;
        } else if (key.compareStrings("minDelegationBNBChange")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMinDelegationBNBChange = value.bytesToUint256(32);
            if (newMinDelegationBNBChange < 0.1 ether || newMinDelegationBNBChange > 10 ether) revert InvalidValue(key, value);
            minDelegationBNBChange = newMinDelegationBNBChange;
        } else if (key.compareStrings("maxElectedValidators")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMaxElectedValidators = value.bytesToUint256(32);
            if (newMaxElectedValidators == 0 || newMaxElectedValidators > 500) revert InvalidValue(key, value);
            maxElectedValidators = newMaxElectedValidators;
        } else if (key.compareStrings("unbondPeriod")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newUnbondPeriod = value.bytesToUint256(32);
            if (newUnbondPeriod < 3 days || newUnbondPeriod > 30 days) revert InvalidValue(key, value);
            unbondPeriod = newUnbondPeriod;
        } else if (key.compareStrings("redelegateFeeRate")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newRedelegateFeeRate = value.bytesToUint256(32);
            if (newRedelegateFeeRate > 100) {
                revert InvalidValue(key, value);
            }
            redelegateFeeRate = newRedelegateFeeRate;
        } else if (key.compareStrings("downtimeSlashAmount")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newDowntimeSlashAmount = value.bytesToUint256(32);
            if (newDowntimeSlashAmount < 5 ether || newDowntimeSlashAmount > felonySlashAmount) {
                revert InvalidValue(key, value);
            }
            downtimeSlashAmount = newDowntimeSlashAmount;
        } else if (key.compareStrings("felonySlashAmount")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newFelonySlashAmount = value.bytesToUint256(32);
            if (newFelonySlashAmount < 100 ether || newFelonySlashAmount <= downtimeSlashAmount) {
                revert InvalidValue(key, value);
            }
            felonySlashAmount = newFelonySlashAmount;
        } else if (key.compareStrings("downtimeJailTime")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newDowntimeJailTime = value.bytesToUint256(32);
            if (newDowntimeJailTime < 2 days || newDowntimeJailTime >= felonyJailTime) revert InvalidValue(key, value);
            downtimeJailTime = newDowntimeJailTime;
        } else if (key.compareStrings("felonyJailTime")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newFelonyJailTime = value.bytesToUint256(32);
            if (newFelonyJailTime < 10 days || newFelonyJailTime <= downtimeJailTime) revert InvalidValue(key, value);
            felonyJailTime = newFelonyJailTime;
        } else if (key.compareStrings("maxFelonyBetweenBreatheBlock")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newJailedPerDay = value.bytesToUint256(32);
            if (newJailedPerDay == 0) revert InvalidValue(key, value);
            maxFelonyBetweenBreatheBlock = newJailedPerDay;
        } else if (key.compareStrings("assetProtector")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address newAssetProtector = value.bytesToAddress(20);
            if (newAssetProtector == address(0)) revert InvalidValue(key, value);
            assetProtector = newAssetProtector;
        } else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @return whether the system is paused
     */
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /**
     * @param operatorAddress the operator address of the validator
     * @param index the index of the day to query(timestamp / 1 days)
     *
     * @return the validator's reward of the day
     */
    function getValidatorRewardRecord(address operatorAddress, uint256 index) external view returns (uint256) {
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExist();
        return IStakeCredit(_validators[operatorAddress].creditContract).rewardRecord(index);
    }

    /**
     * @param operatorAddress the operator address of the validator
     * @param index the index of the day to query(timestamp / 1 days)
     *
     * @return the validator's total pooled BNB of the day
     */
    function getValidatorTotalPooledBNBRecord(address operatorAddress, uint256 index) external view returns (uint256) {
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExist();
        return IStakeCredit(_validators[operatorAddress].creditContract).totalPooledBNBRecord(index);
    }

    /**
     * @notice pagination query all validators' operator address and credit contract address
     *
     * @param offset the offset of the query
     * @param limit the limit of the query
     *
     * @return operatorAddrs operator addresses
     * @return creditAddrs credit contract addresses
     * @return totalLength total number of validators
     */
    function getValidators(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory operatorAddrs, address[] memory creditAddrs, uint256 totalLength) {
        totalLength = _validatorSet.length();
        if (offset >= totalLength) {
            return (operatorAddrs, creditAddrs, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        operatorAddrs = new address[](count);
        creditAddrs = new address[](count);
        for (uint256 i; i < count; ++i) {
            operatorAddrs[i] = _validatorSet.at(offset + i);
            creditAddrs[i] = _validators[operatorAddrs[i]].creditContract;
        }
    }

    /**
     * @notice get the basic info of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return consensusAddress the consensus address of the validator
     * @return creditContract the credit contract address of the validator
     * @return createdTime the creation time of the validator
     * @return voteAddress the vote address of the validator
     * @return jailed whether the validator is jailed
     * @return jailUntil the jail time of the validator
     */
    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        validatorExist(operatorAddress)
        returns (
            address consensusAddress,
            address creditContract,
            uint256 createdTime,
            bytes memory voteAddress,
            bool jailed,
            uint256 jailUntil
        )
    {
        Validator memory valInfo = _validators[operatorAddress];
        consensusAddress = valInfo.consensusAddress;
        creditContract = valInfo.creditContract;
        createdTime = valInfo.createdTime;
        voteAddress = valInfo.voteAddress;
        jailed = valInfo.jailed;
        jailUntil = valInfo.jailUntil;
    }

    /**
     * @param operatorAddress the operator address of the validator
     *
     * @return the description of a validator
     */
    function getValidatorDescription(address operatorAddress)
        external
        view
        validatorExist(operatorAddress)
        returns (Description memory)
    {
        return _validators[operatorAddress].description;
    }

    /**
     * @param operatorAddress the operator address of the validator
     *
     * @return the commission of a validator
     */
    function getValidatorCommission(address operatorAddress)
        external
        view
        validatorExist(operatorAddress)
        returns (Commission memory)
    {
        return _validators[operatorAddress].commission;
    }

    /**
     * @dev this function will be used by Parlia consensus engine.
     *
     * @notice get the election info of a validator
     *
     * @param offset the offset of the query
     * @param limit the limit of the query
     *
     * @return consensusAddrs the consensus addresses of the validators
     * @return votingPowers the voting powers of the validators. The voting power will be 0 if the validator is jailed.
     * @return voteAddrs the vote addresses of the validators
     * @return totalLength the total number of validators
     */
    function getValidatorElectionInfo(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (
            address[] memory consensusAddrs,
            uint256[] memory votingPowers,
            bytes[] memory voteAddrs,
            uint256 totalLength
        )
    {
        totalLength = _validatorSet.length();
        if (offset >= totalLength) {
            return (consensusAddrs, votingPowers, voteAddrs, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        consensusAddrs = new address[](count);
        votingPowers = new uint256[](count);
        voteAddrs = new bytes[](count);
        for (uint256 i; i < count; ++i) {
            address operatorAddress = _validatorSet.at(offset + i);
            Validator memory valInfo = _validators[operatorAddress];
            consensusAddrs[i] = valInfo.consensusAddress;
            votingPowers[i] = valInfo.jailed ? 0 : IStakeCredit(valInfo.creditContract).totalPooledBNB();
            voteAddrs[i] = valInfo.voteAddress;
        }
    }

    /*----------------- internal functions -----------------*/
    function _decodeMigrationSynPackage(bytes memory msgBytes)
        internal
        pure
        returns (StakeMigrationPackage memory, bool)
    {
        StakeMigrationPackage memory migrationPackage;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                migrationPackage.operatorAddress = address(uint160(iter.next().toAddress()));
            } else if (idx == 1) {
                migrationPackage.delegator = address(uint160(iter.next().toAddress()));
            } else if (idx == 2) {
                migrationPackage.refundAddress = address(uint160(iter.next().toAddress()));
            } else if (idx == 3) {
                migrationPackage.amount = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            ++idx;
        }

        return (migrationPackage, success);
    }

    function _doMigration(StakeMigrationPackage memory migrationPkg)
        internal
        whenNotPaused
        returns (StakeMigrationRespCode)
    {
        if (blackList[migrationPkg.delegator] || migrationPkg.delegator == address(0)) {
            revert InBlackList();
        }

        if (!_validatorSet.contains(migrationPkg.operatorAddress)) {
            return StakeMigrationRespCode.VALIDATOR_NOT_EXISTED;
        }

        Validator memory valInfo = _validators[migrationPkg.operatorAddress];
        if (valInfo.jailed && migrationPkg.delegator != migrationPkg.operatorAddress) {
            return StakeMigrationRespCode.VALIDATOR_JAILED;
        }

        uint256 shares =
            IStakeCredit(valInfo.creditContract).delegate{ value: migrationPkg.amount }(migrationPkg.delegator);
        emit Delegated(migrationPkg.operatorAddress, migrationPkg.delegator, shares, migrationPkg.amount);
        emit MigrateSuccess(migrationPkg.operatorAddress, migrationPkg.delegator, shares, migrationPkg.amount);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, migrationPkg.delegator);

        return StakeMigrationRespCode.MIGRATE_SUCCESS;
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
        if (voteAddress.length != BLS_PUBKEY_LENGTH || blsProof.length != BLS_SIG_LENGTH) {
            return false;
        }

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
        emit StakeCreditInitialized(operatorAddress, creditProxy);

        return creditProxy;
    }

    function _checkValidatorSelfDelegation(address operatorAddress) internal {
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.jailed) {
            return;
        }
        if (IStakeCredit(valInfo.creditContract).getPooledBNB(operatorAddress) < minSelfDelegationBNB) {
            _jailValidator(valInfo, block.timestamp + downtimeJailTime);
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).removeTmpMigratedValidator(valInfo.consensusAddress);
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(valInfo.consensusAddress);
        }
    }

    function _checkFelonyRecord(address operatorAddress, SlashType slashType) internal returns (bool, uint256) {
        bytes32 slashKey = keccak256(abi.encodePacked(operatorAddress, slashType));
        uint256 jailUntil = _felonyRecords[slashKey];
        // for double sign and malicious vote slash
        // if the validator is already jailed, no need to slash again
        if (jailUntil > block.timestamp) {
            return (false, 0);
        }
        jailUntil = block.timestamp + felonyJailTime;
        _felonyRecords[slashKey] = jailUntil;
        return (true, jailUntil);
    }

    function _jailValidator(Validator storage valInfo, uint256 jailUntil) internal {
        // keep the last eligible validator
        bool isLast = (numOfJailed >= _validatorSet.length() - 1);
        if (isLast) {
            // If staking channel is closed, then BC-fusion is finished and we should keep the last eligible validator here
            if (
                !ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).registeredContractChannelMap(
                    VALIDATOR_CONTRACT_ADDR, STAKING_CHANNELID
                )
            ) {
                emit ValidatorEmptyJailed(valInfo.operatorAddress);
                return;
            }
        }

        if (jailUntil > valInfo.jailUntil) {
            valInfo.jailUntil = jailUntil;
        }

        if (!valInfo.jailed) {
            valInfo.jailed = true;
            numOfJailed += 1;

            emit ValidatorJailed(valInfo.operatorAddress);
        }
    }

    function _claim(address operatorAddress, uint256 requestNumber) internal validatorExist(operatorAddress) {
        uint256 bnbAmount = IStakeCredit(_validators[operatorAddress].creditContract).claim(msg.sender, requestNumber);
        emit Claimed(operatorAddress, msg.sender, bnbAmount);
    }
}
