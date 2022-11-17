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

    uint256 public requiredDeposit;
    uint256 public dues;

    mapping(address => admin) admins;
    mapping(address => bool) relayAdminsExistMap;
    mapping(address => address) adminsAndRelayers;
    mapping(address => bool) relayerExistsMap;

    struct admin {
        uint256 deposit;
        uint256 dues;
    }

    modifier onlyNonRegisteredAdmin() {
        require(relayAdminsExistMap[msg.sender], "admin does not exist");
        _;
    }

    modifier onlyRegisteredAdmin() {
        require(relayAdminsExistMap[msg.sender], "admin does not exist");
        require(admins[msg.sender], "admin not registered");
        _;
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
        require(!relayerExistsMap[msg.sender], "relayer already exists");
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


    function init() external onlyNotInit {
        requiredDeposit = INIT_REQUIRED_DEPOSIT;
        dues = INIT_DUES;
        alreadyInit = true;
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
        } else if (Memory.compareStrings(key, "addAdmin")) {

            require(value.length == 20, "length of admin address mismatch");
            address newAdmin = BytesToTypes.bytesToAddress(20, value);
            addAdminAddress(newAdmin);

        } else if (Memory.compareStrings(key, "removeAdmin")) {

            require(value.length == 20, "length of admin address mismatch");
            address admin = BytesToTypes.bytesToAddress(20, value);
            removeAdminAddress(admin);

        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    function removeAdminAddress(address adminToBeRemoved) external onlyGov {
        removeAdminHelper(adminToBeRemoved);
    }

    function removeAdmin() external onlyRegisteredAdmin {
        // here the admin removes himself
        removeAdminHelper(msg.sender);
    }

    function removeAdminHelper(address adminAddress) {
        // check if the admin address already exists
        require(relayAdminsExistMap[adminAddress], "admin doesn't exist");

        relayer memory relayerAddress = adminsAndRelayers[adminAddress];

        delete (relayAdminsExistMap[adminAddress]);
        delete (adminsAndRelayers[adminAddress]);

        admin memory a = admins[adminAddress];
        adminAddress.transfer(a.deposit.sub(a.dues));
        address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
        systemPayable.transfer(a.dues);

        delete (admins[adminAddress]);

        // emit success event
        emit removeAdminAddress(adminAddress);
        if (relayerAddress != address(0)) {
            emit removeRelayer(relayerAddress);
        }
    }

    function addAdminAddress(address adminToBeAdded) external onlyGov {
        require(!relayAdminsExistMap[adminToBeAdded], "admin already exists");

        relayAdminsExistMap[adminToBeAdded] = true;

        emit addAdminAddress(adminToBeAdded);
    }

    function registerAdmin() external payable onlyNonRegisteredAdmin {
        require(msg.value == requiredDeposit, "deposit value is not exactly the same");
        admins[msg.sender] = admin(requiredDeposit, dues);
        emit registerAdmin(msg.sender);
    }

    function addRelayer(address relayerToBeAdded) external onlyRegisteredAdmin noExist notContract noProxy {
        adminsAndRelayers[msg.sender] = relayerToBeAdded;
        relayerExistsMap[relayerToBeAdded] = true;
        emit addRelayer(relayerToBeAdded);
    }

    function registerAdminAddRelayer(address relayer) external payable onlyNonRegisteredAdmin {
        registerAdmin();
        addRelayer(relayer);
    }

    function removeRelayer() external onlyRegisteredAdmin {
        require(adminsAndRelayers[msg.sender], "relayer doesn't exist for this admin");

        relayer memory r = adminsAndRelayers[msg.sender];

        delete (relayerExistsMap[r]);
        delete (adminsAndRelayers[msg.sender]);

        emit removeRelayer(r);
    }

    function verifyRelayer(address relayerAddress) external returns (bool){
        return relayerExistsMap[relayerAddress];
    }
}
