pragma solidity 0.6.4;

contract MockSystemReward {

  event RewardTo(address indexed to, uint256 indexed amount);
  event RewardEmpty();

  constructor() public payable {

  }

  function claimRewards(address payable to, uint256 amount) public payable {
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if (actualAmount>0) {
      to.transfer(actualAmount);
      emit RewardTo(to, actualAmount);
    } else {
      emit RewardEmpty();
    }
  }
}