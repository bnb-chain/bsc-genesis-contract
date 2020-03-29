pragma solidity 0.6.4;

interface IHeaderRelayerIncentivize {

    function addReward(address payable headerRelayerAddr, address payable caller) external payable returns (bool);

}
