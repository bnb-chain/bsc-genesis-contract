pragma solidity 0.6.4;

import "./lib/BytesToTypes.sol";
import "./lib/Memory.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./System.sol";
import "./lib/SafeMath.sol";


contract RelayerHub is IRelayerHub, System, IParamSubscriber {
    using SafeMath for uint256;

    uint256 public constant INIT_REQUIRED_DEPOSIT = 1e20;
    uint256 public constant INIT_DUES = 1e17;
    address public constant WHITELIST_1 = 0xb005741528b86F5952469d80A8614591E3c5B632;
    address public constant WHITELIST_2 = 0x446AA6E0DC65690403dF3F127750da1322941F3e;

    uint256 public requiredDeposit;
    uint256 public dues;

    mapping(address => manager) managers;
    mapping(address => bool) managersRegistered;
    mapping(address => bool) relayManagersExistMap;
    mapping(address => address) managersAndRelayers;
    mapping(address => bool) relayerExistsMap;

    struct manager {
        uint256 deposit;
        uint256 dues;
    }

    modifier onlyNonRegisteredManager() {
        require(relayManagersExistMap[msg.sender], "manager does not exist");
        _;
    }

    modifier onlyRegisteredManager() {
        require(relayManagersExistMap[msg.sender], "manager does not exist");
        require(managersRegistered[msg.sender], "manager not registered");
        _;
    }

    modifier noProxy() {
        require(msg.sender == tx.origin, "no proxy is allowed");
        _;
    }

    event relayerRegister(address _relayer);
    event relayerUnRegister(address _relayer);
    event paramChange(string key, bytes value);

    event removeManagerByGovEvent(address _removedManager);
    event addManagerByGovEvent(address _addedManager);
    event registerManagerEvent(address _registeredManager);
    event addRelayerEvent(address _relayerToBeAdded);
    event removeRelayerEvent(address _removedRelayer);
    event updateRelayerEvent(address _from, address _to);


    function init() external onlyNotInit {
        requiredDeposit = INIT_REQUIRED_DEPOSIT;
        dues = INIT_DUES;
        addInitRelayer(WHITELIST_1);
        addInitRelayer(WHITELIST_2);
        alreadyInit = true;
    }

    function addInitRelayer(address addr) internal {
        managers[addr] = manager(requiredDeposit, dues);
        managersRegistered[addr] = true;
        relayManagersExistMap[addr] = true;
        managersAndRelayers[addr] = addr; // fixme current relayer
        relayerExistsMap[addr] = true;
    }

    /*********************** Param update ********************************/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        if (Memory.compareStrings(key, "requiredDeposit")) {
            require(value.length == 32, "length of requiredDeposit mismatch");
            uint256 newRequiredDeposit = BytesToTypes.bytesToUint256(32, value);
            require(newRequiredDeposit > 1 && newRequiredDeposit <= 1e21 && newRequiredDeposit > dues, "the requiredDeposit out of range");
            requiredDeposit = newRequiredDeposit;
        } else if (Memory.compareStrings(key, "dues")) {
            require(value.length == 32, "length of dues mismatch");
            uint256 newDues = BytesToTypes.bytesToUint256(32, value);
            require(newDues > 0 && newDues < requiredDeposit, "the dues out of range");
            dues = newDues;
        } else if (Memory.compareStrings(key, "addManager")) {

            require(value.length == 20, "length of manager address mismatch");
            address newManager = BytesToTypes.bytesToAddress(20, value);
            addManagerByGov(newManager);

        } else if (Memory.compareStrings(key, "removeManager")) {

            require(value.length == 20, "length of manager address mismatch");
            address payable managerAddress = payable(BytesToTypes.bytesToAddress(20, value));
            removeManagerByGov(managerAddress);

        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    function removeManagerByGov(address payable managerToBeRemoved) internal {
        removeManagerHelper(managerToBeRemoved);
    }

    function removeManager() external {
        // here the manager removes himself
        removeManagerHelper(payable(msg.sender));
    }

    function removeManagerHelper(address payable managerAddress) internal {
        // check if the manager address already exists
        require(relayManagersExistMap[managerAddress], "manager doesn't exist");

        address relayerAddress = managersAndRelayers[managerAddress];

        delete (relayManagersExistMap[managerAddress]);
        delete (managersAndRelayers[managerAddress]);

        manager memory a = managers[managerAddress];
        managerAddress.transfer(a.deposit.sub(a.dues));
        address payable systemPayable = payable(address(uint160(SYSTEM_REWARD_ADDR)));
        systemPayable.transfer(a.dues);

        delete (managers[managerAddress]);
        delete (managersRegistered[managerAddress]);

        // emit success event
        emit removeManagerByGovEvent(managerAddress);
        if (relayerAddress != address(0)) {
            delete (relayerExistsMap[relayerAddress]);
            emit removeRelayerEvent(relayerAddress);
        }
    }

    function addManagerByGov(address managerToBeAdded) internal {
        require(!relayManagersExistMap[managerToBeAdded], "manager already exists");
        require(!isContract(managerToBeAdded), "contract is not allowed to be a manager");

        relayManagersExistMap[managerToBeAdded] = true;

        emit addManagerByGovEvent(managerToBeAdded);
    }

    function registerManager() internal onlyNonRegisteredManager {
        require(msg.value == requiredDeposit, "deposit value is not exactly the same");
        managers[msg.sender] = manager(requiredDeposit, dues);
        managersRegistered[msg.sender] = true;
        emit registerManagerEvent(msg.sender);
    }

    // updateRelayer() can be used to add relayer for the first time, update it in future and remove it
    // in case of removal we can simply update it to a non-existing account
    function updateRelayer(address relayerToBeAdded) public onlyRegisteredManager {
        require(!relayerExistsMap[relayerToBeAdded], "relayer already exists");
        require(!isContract(relayerToBeAdded), "contract is not allowed to be a relayer");

        address oldRelayer = managersAndRelayers[msg.sender];
        relayerExistsMap[oldRelayer] = false;

        managersAndRelayers[msg.sender] = relayerToBeAdded;
        relayerExistsMap[relayerToBeAdded] = true;

        emit updateRelayerEvent(oldRelayer, relayerToBeAdded);
    }

    function registerManagerAddRelayer(address relayer) external payable onlyNonRegisteredManager {
        registerManager();
        updateRelayer(relayer);
    }

    function isRelayer(address relayerAddress) external override view returns (bool){
        return relayerExistsMap[relayerAddress];
    }

    // TODO remove just for testing
    function isManager(address relayerAddress) external view returns (bool){
        return relayManagersExistMap[relayerAddress];
    }
}
