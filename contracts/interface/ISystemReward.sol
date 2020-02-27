pragma solidity ^0.5.15;

interface ISystemReward {
  function claimRewards(address payable to, uint256 amount) external;
}