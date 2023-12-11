// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface StakeHub {
    type SlashType is uint8;

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

    error AlreadySlashed();
    error DelegationAmountTooSmall();
    error DuplicateConsensusAddress();
    error DuplicateVoteAddress();
    error InBlackList();
    error InvalidCommission();
    error InvalidConsensusAddress();
    error InvalidMoniker();
    error InvalidRequest();
    error InvalidValue(string key, bytes value);
    error InvalidVoteAddress();
    error JailTimeNotExpired();
    error NoMoreFelonyToday();
    error OnlyAssetProtector();
    error OnlyCoinbase();
    error OnlySelfDelegation();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error SameValidator();
    error SelfDelegationNotEnough();
    error StakeHubPaused();
    error TransferFailed();
    error UnknownParam(string key, bytes value);
    error UpdateTooFrequently();
    error ValidatorExisted();
    error ValidatorNotExist();
    error ValidatorNotJailed();
    error ZeroShares();

    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event DescriptionEdited(address indexed operatorAddress);
    event Initialized(uint8 version);
    event ParamChange(string key, bytes value);
    event Paused();
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
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
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

    receive() external payable;

    function BREATH_BLOCK_INTERVAL() external view returns (uint256);
    function DEAD_ADDRESS() external view returns (address);
    function LOCK_AMOUNT() external view returns (uint256);
    function REDELEGATE_FEE_RATE_BASE() external view returns (uint256);
    function addToBlackList(address account) external;
    function assetProtector() external view returns (address);
    function blackList(address) external view returns (bool);
    function claim(address operatorAddress, uint256 requestNumber) external;
    function claimBatch(address[] memory operatorAddresses, uint256[] memory requestNumbers) external;
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
    function getOperatorAddressByConsensusAddress(address consensusAddress) external view returns (address);
    function getOperatorAddressByVoteAddress(bytes memory voteAddress) external view returns (address);
    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        returns (
            address consensusAddress,
            address creditContract,
            uint256 createdTime,
            bytes memory voteAddress,
            bool jailed,
            uint256 jailUntil
        );
    function getValidatorCommission(address operatorAddress) external view returns (Commission memory);
    function getValidatorDescription(address operatorAddress) external view returns (Description memory);
    function getValidatorElectionInfo(uint256 offset, uint256 limit)
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
    function initialize() external;
    function isPaused() external view returns (bool);
    function maliciousVoteSlash(bytes memory _voteAddr) external;
    function maxElectedValidators() external view returns (uint256);
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
}
