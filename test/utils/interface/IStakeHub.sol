pragma solidity ^0.8.10;

interface StakeHub {
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event DescriptionEdited(address indexed operatorAddress);
    event ParamChange(string key, bytes value);
    event Redelegated(
        address indexed srcValidator,
        address indexed dstValidator,
        address indexed delegator,
        uint256 oldShares,
        uint256 newShares,
        uint256 bnbAmount
    );
    event RewardDistributeFailed(address indexed operatorAddress, bytes failReason);
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event StakingPaused();
    event StakingResumed();
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
        address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, uint248 slashHeight, uint8 slashType
    );
    event ValidatorUnjailed(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);

    struct Validator {
        address consensusAddress;
        address feeAddress;
        address BBCFeeAddress;
        uint64 votingPower;
        bool jailed;
        uint256 incoming;
    }

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

    function BLS_PUBKEY_LENGTH() external view returns (uint256);
    function BLS_SIG_LENGTH() external view returns (uint256);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function DEAD_ADDRESS() external view returns (address);
    function GOVERNOR_ADDR() external view returns (address);
    function GOV_HUB_ADDR() external view returns (address);
    function GOV_TOKEN_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKE_CREDIT_ADDR() external view returns (address);
    function STAKE_HUB_ADDR() external view returns (address);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TIMELOCK_ADDR() external view returns (address);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function claim(address operatorAddress, uint256 requestNumber) external;
    function createValidator(
        address consensusAddress,
        bytes memory voteAddress,
        bytes memory blsProof,
        Commission memory commission,
        Description memory description
    ) external payable;
    function delegate(address operatorAddress) external payable;
    function distributeReward(address consensusAddress) external payable;
    function doubleSignJailTime() external view returns (uint256);
    function doubleSignSlash(address consensusAddress, uint256 height, uint256 evidenceTime) external;
    function doubleSignSlashAmount() external view returns (uint256);
    function downtimeJailTime() external view returns (uint256);
    function downtimeSlash(address consensusAddress) external;
    function downtimeSlashAmount() external view returns (uint256);
    function editCommissionRate(uint64 commissionRate) external;
    function editConsensusAddress(address newConsensusAddress) external;
    function editDescription(Description memory description) external;
    function editVoteAddress(bytes memory newVoteAddress, bytes memory blsProof) external;
    function getEligibleValidators() external view returns (Validator[] memory, bytes[] memory);
    function getOperatorAddressByConsensusAddress(address consensusAddress) external view returns (address);
    function getOperatorAddressByVoteAddress(bytes memory voteAddress) external view returns (address);
    function getSlashRecord(address operatorAddress, uint256 height, uint8 slashType)
        external
        view
        returns (uint256 slashAmount, uint256 slashHeight, uint256 jailUntil);
    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        returns (
            address consensusAddress,
            address creditContract,
            bytes memory voteAddress,
            bool jailed,
            uint256 jailUntil
        );
    function getValidatorCommission(address operatorAddress) external view returns (Commission memory);
    function getValidatorDescription(address operatorAddress) external view returns (Description memory);
    function getValidatorWithVotingPower(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory consensusAddrs, uint256[] memory votingPowers, uint256 totalLength);
    function initialize() external;
    function isPaused() external view returns (bool);
    function maliciousVoteSlash(bytes memory _voteAddr, uint256 height) external;
    function maxElectedValidators() external view returns (uint256);
    function maxEvidenceAge() external view returns (uint256);
    function minDelegationBNBChange() external view returns (uint256);
    function minSelfDelegationBNB() external view returns (uint256);
    function numOfJailed() external view returns (uint256);
    function pauseStaking() external;
    function redelegate(address srcValidator, address dstValidator, uint256 shares) external;
    function resumeStaking() external;
    function sync(address[] memory operatorAddresses, address account) external;
    function transferGasLimit() external view returns (uint256);
    function unbondPeriod() external view returns (uint256);
    function undelegate(address operatorAddress, uint256 shares) external;
    function unjail(address operatorAddress) external;
    function updateEligibleValidators(address[] memory validators, uint64[] memory votingPowers) external;
    function updateParam(string memory key, bytes memory value) external;
}
