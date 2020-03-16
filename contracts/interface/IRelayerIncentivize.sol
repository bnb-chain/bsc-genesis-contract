pragma solidity 0.5.16;

interface IRelayerIncentivize {

    function addReward(address payable relayerAddr) external payable returns (bool);

    function distributeReward(uint256 rewardSequence) external returns (bool);

}
