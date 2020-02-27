pragma solidity ^0.5.15;
import { System } from "./System.sol";

contract SlashIndicator is System{
  uint256 public constant TOLERATE_DISTANCE = 1000;
  uint256 public constant SPRINT = 100;

  // State of the contract
  mapping(address => Indicator) indicators;
  uint256 public previousHeight;

  event ValidatorSlashed(address indexed validator);

  struct Indicator {
    uint256 height;
    uint256 count;
    bool exist;
  }

  modifier onlyOnce() {
    require(block.number > previousHeight, "can not slash twice in one block");
    _;
    previousHeight = block.number;
  }

  function slash(address validator) external onlySystem onlyOnce{
    Indicator memory indicator = indicators[validator];
    if (indicator.exist){
      if (block.number-indicator.height < TOLERATE_DISTANCE){
        indicator.count++;
        if (indicator.count % SPRINT == 0){
          emit ValidatorSlashed(validator);
        }
      }
    }else{
      indicator.exist = true;
    }
    indicator.height = block.number;
    indicators[validator] = indicator;
  }

  function getSlashIndicator(address validator) external view returns (uint256,uint256){
    Indicator memory indicator = indicators[validator];
    return (indicator.height, indicator.count);
  }
}