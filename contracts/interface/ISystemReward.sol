pragma solidity 0.6.4;

interface ISystemReward {
  function claimRewards(address payable to, uint256 amount) external returns(uint256 actualAmount);
}