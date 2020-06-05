pragma solidity 0.6.4;

interface ICrossChain {

    /**
    * @dev Handle package From Binance Chain
    */
    function handlePackage(bytes memory payload, bytes memory proof, uint64 height, uint64 packageSequence, uint8 channelId, uint8 packageType) external returns(bool);

    /**
     * @dev Send package to Binance Chain
     */
    function sendPackage(uint8 channelId, bytes calldata payload) external returns(bool);
}