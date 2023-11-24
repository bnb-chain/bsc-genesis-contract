// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

import "./System.sol";
import "./lib/Utils.sol";

contract BSCTimelock is System, Initializable, TimelockControllerUpgradeable {
    using Utils for string;

    /*----------------- constants -----------------*/
    uint256 private constant INIT_MINIMAL_DELAY = 24 hours;

    /*----------------- init -----------------*/
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        address[] memory _governor = new address[](1);
        _governor[0] = GOVERNOR_ADDR;
        __TimelockController_init(INIT_MINIMAL_DELAY, _governor, _governor, GOVERNOR_ADDR);
    }

    /*----------------- system functions -----------------*/
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        uint256 valueLength = value.length;
        if (key.compareStrings("minDelay")) {
            require(valueLength == 32, "INVALID_VALUE_LENGTH");
            uint256 newMinDelay = Utils.bytesToUint256(value, valueLength);
            require(newMinDelay > 0, "INVALID_MIN_DELAY");
            require(newMinDelay < 14 days, "INVALID_MIN_DELAY");
            this.updateDelay(newMinDelay);
        } else {
            revert("UNKNOWN_PARAM");
        }
        emit ParamChange(key, value);
    }
}
