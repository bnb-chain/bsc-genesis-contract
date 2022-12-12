pragma solidity ^0.8.10;

interface MockSystemReward {
    event RewardEmpty();
    event RewardTo(address indexed to, uint256 indexed amount);

    function claimRewards(address to, uint256 amount) external payable;
}
