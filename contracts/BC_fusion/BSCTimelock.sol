// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "./System.sol";

contract BSCTimelock is System, TimelockControllerUpgradeable {
    uint256 public constant MINIMAL_DELAY = 6 hours;

    function initialize(address _admin) external initializer onlyCoinbase onlyZeroGasPrice {
        address[] memory _governor = new address[](1);
        _governor[0] = GOVERNOR_ADDR;
        __TimelockController_init(MINIMAL_DELAY, _governor, _governor, _admin);
    }
}
