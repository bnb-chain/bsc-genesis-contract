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
    event editRelayerEvent(address _relayerToBeAdded);
    event removeRelayerEvent(address _removedRelayer);


    function init() external onlyNotInit {
        requiredDeposit = INIT_REQUIRED_DEPOSIT;
        dues = INIT_DUES;
        alreadyInit = true;

        // todo initialise the currently existing Managers and their relayer keys

        managers[WHITELIST_1] = manager(requiredDeposit, dues);
        managers[WHITELIST_2] = manager(requiredDeposit, dues);

        managersRegistered[WHITELIST_1] = true;
        managersRegistered[WHITELIST_2] = true;

        relayManagersExistMap[WHITELIST_1] = true;
        relayManagersExistMap[WHITELIST_2] = true;

        managersAndRelayers[WHITELIST_1] = WHITELIST_1; // fixme current relayer
        managersAndRelayers[WHITELIST_2] = WHITELIST_2; // fixme current relayer

        // fixme initialise relayerExistsMap
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

    function removeManager() external onlyRegisteredManager {
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

    function addRelayer(address relayerToBeAdded) internal onlyRegisteredManager noProxy {
        require(!relayerExistsMap[relayerToBeAdded], "relayer already exists");
        require(!isContract(relayerToBeAdded), "contract is not allowed to be a relayer");

        managersAndRelayers[msg.sender] = relayerToBeAdded;
        relayerExistsMap[relayerToBeAdded] = true;
        emit editRelayerEvent(relayerToBeAdded);
    }

    function editRelayer(address relayerToBeAdded) external onlyRegisteredManager noProxy {
        require(!relayerExistsMap[relayerToBeAdded], "relayer already exists");
        require(!isContract(relayerToBeAdded), "contract is not allowed to be a relayer");

        managersAndRelayers[msg.sender] = relayerToBeAdded;
        relayerExistsMap[relayerToBeAdded] = true;
        emit editRelayerEvent(relayerToBeAdded);
    }

    function registerManagerAddRelayer(address relayer) external payable onlyNonRegisteredManager {
        registerManager();
        addRelayer(relayer);
    }

    function removeRelayer() external onlyRegisteredManager {
        if (managersAndRelayers[msg.sender] == address(0)) {
            require(false, "relayer doesn't exist for this manager");
        }

        address r = managersAndRelayers[msg.sender];

        delete (relayerExistsMap[r]);
        delete (managersAndRelayers[msg.sender]);

        emit removeRelayerEvent(r);
    }

    function isRelayer(address relayerAddress) external override view returns (bool){
        return relayerExistsMap[relayerAddress];
    }
}
