// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IStakeHub {
    function unbondPeriod() external view returns (uint256);
    function transferGasLimit() external view returns (uint256);
}
