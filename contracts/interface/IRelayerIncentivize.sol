pragma solidity 0.6.4;

interface IRelayerIncentivize {

    function addReward(address payable relayerAddr) external payable returns (bool);

    function withdrawReward(uint256 sequence) external returns (bool);

}
