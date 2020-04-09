pragma solidity 0.6.4;

import "./interface/IRelayerHub.sol";


contract RelayerHub is IRelayerHub {

  uint256 public constant INIT_REQUIRED_DEPOSIT =  1e20;
  uint256 public constant INIT_DUES =  1e17;
  address payable public constant INIT_SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;

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
    INIT_SYSTEM_REWARD_ADDR.transfer(r.dues);
    delete relayersExistMap[msg.sender];
    delete relayers[msg.sender];
    emit relayerUnRegister(msg.sender);
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
