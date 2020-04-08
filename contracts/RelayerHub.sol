pragma solidity 0.6.4;

contract RelayerHub {

  uint256 public constant INIT_REQUIRED_DEPOSIT =  1e20;
  uint256 public constant INIT_DUES =  1e17;

  uint256 public requiredDeposit;
  uint256 public dues;
  bool public alreadyInit;

  mapping(address =>relayer) relayers;

  struct relayer{
    uint256 deposit;
    uint256  dues;
    bool exist;
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
    require(!relayers[msg.sender].exist, "relayer already exist");
    _;
  }

  modifier exist() {
    require(relayers[msg.sender].exist, "relayer do not exist");
    _;
  }

  event relayerRegister(address _relayer);
  event relayerUnRegister(address _relayer);



  function init() external onlyNotInit{
    requiredDeposit = INIT_REQUIRED_DEPOSIT;
    dues = INIT_DUES;
    alreadyInit = true;
  }

  function register() payable external noExist onlyInit{
    require(msg.value == requiredDeposit, "deposit value is not exactly the same");
    relayers[msg.sender] = relayer(requiredDeposit, dues, true);
  }

  function  unregister() external exist onlyInit{
    relayer memory r = relayers[msg.sender];
    msg.sender.transfer(r.deposit-r.dues);
  }

  function isRelayer(address sender) external exist view returns (bool){
    return relayers[sender].exist;
  }

  function isContract(address addr) internal view returns (bool) {
    uint size;
    assembly { size := extcodesize(addr) }
    return size > 0;
  }
}
