// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IStakeHub {
    function DEAD_ADDRESS() external view returns (address);
    function INIT_LOCK_AMOUNT() external view returns (uint256);
    function unbondPeriod() external view returns (uint256);
    function transferGasLimit() external view returns (uint256);
}
