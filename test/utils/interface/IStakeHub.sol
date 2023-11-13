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

    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
    event DescriptionEdited(address indexed operatorAddress);
    event Initialized(uint8 version);
    event ParamChange(string key, bytes value);
    event Redelegated(
        address indexed srcValidator, address indexed dstValidator, address indexed delegator, uint256 bnbAmount
    );
    event RewardDistributeFailed(address indexed operatorAddress, bytes failReason);
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event StakingPaused();
    event StakingResumed();
    event ValidatorCreated(
        address indexed consensusAddress,
        address indexed operatorAddress,
        address indexed creditContract,
        bytes voteAddress
    );
    event ValidatorEmptyJailed(address indexed operatorAddress);
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorSlashed(
        address indexed operatorAddress,
        uint256 jailUntil,
        uint256 slashAmount,
        uint248 slashHeight,
        SlashType slashType
    );
    event ValidatorUnjailed(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);

    function addBlackList(address _addr) external;
    function assetProtector() external view returns (address);
    function blackList(address) external view returns (bool);
    function claim(address operatorAddress, uint256 requestNumber) external;
    function createValidator(
        address consensusAddress,
        bytes memory voteAddress,
        bytes memory blsProof,
        Commission memory commission,
        Description memory description
    ) external payable;
    function delegate(address operatorAddress, bool delegateVotePower) external payable;
    function distributeReward(address consensusAddress) external payable;
    function doubleSignJailTime() external view returns (uint256);
    function doubleSignSlash(address consensusAddress, uint256 height) external;
    function doubleSignSlashAmount() external view returns (uint256);
    function downtimeJailTime() external view returns (uint256);
    function downtimeSlash(address consensusAddress) external;
    function downtimeSlashAmount() external view returns (uint256);
    function editCommissionRate(uint64 commissionRate) external;
    function editConsensusAddress(address newConsensusAddress) external;
    function editDescription(Description memory description) external;
    function editVoteAddress(bytes memory newVoteAddress, bytes memory blsProof) external;
    function getOperatorAddressByConsensusAddress(address consensusAddress) external view returns (address);
    function getOperatorAddressByVoteAddress(bytes memory voteAddress) external view returns (address);
    function getSlashRecord(address operatorAddress, uint256 height, SlashType slashType)
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
    function getValidatorElectionInfo(uint256 offset, uint256 limit)
        external
        view
        returns (
            address[] memory consensusAddrs,
            uint256[] memory votingPowers,
            bytes[] memory voteAddrs,
            uint256 totalLength
        );
    function initialize() external;
    function isPaused() external view returns (bool);
    function maliciousVoteSlash(bytes memory _voteAddr, uint256 height) external;
    function maxElectedValidators() external view returns (uint256);
    function minDelegationBNBChange() external view returns (uint256);
    function minSelfDelegationBNB() external view returns (uint256);
    function numOfJailed() external view returns (uint256);
    function pauseStaking() external;
    function redelegate(address srcValidator, address dstValidator, uint256 shares, bool delegateVotePower) external;
    function removeBlackList(address _addr) external;
    function resumeStaking() external;
    function sync(address[] memory operatorAddresses, address account) external;
    function transferGasLimit() external view returns (uint256);
    function unbondPeriod() external view returns (uint256);
    function undelegate(address operatorAddress, uint256 shares) external;
    function unjail(address operatorAddress) external;
    function updateParam(string memory key, bytes memory value) external;
}
