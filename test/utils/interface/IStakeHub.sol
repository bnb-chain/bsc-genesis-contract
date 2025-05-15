// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface StakeHub {
    type SlashType is uint8;
    type StakeMigrationRespCode is uint8;

    struct Commission {
        uint64 rate;
        uint64 maxRate;
        uint64 maxChangeRate;
    }

    struct Description {
        string moniker;
        string identity;
        string website;
        string details;
    }

    error AlreadyPaused();
    error AlreadySlashed();
    error ConsensusAddressExpired();
    error DelegationAmountTooSmall();
    error DuplicateConsensusAddress();
    error DuplicateMoniker();
    error DuplicateVoteAddress();
    error InBlackList();
    error InvalidCommission();
    error InvalidConsensusAddress();
    error InvalidMoniker();
    error InvalidRequest();
    error InvalidSynPackage();
    error InvalidValue(string key, bytes value);
    error InvalidVoteAddress();
    error JailTimeNotExpired();
    error NoMoreFelonyAllowed();
    error NotPaused();
    error OnlyCoinbase();
    error OnlyProtector();
    error OnlySelfDelegation();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error SameValidator();
    error SelfDelegationNotEnough();
    error TransferFailed();
    error UnknownParam(string key, bytes value);
    error UpdateTooFrequently();
    error ValidatorExisted();
    error ValidatorNotExisted();
    error ValidatorNotJailed();
    error VoteAddressExpired();
    error ZeroShares();
    error InvalidAgent();
    error InvalidValidator();

    event BlackListed(address indexed target);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event CommissionRateEdited(address indexed operatorAddress, uint64 newCommissionRate);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event DescriptionEdited(address indexed operatorAddress);
    event Initialized(uint8 version);
    event MigrateFailed(
        address indexed operatorAddress, address indexed delegator, uint256 bnbAmount, StakeMigrationRespCode respCode
    );
    event MigrateSuccess(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event ParamChange(string key, bytes value);
    event Paused();
    event ProtectorChanged(address indexed oldProtector, address indexed newProtector);
    event Redelegated(
        address indexed srcValidator,
        address indexed dstValidator,
        address indexed delegator,
        uint256 oldShares,
        uint256 newShares,
        uint256 bnbAmount
    );
    event Resumed();
    event RewardDistributeFailed(address indexed operatorAddress, bytes failReason);
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event StakeCreditInitialized(address indexed operatorAddress, address indexed creditContract);
    event UnBlackListed(address indexed target);
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ValidatorCreated(
        address indexed consensusAddress,
        address indexed operatorAddress,
        address indexed creditContract,
        bytes voteAddress
    );
    event ValidatorEmptyJailed(address indexed operatorAddress);
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorSlashed(
        address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, SlashType slashType
    );
    event ValidatorUnjailed(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event AgentChanged(address indexed operatorAddress, address indexed oldAgent, address indexed newAgent);
    event NodeIDAdded(address indexed validator, bytes32 nodeID);
    event NodeIDRemoved(address indexed validator, bytes32 nodeID);

    receive() external payable;

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function BREATHE_BLOCK_INTERVAL() external view returns (uint256);
    function DEAD_ADDRESS() external view returns (address);
    function LOCK_AMOUNT() external view returns (uint256);
    function REDELEGATE_FEE_RATE_BASE() external view returns (uint256);
    function STAKING_CHANNELID() external view returns (uint8);
    function addToBlackList(address account) external;
    function blackList(address) external view returns (bool);
    function claim(address operatorAddress, uint256 requestNumber) external;
    function claimBatch(address[] memory operatorAddresses, uint256[] memory requestNumbers) external;
    function consensusExpiration(address) external view returns (uint256);
    function consensusToOperator(address) external view returns (address);
    function createValidator(
        address consensusAddress,
        bytes memory voteAddress,
        bytes memory blsProof,
        Commission memory commission,
        Description memory description
    ) external payable;
    function delegate(address operatorAddress, bool delegateVotePower) external payable;
    function distributeReward(address consensusAddress) external payable;
    function doubleSignSlash(address consensusAddress) external;
    function downtimeJailTime() external view returns (uint256);
    function downtimeSlash(address consensusAddress) external;
    function downtimeSlashAmount() external view returns (uint256);
    function editCommissionRate(uint64 commissionRate) external;
    function editConsensusAddress(address newConsensusAddress) external;
    function editDescription(Description memory description) external;
    function editVoteAddress(bytes memory newVoteAddress, bytes memory blsProof) external;
    function felonyJailTime() external view returns (uint256);
    function felonySlashAmount() external view returns (uint256);
    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        returns (uint256 createdTime, bool jailed, uint256 jailUntil);
    function getValidatorCommission(address operatorAddress) external view returns (Commission memory);
    function getValidatorConsensusAddress(address operatorAddress) external view returns (address consensusAddress);
    function getValidatorCreditContract(address operatorAddress) external view returns (address creditContract);
    function getValidatorDescription(address operatorAddress) external view returns (Description memory);
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
        );
    function getValidatorRewardRecord(address operatorAddress, uint256 index) external view returns (uint256);
    function getValidatorTotalPooledBNBRecord(address operatorAddress, uint256 index) external view returns (uint256);
    function getValidatorVoteAddress(address operatorAddress) external view returns (bytes memory voteAddress);
    function getValidators(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory operatorAddrs, address[] memory creditAddrs, uint256 totalLength);
    function handleAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleFailAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleSynPackage(uint8, bytes memory msgBytes) external returns (bytes memory);
    function initialize() external;
    function isPaused() external view returns (bool);
    function maliciousVoteSlash(bytes memory voteAddress) external;
    function maxElectedValidators() external view returns (uint256);
    function maxFelonyBetweenBreatheBlock() external view returns (uint256);
    function minDelegationBNBChange() external view returns (uint256);
    function minSelfDelegationBNB() external view returns (uint256);
    function numOfJailed() external view returns (uint256);
    function pause() external;
    function redelegate(address srcValidator, address dstValidator, uint256 shares, bool delegateVotePower) external;
    function redelegateFeeRate() external view returns (uint256);
    function removeFromBlackList(address account) external;
    function resume() external;
    function syncGovToken(address[] memory operatorAddresses, address account) external;
    function transferGasLimit() external view returns (uint256);
    function unbondPeriod() external view returns (uint256);
    function undelegate(address operatorAddress, uint256 shares) external;
    function unjail(address operatorAddress) external;
    function updateParam(string memory key, bytes memory value) external;
    function voteExpiration(bytes memory) external view returns (uint256);
    function voteToOperator(bytes memory) external view returns (address);

    function agentToOperator(address) external view returns (address);
    function updateAgent(address newAgent) external;

    // NodeID management functions
    function addNodeIDs(bytes32[] calldata newNodeIDs) external;
    function removeNodeIDs(bytes32[] calldata targetNodeIDs) external;
    function getNodeIDs(address[] calldata validatorsToQuery) external view returns (address[] memory consensusAddresses, bytes32[][] memory nodeIDsList);
    function maxNodeIDs() external view returns (uint256);
}
