pragma solidity ^0.5.0;
import { System } from "./System.sol";

contract SystemReward is System{
    uint256 public constant MAXREWARDS = 1e18;

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

    event NewOperator(address indexed operator);
    event DeleteOperator(address indexed operator);
    event Reward(address indexed to, uint256 indexed amount);

    constructor(address[] _operators) public {
        for (uint i=0; i<studentList.length; i++) {
            operators[_operators[i]] = true;
        }
        numOperator = _operators.length;
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

    function claimRewards(address payable to, uint256 amount) external onlyOperator {
        require(amount<=MAXREWARDS, "the claim amount exceed the limit");
        uint256 actualAmount = amount < this.balance ? amount : this.balance;
        to.transfer(actualAmount);
        emit Reward(to, actualAmount);
    }

    function isOperator(address addr) view returns (bool){
        return operators[addr];
    }
}