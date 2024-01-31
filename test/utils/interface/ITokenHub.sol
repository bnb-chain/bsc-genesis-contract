// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface TokenHub {
    event CancelTokenRecoverLock(
        bytes32 indexed tokenSymbol, address indexed tokenAddr, address indexed attacker, uint256 amount
    );
    event CancelTransfer(address indexed tokenAddr, address indexed attacker, uint256 amount);
    event LargeTransferLimitSet(address indexed tokenAddr, address indexed owner, uint256 largeTransferLimit);
    event LargeTransferLocked(address indexed tokenAddr, address indexed recipient, uint256 amount, uint256 unlockAt);
    event NotBoundToken(bytes32 indexed tokenSymbol, address indexed recipient, uint256 amount);
    event TokenRecoverLocked(
        bytes32 indexed tokenSymbol,
        address indexed tokenAddr,
        address indexed recipient,
        uint256 amount,
        uint256 unlockAt
    );
    event WithdrawUnlockedToken(address indexed tokenAddr, address indexed recipient, uint256 amount);
    event paramChange(string key, bytes value);
    event receiveDeposit(address from, uint256 amount);
    event refundFailure(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
    event refundSuccess(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
    event rewardTo(address to, uint256 amount);
    event transferInSuccess(address bep20Addr, address refundAddr, uint256 amount);
    event transferOutSuccess(address bep20Addr, address senderAddr, uint256 amount, uint256 relayFee);
    event unexpectedPackage(uint8 channelId, bytes msgBytes);

    receive() external payable;

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function BEP2_TOKEN_DECIMALS() external view returns (uint8);
    function BEP2_TOKEN_SYMBOL_FOR_BNB() external view returns (bytes32);
    function BIND_CHANNELID() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOVERNOR_ADDR() external view returns (address);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function GOV_TOKEN_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function INIT_BNB_LARGE_TRANSFER_LIMIT() external view returns (uint256);
    function INIT_LOCK_PERIOD() external view returns (uint256);
    function INIT_MINIMUM_RELAY_FEE() external view returns (uint256);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function LOCK_PERIOD_FOR_TOKEN_RECOVER() external view returns (uint256);
    function MAXIMUM_BEP20_SYMBOL_LEN() external view returns (uint8);
    function MAX_BEP2_TOTAL_SUPPLY() external view returns (uint256);
    function MAX_GAS_FOR_CALLING_BEP20() external view returns (uint256);
    function MAX_GAS_FOR_TRANSFER_BNB() external view returns (uint256);
    function MINIMUM_BEP20_SYMBOL_LEN() external view returns (uint8);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function REWARD_UPPER_LIMIT() external view returns (uint256);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKE_CREDIT_ADDR() external view returns (address);
    function STAKE_HUB_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TEN_DECIMALS() external view returns (uint256);
    function TIMELOCK_ADDR() external view returns (address);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TOKEN_RECOVER_PORTAL_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_IN_FAILURE_INSUFFICIENT_BALANCE() external view returns (uint8);
    function TRANSFER_IN_FAILURE_NON_PAYABLE_RECIPIENT() external view returns (uint8);
    function TRANSFER_IN_FAILURE_TIMEOUT() external view returns (uint8);
    function TRANSFER_IN_FAILURE_UNBOUND_TOKEN() external view returns (uint8);
    function TRANSFER_IN_FAILURE_UNKNOWN() external view returns (uint8);
    function TRANSFER_IN_SUCCESS() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function alreadyInit() external view returns (bool);
    function batchTransferOutBNB(
        address[] memory recipientAddrs,
        uint256[] memory amounts,
        address[] memory refundAddrs,
        uint64 expireTime
    ) external payable returns (bool);
    function bep20ContractDecimals(address) external view returns (uint256);
    function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external;
    function bscChainID() external view returns (uint16);
    function cancelTokenRecoverLock(bytes32 tokenSymbol, address attacker) external;
    function cancelTransferIn(address tokenAddress, address attacker) external;
    function claimMigrationFund(uint256 amount) external returns (bool);
    function claimRewards(address payable to, uint256 amount) external returns (uint256);
    function getBep2SymbolByContractAddr(address contractAddr) external view returns (bytes32);
    function getBoundBep2Symbol(address contractAddr) external view returns (string memory);
    function getBoundContract(string memory bep2Symbol) external view returns (address);
    function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external view returns (address);
    function getMiniRelayFee() external view returns (uint256);
    function handleAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleFailAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleSynPackage(uint8 channelId, bytes memory msgBytes) external returns (bytes memory);
    function init() external;
    function largeTransferLimitMap(address) external view returns (uint256);
    function lockInfoMap(address, address) external view returns (uint256 amount, uint256 unlockAt);
    function lockPeriod() external view returns (uint256);
    function recoverBCAsset(bytes32 tokenSymbol, address recipient, uint256 amount) external;
    function relayFee() external view returns (uint256);
    function setLargeTransferLimit(address bep20Token, uint256 largeTransferLimit) external;
    function transferOut(
        address contractAddr,
        address recipient,
        uint256 amount,
        uint64 expireTime
    ) external payable returns (bool);
    function unbindToken(bytes32 bep2Symbol, address contractAddr) external;
    function updateParam(string memory key, bytes memory value) external;
    function withdrawStakingBNB(uint256 amount) external returns (bool);
    function withdrawUnlockedToken(address tokenAddress, address recipient) external;
}
