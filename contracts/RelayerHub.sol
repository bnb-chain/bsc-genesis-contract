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

    uint256 public requiredDeposit; // have to keep it to not break the storage layout
    uint256 public dues;

    mapping(address => relayer) relayers; // old map holding the relayers which are to be allowed safe exit
    mapping(address => bool) relayersExistMap;

    struct relayer {
        uint256 deposit;
        uint256 dues;
    }

    mapping(address => uint256) managerDues;
    mapping(address => bool) managersRegistered;
    mapping(address => bool) relayManagersExistMap;
    mapping(address => address) managerToRelayer;
    mapping(address => bool) currentRelayers;

    bool public whitelistInitDone;

    modifier onlyNonRegisteredManager() {
        require(relayManagersExistMap[msg.sender], "manager does not exist");
        require(!managersRegistered[msg.sender], "manager already registered");
        _;
    }

    modifier onlyRegisteredManager() {
        require(managersRegistered[msg.sender], "manager not registered");
        _;
    }

    modifier exist() {
        require(relayersExistMap[msg.sender], "relayer do not exist");
        _;
    }

    event relayerRegister(address _relayer);
    event relayerUnRegister(address _relayer);
    event paramChange(string key, bytes value);

    event removeManagerEvent(address _removedManager);
    event addManagerByGovEvent(address _addedManager);
    event registerManagerEvent(address _registeredManager);
    event updateRelayerEvent(address _from, address _to);

    function init() external onlyNotInit {
        requiredDeposit = INIT_REQUIRED_DEPOSIT;
        dues = INIT_DUES;
        alreadyInit = true;
    }

    function unregister() external exist onlyInit {
        relayer memory r = relayers[msg.sender];
        msg.sender.transfer(r.deposit.sub(r.dues));
        address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
        systemPayable.transfer(r.dues);
        delete relayersExistMap[msg.sender];
        delete relayers[msg.sender];
        emit relayerUnRegister(msg.sender);
    }

    function whitelistInit() external {
        require(!whitelistInitDone, "the whitelists already updated");
        addInitRelayer(WHITELIST_1);
        addInitRelayer(WHITELIST_2);
        whitelistInitDone = true;
    }

    function addInitRelayer(address addr) internal {
        managerDues[addr] = dues;
        managersRegistered[addr] = true;
        relayManagersExistMap[addr] = true;
        managerToRelayer[addr] = addr; // for the current whitelisted relayers we are keeping manager and relayer address the same
        currentRelayers[addr] = true;
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
            removeManager(managerAddress);

        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    function removeManagerByHimself() external {
        // here the manager removes himself
        removeManager(payable(msg.sender));
    }

    function removeManager(address payable managerAddress) internal {
        // check if the manager address already exists
        require(relayManagersExistMap[managerAddress], "manager doesn't exist");

        address relayerAddress = managerToRelayer[managerAddress];

        delete (relayManagersExistMap[managerAddress]);
        delete (managerToRelayer[managerAddress]);

        uint256 mDues = managerDues[managerAddress];
        address payable systemPayable = payable(address(uint160(SYSTEM_REWARD_ADDR)));
        systemPayable.transfer(mDues);

        delete (managerDues[managerAddress]);
        delete (managersRegistered[managerAddress]);

        // emit success event
        emit removeManagerEvent(managerAddress);
        if (relayerAddress != address(0)) {
            delete (currentRelayers[relayerAddress]);
            emit updateRelayerEvent(relayerAddress, address(0));
        }
    }

    function addManagerByGov(address managerToBeAdded) internal {
        require(!relayManagersExistMap[managerToBeAdded], "manager already exists");
        require(!isContract(managerToBeAdded), "contract is not allowed to be a manager");

        relayManagersExistMap[managerToBeAdded] = true;

        emit addManagerByGovEvent(managerToBeAdded);
    }

    // updateRelayer() can be used to add relayer for the first time, update it in future and remove it
    // in case of removal we can simply update it to a non-existing account
    function updateRelayer(address relayerToBeAdded) public onlyRegisteredManager {
        // todo this is a bug which the current test doesn't capture. Write test which captures this and then add separate case for 0 address
        require(!currentRelayers[relayerToBeAdded], "relayer already exists");
        require(!isContract(relayerToBeAdded), "contract is not allowed to be a relayer");

        address oldRelayer = managerToRelayer[msg.sender];
        delete currentRelayers[oldRelayer];

        managerToRelayer[msg.sender] = relayerToBeAdded;
        currentRelayers[relayerToBeAdded] = true;

        emit updateRelayerEvent(oldRelayer, relayerToBeAdded);
    }

    function registerManagerAddRelayer(address r) external payable onlyNonRegisteredManager {
        // register manager
        managerDues[msg.sender] = dues;
        managersRegistered[msg.sender] = true;
        emit registerManagerEvent(msg.sender);

        updateRelayer(r);
    }

    function isRelayer(address relayerAddress) external override view returns (bool){
        return currentRelayers[relayerAddress];
    }

    // TODO remove just for testing
    function isManager(address relayerAddress) external view returns (bool){
        return relayManagersExistMap[relayerAddress];
    }
}
