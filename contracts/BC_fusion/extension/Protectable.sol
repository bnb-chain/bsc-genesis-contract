// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract Protectable is Initializable {
    /*----------------- storage -----------------*/
    bool private _paused;
    address private _protector;
    mapping(address => bool) public blackList;

    /*----------------- errors -----------------*/
    // @notice signature: 0x1785c681
    error AlreadyPaused();
    error NotPaused();
    // @notice signature: 0xb1d02c3d
    error InBlackList();
    // @notice signature: 0x06fbb1e3
    error OnlyProtector();

    /*----------------- events -----------------*/
    event Paused();
    event Resumed();
    event ProtectorChanged(address indexed oldProtector, address indexed newProtector);
    event BlackListed(address indexed target);
    event UnBlackListed(address indexed target);

    /*----------------- modifier -----------------*/
    modifier whenNotPaused() {
        if (_paused) revert AlreadyPaused();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert NotPaused();
        _;
    }

    modifier onlyProtector() {
        if (msg.sender != _protector) revert OnlyProtector();
        _;
    }

    modifier notInBlackList() {
        if (blackList[msg.sender]) revert InBlackList();
        _;
    }

    /*----------------- initializer -----------------*/
    function __Protectable_init(address protector) internal onlyInitializing {
        __Protectable_init_unchained(protector);
    }

    function __Protectable_init_unchained(address protector) internal onlyInitializing {
        _protector = protector;
    }

    /*----------------- external functions -----------------*/
    /**
     * @return whether the system is paused
     */
    function isPaused() external view returns (bool) {
        return _paused;
    }

    /**
     * @dev Pause the whole system in emergency
     */
    function pause() external virtual onlyProtector whenNotPaused {
        _paused = true;
        emit Paused();
    }

    /**
     * @dev Resume the whole system
     */
    function resume() external virtual onlyProtector whenPaused {
        _paused = false;
        emit Resumed();
    }

    /**
     * @dev Add an address to the black list
     */
    function addToBlackList(address account) external virtual onlyProtector {
        blackList[account] = true;
        emit BlackListed(account);
    }

    /**
     * @dev Remove an address from the black list
     */
    function removeFromBlackList(address account) external virtual onlyProtector {
        delete blackList[account];
        emit UnBlackListed(account);
    }

    /*----------------- internal functions -----------------*/
    function _setProtector(address protector) internal {
        emit ProtectorChanged(_protector, protector);
        _protector = protector;
    }

    uint256[50] private __reservedSlot;
}
