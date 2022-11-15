pragma solidity 0.6.4;

import "./lib/BytesToTypes.sol";
import "./lib/Memory.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./System.sol";
import "./lib/SafeMath.sol";


contract RelayerHub is IRelayerHub, System, IParamSubscriber{
  using SafeMath for uint256;

  uint256 public constant INIT_REQUIRED_DEPOSIT =  1e20;
  uint256 public constant INIT_DUES =  1e17;

  uint256 public requiredDeposit;
  uint256 public dues;

  mapping(address =>relayer) relayers;
  mapping(address =>bool) relayersExistMap;

  mapping(address =>admin) admins;
  mapping(address =>bool) relayAdminsExistMap;
  mapping(address =>address) adminsAndRelayers;

  struct relayer{
    uint256 deposit;
    uint256  dues;
  }

  struct admin{
    uint256 deposit;
    uint256  dues;
  }

  modifier notContract() {
    require(!isContract(msg.sender), "contract is not allowed to be a relayer");
    _;
  }

  modifier noProxy() {
    require(msg.sender == tx.origin, "no proxy is allowed");
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

  modifier onlyAdmin() {
    require(relayAdminsExistMap[msg.sender], "admin does not exist");
    require(admins[msg.sender], "admin does not exist");
    _;
  }

  event relayerRegister(address _relayer);
  event relayerUnRegister(address _relayer);
  event paramChange(string key, bytes value);

  event removeAdminAddress(address _removedAdmin);
  event addAdminAddress(address _addedAdmin);
  event registerAdmin(address _registeredAdmin);
  event addRelayer(address _relayerToBeAdded);
  event removeRelayer(address _removedRelayer);


  function init() external onlyNotInit{
    requiredDeposit = INIT_REQUIRED_DEPOSIT;
    dues = INIT_DUES;
    alreadyInit = true;
  }
  
  function register() external payable noExist onlyInit notContract noProxy{
    revert("register suspended");
  }
  

  function  unregister() external exist onlyInit{
    relayer memory r = relayers[msg.sender];
    msg.sender.transfer(r.deposit.sub(r.dues));
    address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
    systemPayable.transfer(r.dues);
    delete relayersExistMap[msg.sender];
    delete relayers[msg.sender];
    emit relayerUnRegister(msg.sender);
  }

  /*********************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov{
    if (Memory.compareStrings(key,"requiredDeposit")) {
      require(value.length == 32, "length of requiredDeposit mismatch");
      uint256 newRequiredDeposit = BytesToTypes.bytesToUint256(32, value);
      require(newRequiredDeposit > 1 && newRequiredDeposit <= 1e21 && newRequiredDeposit > dues, "the requiredDeposit out of range");
      requiredDeposit = newRequiredDeposit;
    } else if (Memory.compareStrings(key,"dues")) {
      require(value.length == 32, "length of dues mismatch");
      uint256 newDues = BytesToTypes.bytesToUint256(32, value);
      require(newDues > 0 && newDues < requiredDeposit, "the dues out of range");
      dues = newDues;
    } else if (Memory.compareStrings(key,"addAdmin")) {
      // fixme check and parse value
      // addAdminAddress(...)
    } else if (Memory.compareStrings(key,"removeAdmin")) {
      // fixme check and parse value
      // removeAdminAddress(...)
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  function isRelayer(address sender) external override view returns (bool) {
    return relayersExistMap[sender];
  }

  function removeAdminAddress(address adminToBeRemoved) external onlyGov{
    // fixme more pre-checks if any

    // check if the admin address already exists
    require(relayAdminsExistMap[adminToBeRemoved], "admin doesn't exist");

    delete(relayAdminsExistMap[adminToBeRemoved]);
    delete(adminsAndRelayers[adminToBeRemoved]);

    // fixme transfer dues and deposits BNB -> check
    admin memory a = admins[adminToBeRemoved];
    adminToBeRemoved.transfer(a.deposit.sub(a.dues));
    address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
    systemPayable.transfer(a.dues);

    // emit success event
    emit removeAdminAddress(adminToBeRemoved);
  }

  function removeAdmin() external onlyAdmin {
  // here the admin removes himself
    // check if the admin address already exists
    require(relayAdminsExistMap[msg.sender], "admin doesn't exist");

    delete(relayAdminsExistMap[msg.sender]);
    delete(adminsAndRelayers[msg.sender]);

    // fixme transfer dues and deposits BNB -> check
    admin memory a = admins[msg.sender];
    msg.sender.transfer(a.deposit.sub(a.dues));
    address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
    systemPayable.transfer(a.dues);

    // emit success event
    emit removeAdminAddress(msg.sender);
  }

  function addAdminAddress(address adminToBeAdded) external onlyGov{
    require(!relayAdminsExistMap[adminToBeAdded], "admin already exists");

    relayAdminsExistMap[adminToBeAdded] = true;
    // admins[adminToBeAdded] = admin(requiredDeposit, dues); todo this will be done when admin registers himself in registerAdmin(?)

    emit addAdminAddress(adminToBeAdded);
  }

  function registerAdmin() external payable onlyAdmin {
//    require(relayAdminsExistMap[msg.sender], "admin not added by Gov yet");
    require(msg.value == requiredDeposit, "deposit value is not exactly the same");
    admins[msg.sender] = admin(requiredDeposit, dues);
    emit registerAdmin(msg.sender);
  }

  function addRelayer(address relayerToBeAdded) external onlyAdmin{
    adminsAndRelayers[msg.sender] = relayerToBeAdded;
    emit addRelayer(relayerToBeAdded);
  }

  function registerAdminAddRelayer(address relayer) external payable onlyAdmin {
    registerAdmin();
    addRelayer(relayer);
  }

  function removeRelayer() external onlyAdmin {
    require(adminsAndRelayers[msg.sender], "relayer doesn't exist for this admin");

    emit removeRelayer(adminsAndRelayers[msg.sender]);

    delete(adminsAndRelayers[msg.sender]);
  }
}
