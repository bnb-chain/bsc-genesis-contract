// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

import "./SystemV2.sol";
import "./lib/0.8.x/Utils.sol";

contract BSCTimelock is SystemV2, Initializable, TimelockControllerUpgradeable {
    using Utils for bytes;
    using Utils for string;

    /*----------------- constants -----------------*/
    /*
     * @dev caution: minDelay using second as unit
     */
    uint256 private constant INIT_MINIMAL_DELAY = 24 hours;

    /*----------------- init -----------------*/
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        address[] memory _governor = new address[](1);
        _governor[0] = GOVERNOR_ADDR;
        __TimelockController_init(INIT_MINIMAL_DELAY, _governor, _governor, GOVERNOR_ADDR);
    }

    /*----------------- system functions -----------------*/
    /**
     * @param key the key of the param
     * @param value the value of the param
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("minDelay")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMinDelay = value.bytesToUint256(32);
            if (newMinDelay == 0 || newMinDelay > 14 days) revert InvalidValue(key, value);
            this.updateDelay(newMinDelay);
        } else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key, value);
    }
}
