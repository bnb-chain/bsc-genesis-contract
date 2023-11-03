// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "./System.sol";
import "./lib/Utils.sol";

contract BSCTimelock is System, TimelockControllerUpgradeable {
    uint256 public constant INIT_MINIMAL_DELAY = 6 hours;

    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        address[] memory _governor = new address[](1);
        _governor[0] = GOVERNOR_ADDR;
        __TimelockController_init(INIT_MINIMAL_DELAY, _governor, _governor, GOVERNOR_ADDR);
    }

    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        uint256 valueLength = value.length;
        if (Utils.compareStrings(key, "minDelay")) {
            require(valueLength == 32, "invalid minDelay value length");
            uint256 newMinDelay = Utils.bytesToUint256(value, valueLength);
            require(newMinDelay > 0, "invalid minDelay");
            this.updateDelay(newMinDelay);
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }
}
