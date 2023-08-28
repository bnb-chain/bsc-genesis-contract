pragma solidity ^0.8.10;

interface TokenManager {
    event bindFailure(address indexed contractAddr, string bep2Symbol, uint32 failedReason);
    event bindSuccess(address indexed contractAddr, string bep2Symbol, uint256 totalSupply, uint256 peggyAmount);
    event mirrorFailure(address indexed bep20Addr, uint8 errCode);
    event mirrorSuccess(address indexed bep20Addr, bytes32 bep2Symbol);
    event paramChange(string key, bytes value);
    event syncFailure(address indexed bep20Addr, uint8 errCode);
    event syncSuccess(address indexed bep20Addr);
    event unexpectedPackage(uint8 channelId, bytes msgBytes);

    function BEP2_TOKEN_DECIMALS() external view returns (uint8);
    function BIND_CHANNELID() external view returns (uint8);
    function BIND_PACKAGE() external view returns (uint8);
    function BIND_STATUS_ALREADY_BOUND_TOKEN() external view returns (uint8);
    function BIND_STATUS_DECIMALS_MISMATCH() external view returns (uint8);
    function BIND_STATUS_REJECTED() external view returns (uint8);
    function BIND_STATUS_SYMBOL_MISMATCH() external view returns (uint8);
    function BIND_STATUS_TIMEOUT() external view returns (uint8);
    function BIND_STATUS_TOO_MUCH_TOKENHUB_BALANCE() external view returns (uint8);
    function BIND_STATUS_TOTAL_SUPPLY_MISMATCH() external view returns (uint8);
    function CODE_OK() external view returns (uint32);
    function CROSS_CHAIN_CONTRACT_ADDR() external view returns (address);
    function CROSS_STAKE_CHANNELID() external view returns (uint8);
    function ERROR_FAIL_DECODE() external view returns (uint32);
    function GOV_CHANNELID() external view returns (uint8);
    function GOV_HUB_ADDR() external view returns (address);
    function INCENTIVIZE_ADDR() external view returns (address);
    function LIGHT_CLIENT_ADDR() external view returns (address);
    function LOG_MAX_UINT256() external view returns (uint256);
    function MAXIMUM_BEP20_SYMBOL_LEN() external view returns (uint8);
    function MAX_BEP2_TOTAL_SUPPLY() external view returns (uint256);
    function MAX_GAS_FOR_TRANSFER_BNB() external view returns (uint256);
    function MINIMUM_BEP20_SYMBOL_LEN() external view returns (uint8);
    function MIRROR_CHANNELID() external view returns (uint8);
    function MIRROR_STATUS_ALREADY_BOUND() external view returns (uint8);
    function MIRROR_STATUS_DUPLICATED_BEP2_SYMBOL() external view returns (uint8);
    function MIRROR_STATUS_TIMEOUT() external view returns (uint8);
    function RELAYERHUB_CONTRACT_ADDR() external view returns (address);
    function SLASH_CHANNELID() external view returns (uint8);
    function SLASH_CONTRACT_ADDR() external view returns (address);
    function STAKING_CHANNELID() external view returns (uint8);
    function STAKING_CONTRACT_ADDR() external view returns (address);
    function SYNC_CHANNELID() external view returns (uint8);
    function SYNC_STATUS_NOT_BOUND_MIRROR() external view returns (uint8);
    function SYNC_STATUS_TIMEOUT() external view returns (uint8);
    function SYSTEM_REWARD_ADDR() external view returns (address);
    function TEN_DECIMALS() external view returns (uint256);
    function TOKEN_HUB_ADDR() external view returns (address);
    function TOKEN_MANAGER_ADDR() external view returns (address);
    function TRANSFER_IN_CHANNELID() external view returns (uint8);
    function TRANSFER_OUT_CHANNELID() external view returns (uint8);
    function UNBIND_PACKAGE() external view returns (uint8);
    function VALIDATOR_CONTRACT_ADDR() external view returns (address);
    function alreadyInit() external view returns (bool);
    function approveBind(address contractAddr, string memory bep2Symbol) external payable returns (bool);
    function bindPackageRecord(bytes32)
        external
        view
        returns (
            uint8 packageType,
            bytes32 bep2TokenSymbol,
            address contractAddr,
            uint256 totalSupply,
            uint256 peggyAmount,
            uint8 bep20Decimals,
            uint64 expireTime
        );
    function boundByMirror(address) external view returns (bool);
    function bscChainID() external view returns (uint16);
    function expireBind(string memory bep2Symbol) external payable returns (bool);
    function handleAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleFailAckPackage(uint8 channelId, bytes memory msgBytes) external;
    function handleSynPackage(uint8 channelId, bytes memory msgBytes) external returns (bytes memory);
    function mirror(address bep20Addr, uint64 expireTime) external payable returns (bool);
    function mirrorFee() external view returns (uint256);
    function mirrorPendingRecord(address) external view returns (bool);
    function queryRequiredLockAmountForBind(string memory symbol) external view returns (uint256);
    function rejectBind(address contractAddr, string memory bep2Symbol) external payable returns (bool);
    function sync(address bep20Addr, uint64 expireTime) external payable returns (bool);
    function syncFee() external view returns (uint256);
    function updateParam(string memory key, bytes memory value) external;
}
