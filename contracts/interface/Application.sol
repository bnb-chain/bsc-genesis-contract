pragma solidity 0.6.4;

interface Application {
    /**
     * @dev Handle sync package
     */
    function handleSyncPackage(uint8 channelId, bytes calldata payload, address payable relayer, address payable headerRelayer) external returns(bytes memory responsePayload);

    /**
     * @dev Handle ack package
     */
    function handleAckPackage(uint8 channelId, bytes calldata payload, address payable relayer, address payable headerRelayer) external returns(bool success);

    /**
     * @dev Handle fail ack package
     */
    function handleFailAckPackage(uint8 channelId, bytes calldata payload, address payable relayer, address payable headerRelayer) external returns(bool success);
}