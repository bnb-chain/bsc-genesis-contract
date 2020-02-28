pragma solidity ^0.5.15;
import { System } from "./System.sol";
import "./interface/ISystemReward.sol";

contract SystemReward is System, ISystemReward{
  uint256 public constant MAX_REWARDS = 1e18;
  address public constant LIGHT_CLIENT_CONTRACT = 0x0000000000000000000000000000000000001003;
  address public constant VALIDATOR_SET_CONTRACT = 0x0000000000000000000000000000000000001000;

  uint public numOperator;
  bool public alreadyInit;
  mapping(address => bool) operators;


  modifier doInit() {
    if(!alreadyInit){
      operators[LIGHT_CLIENT_CONTRACT] = true;
      operators[VALIDATOR_SET_CONTRACT] = true;
      numOperator = 2;
      alreadyInit = true;
    }
    _;
  }

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


  function () external payable{
    if (msg.value>0){
      emit ReceiveDeposit(msg.sender, msg.value);
    }
  }

  function addOperator(address operator) external onlySystem doInit onlyOperatorNotExist(operator){
    operators[operator] = true;
    numOperator ++;
    emit NewOperator(operator);
  }

  function removeOperator(address operator) external onlySystem doInit onlyOperatorExist(operator){
    delete operators[operator];
    numOperator --;
    emit DeleteOperator(operator);
  }

  function claimRewards(address payable to, uint256 amount) external onlyOperator doInit rewardNotExceedLimit(amount){
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