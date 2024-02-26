// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface BSCTimelock {
    error InvalidValue(string key, bytes value);
    error OnlyCoinbase();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error UnknownParam(string key, bytes value);

    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
    event CallSalt(bytes32 indexed id, bytes32 salt);
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );
    event Cancelled(bytes32 indexed id);
    event Initialized(uint8 version);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);
    event ParamChange(string key, bytes value);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    receive() external payable;

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function CANCELLER_ROLE() external view returns (bytes32);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function EXECUTOR_ROLE() external view returns (bytes32);
    function PROPOSER_ROLE() external view returns (bytes32);
    function STAKING_CHANNELID() external view returns (uint8);
    function TIMELOCK_ADMIN_ROLE() external view returns (bytes32);
    function cancel(bytes32 id) external;
    function execute(
        address target,
        uint256 value,
        bytes memory payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;
    function executeBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;
    function getMinDelay() external view returns (uint256);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getTimestamp(bytes32 id) external view returns (uint256);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function hashOperation(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);
    function hashOperationBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);
    function initialize() external;
    function isOperation(bytes32 id) external view returns (bool);
    function isOperationDone(bytes32 id) external view returns (bool);
    function isOperationPending(bytes32 id) external view returns (bool);
    function isOperationReady(bytes32 id) external view returns (bool);
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external returns (bytes4);
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function schedule(
        address target,
        uint256 value,
        bytes memory data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;
    function scheduleBatch(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function updateDelay(uint256 newDelay) external;
    function updateParam(string memory key, bytes memory value) external;
}
