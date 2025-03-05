// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface BSCValidatorSet {
    event batchTransfer(uint256 amount);
    event batchTransferFailed(uint256 indexed amount, string reason);
    event batchTransferLowerFailed(uint256 indexed amount, bytes reason);
    event deprecatedDeposit(address indexed validator, uint256 amount);
    event deprecatedFinalityRewardDeposit(address indexed validator, uint256 amount);
    event directTransfer(address payable indexed validator, uint256 amount);
    event directTransferFail(address payable indexed validator, uint256 amount);
    event failReasonWithStr(string message);
    event feeBurned(uint256 amount);
    event finalityRewardDeposit(address indexed validator, uint256 amount);
    event paramChange(string key, bytes value);
    event systemTransfer(uint256 amount);
    event tmpValidatorSetUpdated(uint256 validatorsNum);
    event unexpectedPackage(uint8 channelId, bytes msgBytes);
    event validatorDeposit(address indexed validator, uint256 amount);
    event validatorEmptyJailed(address indexed validator);
    event validatorEnterMaintenance(address indexed validator);
    event validatorExitMaintenance(address indexed validator);
    event validatorFelony(address indexed validator, uint256 amount);
    event validatorJailed(address indexed validator);
    event validatorMisdemeanor(address indexed validator, uint256 amount);
    event validatorSetUpdated();

    receive() external payable;

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function BIND_CHANNELID() external view returns (uint8);
    function BLOCK_FEES_RATIO_SCALE() external view returns (uint256);
    function BURN_ADDRESS() external view returns (address);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function DUSTY_INCOMING() external view returns (uint256);
    function ERROR_FAIL_CHECK_VALIDATORS() external view returns (uint32);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function ERROR_LEN_OF_VAL_MISMATCH() external view returns (uint32);
    function ERROR_RELAYFEE_TOO_LARGE() external view returns (uint32);
    function ERROR_UNKNOWN_PACKAGE_TYPE() external view returns (uint32);
    function EXPIRE_TIME_SECOND_GAP() external view returns (uint256);
    function GOVERNOR_ADDR() external view returns (address);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function GOV_TOKEN_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_BURN_RATIO() external view returns (uint256);
    function INIT_MAINTAIN_SLASH_SCALE() external view returns (uint256);
    function INIT_MAX_NUM_OF_MAINTAINING() external view returns (uint256);
    function INIT_NUM_OF_CABINETS() external view returns (uint256);
    function INIT_SYSTEM_REWARD_RATIO() external view returns (uint256);
    function INIT_VALIDATORSET_BYTES() external view returns (bytes memory);
    function JAIL_MESSAGE_TYPE() external view returns (uint8);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function MAX_NUM_OF_VALIDATORS() external view returns (uint256);
    function MAX_SYSTEM_REWARD_BALANCE() external view returns (uint256);
    function PRECISION() external view returns (uint256);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKE_CREDIT_ADDR() external view returns (address);
    function STAKE_HUB_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TIMELOCK_ADDR() external view returns (address);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TOKEN_RECOVER_PORTAL_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function VALIDATORS_UPDATE_MESSAGE_TYPE() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function alreadyInit() external view returns (bool);
    function systemRewardAntiMEVRatio() external view returns (uint256);
    function bscChainID() external view returns (uint16);
    function burnRatio() external view returns (uint256);
    function burnRatioInitialized() external view returns (bool);
    function canEnterMaintenance(uint256 index) external view returns (bool);
    function currentValidatorSet(uint256)
        external
        view
        returns (
            address consensusAddress,
            address payable feeAddress,
            address BBCFeeAddress,
            uint64 votingPower,
            bool jailed,
            uint256 incoming
        );
    function currentValidatorSetMap(address) external view returns (uint256);
    function currentVoteAddrFullSet(uint256) external view returns (bytes memory);
    function deposit(address valAddr) external payable;
    function distributeFinalityReward(address[] memory valAddrs, uint256[] memory weights) external;
    function enterMaintenance() external;
    function exitMaintenance() external;
    function expireTimeSecondGap() external view returns (uint256);
    function felony(address validator) external;
    function getCurrentValidatorIndex(address validator) external view returns (uint256);
    function getIncoming(address validator) external view returns (uint256);
    function getLivingValidators() external view returns (address[] memory, bytes[] memory);
    function getMiningValidators() external view returns (address[] memory, bytes[] memory);
    function getTurnLength() external view returns (uint256);
    function getValidators() external view returns (address[] memory);
    function getWorkingValidatorCount() external view returns (uint256 workingValidatorCount);
    function handleAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleFailAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleSynPackage(uint8, bytes memory msgBytes) external returns (bytes memory responsePayload);
    function init() external;
    function systemRewardBaseRatio() external view returns (uint256);
    function isCurrentValidator(address validator) external view returns (bool);
    function isMonitoredForMaliciousVote(bytes memory voteAddr) external view returns (bool);
    function isSystemRewardIncluded() external view returns (bool);
    function isWorkingValidator(uint256 index) external view returns (bool);
    function maintainSlashScale() external view returns (uint256);
    function maxNumOfCandidates() external view returns (uint256);
    function maxNumOfMaintaining() external view returns (uint256);
    function maxNumOfWorkingCandidates() external view returns (uint256);
    function misdemeanor(address validator) external;
    function numOfCabinets() external view returns (uint256);
    function numOfJailed() external view returns (uint256);
    function numOfMaintaining() external view returns (uint256);
    function previousBalanceOfSystemReward() external view returns (uint256);
    function previousHeight() external view returns (uint256);
    function previousVoteAddrFullSet(uint256) external view returns (bytes memory);
    function removeTmpMigratedValidator(address validator) external;
    function totalInComing() external view returns (uint256);
    function turnLength() external view returns (uint256);
    function updateParam(string memory key, bytes memory value) external;
    function updateValidatorSetV2(
        address[] memory _consensusAddrs,
        uint64[] memory _votingPowers,
        bytes[] memory _voteAddrs
    ) external;
    function validatorExtraSet(uint256)
        external
        view
        returns (uint256 enterMaintenanceHeight, bool isMaintaining, bytes memory voteAddress);
}
