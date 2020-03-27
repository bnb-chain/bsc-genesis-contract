pragma solidity 0.6.4;
import "./System.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IBSCValidatorSet.sol";


contract SlashIndicator is ISlashIndicator,System {
  uint256 public constant MISDEMEANOR_THRESHOLD = 50; // around 1.45 hours
  uint256 public constant FELONY_THRESHOLD = 150;     // around 4.3 hours
  address public constant  VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
  
  // State of the contract
  address[] validators;
  mapping(address => Indicator) indicators;
  uint256 public previousHeight;

  event validatorSlashed(address indexed validator);
  event indicatorCleaned();

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

  modifier onlyValidatorContract() {
    require(msg.sender == VALIDATOR_CONTRACT_ADDR, "the message sender must be validatorSet contract");
    _;
  }

  function slash(address validator) external onlySystem onlyOnce{
    Indicator memory indicator = indicators[validator];
    if (indicator.exist){
      indicator.count++;
    }else{
      indicator.exist = true;
      indicator.count = 1;
      validators.push(validator);
    }
    indicator.height = block.number;
    indicators[validator] = indicator;
    if(indicator.count % FELONY_THRESHOLD == 0){
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(validator);
    }else if (indicator.count % MISDEMEANOR_THRESHOLD == 0){
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).misdemeanor(validator);
    }
    emit validatorSlashed(validator);
  }

  function clean() external override(ISlashIndicator) onlyValidatorContract{
    uint n = validators.length;
    for(uint i = 0; i < n; i++){
      delete indicators[validators[n-i-1]];
      validators.pop();
    }
    emit indicatorCleaned();
  }

  function getSlashIndicator(address validator) external view returns (uint256,uint256){
    Indicator memory indicator = indicators[validator];
    return (indicator.height, indicator.count);
  }
}