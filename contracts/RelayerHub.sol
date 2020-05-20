pragma solidity 0.6.4;

import "./Seriality/BytesToTypes.sol";
import "./Seriality/Memory.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./System.sol";


contract RelayerHub is IRelayerHub, System, IParamSubscriber{

  uint256 public constant INIT_REQUIRED_DEPOSIT =  1e20;
  uint256 public constant INIT_DUES =  1e17;

  uint256 public requiredDeposit;
  uint256 public dues;
  bool public alreadyInit;

  mapping(address =>relayer) relayers;
  mapping(address =>bool) relayersExistMap;

  struct relayer{
    uint256 deposit;
    uint256  dues;
  }

  modifier onlyNotInit() {
    require(!alreadyInit, "the contract already init");
    _;
  }

  modifier onlyInit() {
    require(alreadyInit, "the contract not init yet");
    _;
  }

  modifier notContract() {
    require(!isContract(msg.sender), "contract is not allowed to be a relayer");
    _;
  }

  modifier noExist() {
    require(!relayersExistMap[msg.sender], "relayer already exist");
    _;
  }

  modifier exist() {
    require(relayersExistMap[msg.sender], "relayer do not exist");
    _;
  }

  event relayerRegister(address _relayer);
  event relayerUnRegister(address _relayer);
  event paramChange(string key, bytes value);


  function init() external onlyNotInit{
    requiredDeposit = INIT_REQUIRED_DEPOSIT;
    dues = INIT_DUES;
    alreadyInit = true;
  }

  function register() payable external noExist onlyInit notContract{
    require(msg.value == requiredDeposit, "deposit value is not exactly the same");
    relayers[msg.sender] = relayer(requiredDeposit, dues);
    relayersExistMap[msg.sender] = true;
    emit relayerRegister(msg.sender);
  }

  function  unregister() external exist onlyInit{
    relayer memory r = relayers[msg.sender];
    msg.sender.transfer(r.deposit-r.dues);
    address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
    systemPayable.transfer(r.dues);
    delete relayersExistMap[msg.sender];
    delete relayers[msg.sender];
    emit relayerUnRegister(msg.sender);
  }

  /*********************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) override external onlyInit onlyGov{
    if (Memory.compareStrings(key,"requiredDeposit")){
      require(value.length == 32, "length of requiredDeposit mismatch");
      uint256 newRequiredDeposit = BytesToTypes.bytesToUint256(32, value);
      require(newRequiredDeposit >=1 && newRequiredDeposit <= 1e21, "the requiredDeposit out of range");
      requiredDeposit = newRequiredDeposit;
    }else if(Memory.compareStrings(key,"dues")){
      require(value.length == 32, "length of dues mismatch");
      uint256 newDues = BytesToTypes.bytesToUint256(32, value);
      require(newDues >0 && newDues < requiredDeposit, "the dues out of range");
      dues = newDues;
    }else{
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  function isRelayer(address sender) external override view returns (bool){
    return relayersExistMap[sender];
  }

  function isContract(address addr) internal view returns (bool) {
    uint size;
    assembly { size := extcodesize(addr) }
    return size > 0;
  }
}
