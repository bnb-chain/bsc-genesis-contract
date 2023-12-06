pragma solidity 0.6.4;

import "./System.sol";
import "./lib/Memory.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/ISystemReward.sol";

contract SystemReward is System, IParamSubscriber, ISystemReward {
  uint256 public constant MAX_REWARDS/*_FOR_RELAYER*/ = 1e18;
  uint256 public constant MAX_REWARDS_FOR_FINALITY = 5e18;

  uint public numOperator;
  mapping(address => bool) operators;

  modifier doInit() {
    if (!alreadyInit) {
      operators[LIGHT_CLIENT_ADDR] = true;
      operators[INCENTIVIZE_ADDR] = true;
      numOperator = 2;
      alreadyInit = true;
    }
    _;
  }

  modifier onlyOperator() {
    require(operators[msg.sender],"only operator is allowed to call the method");
    _;
  }

  event rewardTo(address indexed to, uint256 amount);
  event rewardEmpty();
  event receiveDeposit(address indexed from, uint256 amount);
  event addOperator(address indexed operator);
  event deleteOperator(address indexed operator);
  event paramChange(string key, bytes value);

  receive() external payable{
    if (msg.value>0) {
      emit receiveDeposit(msg.sender, msg.value);
    }
  }

  function claimRewards(address payable to, uint256 amount) external override(ISystemReward) doInit onlyOperator returns (uint256) {
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if (actualAmount > MAX_REWARDS) {
      actualAmount = MAX_REWARDS;
    }
    if (actualAmount != 0) {
      to.transfer(actualAmount);
      emit rewardTo(to, actualAmount);
    } else {
      emit rewardEmpty();
    }
    return actualAmount;
  }

  function claimRewardsforFinality(address payable to, uint256 amount) external override(ISystemReward) doInit onlyOperator returns (uint256) {
    uint256 actualAmount = amount < address(this).balance ? amount : address(this).balance;
    if (actualAmount > MAX_REWARDS_FOR_FINALITY) {
      actualAmount = MAX_REWARDS_FOR_FINALITY;
    }
    if (actualAmount != 0) {
      to.transfer(actualAmount);
      emit rewardTo(to, actualAmount);
    } else {
      emit rewardEmpty();
    }
    return actualAmount;
  }

  function isOperator(address addr) external view returns (bool) {
    return operators[addr];
  }

  function updateParam(string calldata key, bytes calldata value) onlyGov external override {
    if (Memory.compareStrings(key, "addOperator")) {
      bytes memory valueLocal = value;
      require(valueLocal.length == 20, "length of value for addOperator should be 20");
      address operatorAddr;
      assembly {
        operatorAddr := mload(add(valueLocal, 20))
      }
      operators[operatorAddr] = true;
      emit addOperator(operatorAddr);
    } else if (Memory.compareStrings(key, "deleteOperator")) {
      bytes memory valueLocal = value;
      require(valueLocal.length == 20, "length of value for deleteOperator should be 20");
      address operatorAddr;
      assembly {
        operatorAddr := mload(add(valueLocal, 20))
      }
      delete operators[operatorAddr];
      emit deleteOperator(operatorAddr);
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }
}
