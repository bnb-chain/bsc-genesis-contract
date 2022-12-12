pragma solidity ^0.8.10;

interface Staking {
    event crashResponse(uint8 indexed eventType);
    event delegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
    event delegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 relayerFee);
    event delegateSuccess(address indexed delegator, address indexed validator, uint256 amount);
    event failedSynPackage(uint8 indexed eventType, uint256 errCode);
    event paramChange(string key, bytes value);
    event redelegateFailed(
        address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount, uint8 errCode
    );
    event redelegateSubmitted(
        address indexed delegator,
        address indexed validatorSrc,
        address indexed validatorDst,
        uint256 amount,
        uint256 relayerFee
    );
    event redelegateSuccess(address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount);
    event rewardClaimed(address indexed delegator, uint256 amount);
    event rewardReceived(address indexed delegator, uint256 amount);
    event undelegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
    event undelegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 relayerFee);
    event undelegateSuccess(address indexed delegator, address indexed validator, uint256 amount);
    event undelegatedClaimed(address indexed delegator, uint256 amount);
    event undelegatedReceived(address indexed delegator, address indexed validator, uint256 amount);

    function BIND_CHANNELID() external view returns (uint8);
    function CODE_FAILED() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CODE_SUCCESS() external view returns (uint8);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function ERROR_WITHDRAW_BNB() external view returns (uint32);
    function EVENT_DELEGATE() external view returns (uint8);
    function EVENT_DISTRIBUTE_REWARD() external view returns (uint8);
    function EVENT_DISTRIBUTE_UNDELEGATED() external view returns (uint8);
    function EVENT_REDELEGATE() external view returns (uint8);
    function EVENT_UNDELEGATE() external view returns (uint8);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_BSC_RELAYER_FEE() external view returns (uint256);
    function INIT_MIN_DELEGATION() external view returns (uint256);
    function INIT_RELAYER_FEE() external view returns (uint256);
    function INIT_TRANSFER_GAS() external view returns (uint256);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function LOCK_TIME() external view returns (uint256);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TEN_DECIMALS() external view returns (uint256);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function alreadyInit() external view returns (bool);
    function bSCRelayerFee() external view returns (uint256);
    function bscChainID() external view returns (uint16);
    function claimReward() external returns (uint256 amount);
    function claimUndelegated() external returns (uint256 amount);
    function delegate(address validator, uint256 amount) external payable;
    function getDelegated(address delegator, address validator) external view returns (uint256);
    function getDistributedReward(address delegator) external view returns (uint256);
    function getMinDelegation() external view returns (uint256);
    function getPendingRedelegateTime(address delegator, address valSrc, address valDst)
        external
        view
        returns (uint256);
    function getPendingUndelegateTime(address delegator, address validator) external view returns (uint256);
    function getRelayerFee() external view returns (uint256);
    function getRequestInFly(address delegator) external view returns (uint256[3] memory);
    function getTotalDelegated(address delegator) external view returns (uint256);
    function getUndelegated(address delegator) external view returns (uint256);
    function handleAckPackage(uint8, bytes memory msgBytes) external;
    function handleFailAckPackage(uint8, bytes memory msgBytes) external;
    function handleSynPackage(uint8, bytes memory msgBytes) external returns (bytes memory);
    function minDelegation() external view returns (uint256);
    function redelegate(address validatorSrc, address validatorDst, uint256 amount) external payable;
    function relayerFee() external view returns (uint256);
    function transferGas() external view returns (uint256);
    function undelegate(address validator, uint256 amount) external payable;
    function updateParam(string memory key, bytes memory value) external;
}
