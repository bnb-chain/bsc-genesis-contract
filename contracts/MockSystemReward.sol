pragma solidity 0.5.16;

contract SystemReward {

    event RewardTo(address indexed to, uint256 indexed amount);
    event RewardEmpty();

    function claimRewards(address payable to, uint256 amount) public payable {
        uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
        if(actualAmount>0){
            to.transfer(actualAmount);
            emit RewardTo(to, actualAmount);
        }else{
            emit RewardEmpty();
        }
    }
}