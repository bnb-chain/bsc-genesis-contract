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
      operators[VALIDATOR_CONTRACT_ADDR] = true;
      operators[TOKEN_HUB_ADDR] = true;
      operators[GOV_HUB_ADDR] = true;
      numOperator = 4;
      alreadyInit = true;
    }
    _;
  }


  modifier onlyOperator() {
    require(operators[msg.sender],"only operator is available to call the method");
    _;
  }

  modifier rewardNotExceedLimit(uint256 _amount) {
    require(_amount<MAX_REWARDS && _amount>0, "the claim amount exceed the limit");
    _;
  }

  event NewOperator(address indexed operator);
  event DeleteOperator(address indexed operator);
  event RewardTo(address indexed to, uint256 amount);
  event RewardEmpty();
  event ReceiveDeposit(address indexed from, uint256 amount);


  receive() external payable{
    if (msg.value>0){
      emit ReceiveDeposit(msg.sender, msg.value);
    }
  }
  
  function claimRewards(address payable to, uint256 amount) external override(ISystemReward) doInit onlyOperator rewardNotExceedLimit(amount) returns(uint256) {
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if(actualAmount>0){
      to.transfer(actualAmount);
      emit RewardTo(to, actualAmount);
    }else{
      emit RewardEmpty();
    }
    return actualAmount;
  }

  function isOperator(address addr) external view returns (bool){
    return operators[addr];
  }
}