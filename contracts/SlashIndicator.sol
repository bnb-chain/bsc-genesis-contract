pragma solidity 0.6.4;
import "./System.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/Memory.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IApplication.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/ICrossChain.sol";
import "./rlp/CmnPkg.sol";
import "./rlp/RLPEncode.sol";

contract SlashIndicator is ISlashIndicator,System,IParamSubscriber, IApplication{
  using RLPEncode for *;

  uint256 public constant MISDEMEANOR_THRESHOLD = 50;
  uint256 public constant FELONY_THRESHOLD = 150;
  uint256 public constant BSC_RELAYER_REWARD = 1e16;


  // State of the contract
  address[] validators;
  mapping(address => Indicator) indicators;
  uint256 public previousHeight;
  uint256 public  misdemeanorThreshold;
  uint256 public  felonyThreshold;
  uint256 public  bscRelayerReward;

  event validatorSlashed(address indexed validator);
  event indicatorCleaned();
  event paramChange(string key, bytes value);

  event knownResponse(uint32 code);
  event unKnownResponse(uint32 code);
  event crashResponse();

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

  function init() external onlyNotInit{
    misdemeanorThreshold = MISDEMEANOR_THRESHOLD;
    felonyThreshold = FELONY_THRESHOLD;
    bscRelayerReward = BSC_RELAYER_REWARD;
    alreadyInit = true;
  }

  /*********************** Implement cross chain app ********************************/
  function handleSynPackage(uint8, bytes calldata) onlyCrossChainContract external override returns(bytes memory){
    require(false, "receive unexpected syn package");
  }

  function handleAckPackage(uint8, bytes calldata msgBytes) external override {
    (CmnPkg.CommonAckPackage memory response, bool ok) = CmnPkg.decodeCommonAckPackage(msgBytes);
    if(ok){
      emit knownResponse(response.code);
    }else{
      emit unKnownResponse(response.code);
    }
    return;
  }

  function handleFailAckPackage(uint8, bytes calldata) external override {
    emit crashResponse();
    return;
  }

  /*********************** External func ********************************/
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
      ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendPackage(SLASH_CHANNELID, encodeSlashPackage(validator), 0, bscRelayerReward);
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


  /*********************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) override external onlyInit onlyGov{
    if (Memory.compareStrings(key,"misdemeanorThreshold")){
      require(value.length == 32, "length of misdemeanorThreshold mismatch");
      uint256 newMisdemeanorThreshold = BytesToTypes.bytesToUint256(32, value);
      require(newMisdemeanorThreshold >=10 && newMisdemeanorThreshold < felonyThreshold, "the misdemeanorThreshold out of range");
      misdemeanorThreshold = newMisdemeanorThreshold;
    }else if(Memory.compareStrings(key,"felonyThreshold")){
      require(value.length == 32, "length of felonyThreshold mismatch");
      uint256 newFelonyThreshold = BytesToTypes.bytesToUint256(32, value);
      require(newFelonyThreshold >20 && newFelonyThreshold <= 1000, "the felonyThreshold out of range");
      felonyThreshold = newFelonyThreshold;
    }else if(Memory.compareStrings(key,"bscRelayerReward")){
      require(value.length == 32, "length of bscRelayerReward mismatch");
      uint256 newBscRelayerReward = BytesToTypes.bytesToUint256(32, value);
      require(newBscRelayerReward > 1e18, "the bscRelayerReward out of range");
      bscRelayerReward = newBscRelayerReward;
    }else{
      require(false, "unknown param");
    }
    emit paramChange(key,value);
  }

  /*********************** query api ********************************/
  function getSlashIndicator(address validator) external view returns (uint256,uint256){
    Indicator memory indicator = indicators[validator];
    return (indicator.height, indicator.count);
  }

  function encodeSlashPackage(address valAddr) internal view returns (bytes memory) {
    bytes[] memory elements = new bytes[](4);
    elements[0] = valAddr.encodeAddress();
    elements[1] = uint256(block.number).encodeUint();
    elements[2] = uint256(bscChainID).encodeUint();
    elements[3] = uint256(block.timestamp).encodeUint();
    return elements.encodeList();
  }
}