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
  address public constant INIT_RELAYER = 0xcca19442F5b3e5Fa71aaE69C092aC280e81Fd39f; // use other address for production

  uint256 public requiredDeposit;
  uint256 public dues;

  mapping(address =>relayer) relayers;
  mapping(address =>bool) relayersExistMap;

  struct relayer{
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

  modifier noExist(address newRelayer) {
    require(!relayersExistMap[newRelayer], "relayer already exist");
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
    relayersExistMap[INIT_RELAYER] = true;
  }

  function register(address newRelayer) external payable noExist(newRelayer) onlyInit notContract noProxy onlyRelayer{
    require(msg.value == requiredDeposit, "deposit value is not exactly the same");
    relayers[newRelayer] = relayer(requiredDeposit, dues);
    relayersExistMap[newRelayer] = true;
    emit relayerRegister(newRelayer);
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
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  function isRelayer(address sender) external override view returns (bool) {
    return relayersExistMap[sender];
  }
}
