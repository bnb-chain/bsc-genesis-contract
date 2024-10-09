pragma solidity 0.6.4;

import "../lib/0.6.x/BytesToTypes.sol";
import "../lib/0.6.x/Memory.sol";
import "../interface/0.6.x/IRelayerHub.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../System.sol";
import "../lib/0.6.x/SafeMath.sol";

contract RelayerHub is IRelayerHub, System, IParamSubscriber {
    using SafeMath for uint256;

    uint256 public constant INIT_REQUIRED_DEPOSIT = 1e20;
    uint256 public constant INIT_DUES = 1e17;

    uint256 internal requiredDeposit; // have to keep it to not break the storage layout
    uint256 internal dues;

    mapping(address => relayer) deprecatedRelayers; // old map holding the relayers which are to be allowed safe exit
    mapping(address => bool) relayersExistMap;

    struct relayer {
        uint256 deposit;
        uint256 dues;
    }

    mapping(address => bool) relayManagersExistMap;
    mapping(address => address) managerToRelayer;  // @dev deprecated
    mapping(address => bool) currentRelayers;
    mapping(address => bool) provisionalRelayers;
    mapping(address => address) managerToProvisionalRelayer;  // @dev deprecated

    bool public whitelistInitDone;  // @dev deprecated

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

    event paramChange(string key, bytes value);  // @dev deprecated
    event managerRemoved(address _removedManager);  // @dev deprecated
    event managerAdded(address _addedManager);  // @dev deprecated
    event relayerUpdated(address _from, address _to);  // @dev deprecated
    event relayerAddedProvisionally(address _relayer);  // @dev deprecated

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
        revert("deprecated");
    }

    /*----------------- Param update -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        revert("deprecated");
    }

    function removeManagerByHimself() external {
        revert("deprecated");
    }

    // updateRelayer() can be used to add relayer for the first time, update it in future and remove it
    // in case of removal, we set relayerToBeAdded to be address(0)
    function updateRelayer(address relayerToBeAdded) external onlyManager {
        revert("deprecated");
    }

    // acceptBeingRelayer needs to be called by the relayer after being added provisionally.
    // This 2 step process of relayer updating is required to avoid having a contract as a relayer.
    function acceptBeingRelayer(address manager) external onlyProvisionalRelayer {
        revert("deprecated");
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
