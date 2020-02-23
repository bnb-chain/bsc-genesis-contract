pragma solidity ^0.5.16;
import { System } from "./System.sol";
import "./interface/ISystemReward.sol";

contract SystemReward is System, ISystemReward{
  uint256 public constant MAX_REWARDS = 1e18;

  uint public numOperator;
  mapping(address => bool) operators;

  modifier onlyOperatorExist(address _operator) {
    require(operators[_operator], "the operator do not exist");
    _;
  }

  modifier onlyOperatorNotExist(address _operator) {
    require(!operators[_operator],"the operator already exist");
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
  event RewardTo(address indexed to, uint256 indexed amount);
  event RewardEmpty();

  event ReceiveDeposit(address indexed from, uint256 indexed amount);
  constructor(address[] memory _operators) public {
    for(uint i = 0; i<_operators.length; i++) {
      operators[_operators[i]] = true;
    }
    numOperator = _operators.length;
  }

  function () external payable{
    if (msg.value>0){
      emit ReceiveDeposit(msg.sender, msg.value);
    }
  }

  function addOperator(address operator) external onlySystem onlyOperatorNotExist(operator){
    operators[operator] = true;
    numOperator ++;
    emit NewOperator(operator);
  }

  function removeOperator(address operator) external onlySystem onlyOperatorExist(operator){
    delete operators[operator];
    numOperator --;
    emit DeleteOperator(operator);
  }

  function claimRewards(address payable to, uint256 amount) external onlyOperator rewardNotExceedLimit(amount){
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if(actualAmount>0){
      to.transfer(actualAmount);
      emit RewardTo(to, actualAmount);
    }else{
      emit RewardEmpty();
    }
  }

  function isOperator(address addr) external view returns (bool){
    return operators[addr];
  }
}