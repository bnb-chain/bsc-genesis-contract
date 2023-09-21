pragma solidity 0.6.4;

interface ICrossChain {
    /**
     * @dev Send package to Binance Chain
     */
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee) external;
    function channelHandlerContractMap(uint8 channelId) external view returns (address);
}
