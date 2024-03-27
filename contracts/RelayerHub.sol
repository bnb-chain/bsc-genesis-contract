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

    uint256 internal requiredDeposit; // have to keep it to not break the storage layout
    uint256 internal dues;

    mapping(address => relayer) deprecatedRelayers; // old map holding the relayers which are to be allowed safe exit
    mapping(address => bool) relayersExistMap;

    struct relayer {
        uint256 deposit;
        uint256 dues;
    }

    mapping(address => bool) relayManagersExistMap;
    mapping(address => address) managerToRelayer;
    mapping(address => bool) currentRelayers;
    mapping(address => bool) provisionalRelayers;
    mapping(address => address) managerToProvisionalRelayer;

    bool public whitelistInitDone;

    modifier onlyManager() {
        require(relayManagersExistMap[msg.sender], "manager does not exist");
        _;
    }

    modifier exist() {
        require(relayersExistMap[msg.sender], "relayer do not exist");
        _;
    }

    modifier onlyProvisionalRelayer() {
        require(provisionalRelayers[msg.sender], "relayer is not a provisional relayer");
        _;
    }

    event relayerUnRegister(address _relayer);
    event paramChange(string key, bytes value);

    event managerRemoved(address _removedManager);
    event managerAdded(address _addedManager);
    event relayerUpdated(address _from, address _to);
    event relayerAddedProvisionally(address _relayer);

    function init() external onlyNotInit {
        requiredDeposit = INIT_REQUIRED_DEPOSIT;
        dues = INIT_DUES;
        alreadyInit = true;
    }

    function unregister() external exist onlyInit {
        relayer memory r = deprecatedRelayers[msg.sender];
        msg.sender.transfer(r.deposit.sub(r.dues));
        address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
        systemPayable.transfer(r.dues);
        delete relayersExistMap[msg.sender];
        delete deprecatedRelayers[msg.sender];
        emit relayerUnRegister(msg.sender);
    }

    function whitelistInit() external {
        require(!whitelistInitDone, "the whitelists already updated");
        addInitRelayer(WHITELIST_1);
        addInitRelayer(WHITELIST_2);
        whitelistInitDone = true;
    }

    function addInitRelayer(address addr) internal {
        relayManagersExistMap[addr] = true;
        managerToRelayer[addr] = addr; // for the current whitelisted relayers we are keeping manager and relayer address the same
        currentRelayers[addr] = true;
        emit managerAdded(addr);
        emit relayerUpdated(address(0), addr);
    }

    /*----------------- Param update -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        if (Memory.compareStrings(key, "addManager")) {
            require(value.length == 20, "length of manager address mismatch");
            address newManager = BytesToTypes.bytesToAddress(20, value);
            addManagerByGov(newManager);
        } else if (Memory.compareStrings(key, "removeManager")) {
            require(value.length == 20, "length of manager address mismatch");
            address managerAddress = BytesToTypes.bytesToAddress(20, value);
            removeManager(managerAddress);
        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    function removeManagerByHimself() external {
        // here the manager removes himself
        removeManager(msg.sender);
    }

    function removeManager(address managerAddress) internal {
        // check if the manager address already exists
        require(relayManagersExistMap[managerAddress], "manager doesn't exist");

        address relayerAddress = managerToRelayer[managerAddress];

        delete (relayManagersExistMap[managerAddress]);
        delete (managerToRelayer[managerAddress]);

        delete (provisionalRelayers[managerToProvisionalRelayer[managerAddress]]);
        delete (managerToProvisionalRelayer[managerAddress]);

        // emit success event
        emit managerRemoved(managerAddress);
        if (relayerAddress != address(0)) {
            delete (currentRelayers[relayerAddress]);
            emit relayerUpdated(relayerAddress, address(0));
        }
    }

    function addManagerByGov(address managerToBeAdded) internal {
        require(!relayManagersExistMap[managerToBeAdded], "manager already exists");

        relayManagersExistMap[managerToBeAdded] = true;

        emit managerAdded(managerToBeAdded);
    }

    // updateRelayer() can be used to add relayer for the first time, update it in future and remove it
    // in case of removal, we set relayerToBeAdded to be address(0)
    function updateRelayer(address relayerToBeAdded) external onlyManager {
        require(!isContract(relayerToBeAdded), "contract is not allowed to be a relayer");

        if (relayerToBeAdded != address(0)) {
            require(!currentRelayers[relayerToBeAdded], "relayer already exists");
            provisionalRelayers[relayerToBeAdded] = true;
            managerToProvisionalRelayer[msg.sender] = relayerToBeAdded;
        } else {
            address oldRelayer = managerToRelayer[msg.sender];
            address oldProvisionalRelayer = managerToProvisionalRelayer[msg.sender];
            delete managerToRelayer[msg.sender];
            delete currentRelayers[oldRelayer];
            delete provisionalRelayers[oldProvisionalRelayer];
            delete managerToProvisionalRelayer[msg.sender];
            emit relayerUpdated(oldRelayer, relayerToBeAdded);
            return;
        }

        emit relayerAddedProvisionally(relayerToBeAdded);
    }

    // acceptBeingRelayer needs to be called by the relayer after being added provisionally.
    // This 2 step process of relayer updating is required to avoid having a contract as a relayer.
    function acceptBeingRelayer(address manager) external onlyProvisionalRelayer {
        // ensure msg.sender is not contract and it is not a proxy
        require(!isContract(msg.sender), "provisional relayer is a contract");
        require(tx.origin == msg.sender, "provisional relayer is a proxy");
        require(managerToProvisionalRelayer[manager] == msg.sender, "provisional is not set for this manager");

        address oldRelayer = managerToRelayer[manager];

        currentRelayers[msg.sender] = true;
        managerToRelayer[manager] = msg.sender;

        delete provisionalRelayers[msg.sender];
        delete managerToProvisionalRelayer[manager];
        delete currentRelayers[oldRelayer];
        emit relayerUpdated(oldRelayer, msg.sender);
    }

    function isRelayer(address relayerAddress) external view override returns (bool) {
        return currentRelayers[relayerAddress];
    }

    function isProvisionalRelayer(address relayerAddress) external view returns (bool) {
        return provisionalRelayers[relayerAddress];
    }

    function isManager(address managerAddress) external view returns (bool) {
        return relayManagersExistMap[managerAddress];
    }
}
