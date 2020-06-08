pragma solidity 0.6.4;

interface ICrossChain {
    /**
     * @dev Send package to Binance Chain
     */
    function sendPackage(uint8 channelId, bytes calldata msgBytes, uint256 syncRelayFee, uint256 ackRelayFee) external returns(bool);
}