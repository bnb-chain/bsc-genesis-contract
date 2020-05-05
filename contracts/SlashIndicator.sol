pragma solidity 0.6.4;
import "./System.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/Memory.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IBSCValidatorSet.sol";


contract SlashIndicator is ISlashIndicator,System{
  uint256 public constant MISDEMEANOR_THRESHOLD = 50;
  uint256 public constant FELONY_THRESHOLD = 150;

  // State of the contract
  address[] validators;
  mapping(address => Indicator) indicators;
  uint256 public previousHeight;
  bool public alreadyInit;
  uint256 public  misdemeanorThreshold;
  uint256 public  felonyThreshold;

  event validatorSlashed(address indexed validator);
  event indicatorCleaned();
  event paramChange(string key, bytes value);

  /* solium-disable-next-line */
  constructor() public {}

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

  modifier onlyNotInit() {
    require(!alreadyInit, "the contract already init");
    _;
  }

  modifier onlyInit() {
    require(alreadyInit, "the contract not init yet");
    _;
  }

  function init() public{
    misdemeanorThreshold = 50;
    felonyThreshold = 150;
    alreadyInit = true;
  }

  function slash(address validator) external onlyCoinbase onlyInit onlyOnce{
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
    if(indicator.count % felonyThreshold == 0){
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(validator);
    }else if (indicator.count % misdemeanorThreshold == 0){
      IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).misdemeanor(validator);
    }
    emit validatorSlashed(validator);
  }

  function clean() external override(ISlashIndicator) onlyValidatorContract onlyInit{
    uint n = validators.length;
    for(uint i = 0; i < n; i++){
      delete indicators[validators[n-i-1]];
      validators.pop();
    }
    emit indicatorCleaned();
  }


  /*********************** query api ********************************/
  function getSlashIndicator(address validator) external view returns (uint256,uint256){
    Indicator memory indicator = indicators[validator];
    return (indicator.height, indicator.count);
  }
}