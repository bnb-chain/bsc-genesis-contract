pragma solidity 0.6.4;
import "./System.sol";
import "./interface/ISystemReward.sol";

contract SystemReward is System, ISystemReward{
  uint256 public constant MAX_REWARDS = 1e18;

  uint public numOperator;
  mapping(address => bool) operators;


  modifier doInit() {
    if(!alreadyInit){
      operators[LIGHT_CLIENT_ADDR] = true;
      operators[INCENTIVIZE_ADDR] = true;
      numOperator = 2;
      alreadyInit = true;
    }
    _;
  }


  modifier onlyOperator() {
    require(operators[msg.sender],"only operator is available to call the method");
    _;
  }
  
  event rewardTo(address indexed to, uint256 amount);
  event rewardEmpty();
  event receiveDeposit(address indexed from, uint256 amount);


  receive() external payable{
    if (msg.value>0){
      emit receiveDeposit(msg.sender, msg.value);
    }
  }

  
  function claimRewards(address payable to, uint256 amount) external override(ISystemReward) doInit onlyOperator returns(uint256) {
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if(actualAmount > MAX_REWARDS){
      actualAmount = MAX_REWARDS;
    }
    if(actualAmount>0){
      to.transfer(actualAmount);
      emit rewardTo(to, actualAmount);
    }else{
      emit rewardEmpty();
    }
    return actualAmount;
  }

  function isOperator(address addr) external view returns (bool){
    return operators[addr];
  }
}