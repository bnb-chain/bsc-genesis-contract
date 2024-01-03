// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ICrossChain {
    function registeredContractChannelMap(address, uint8) external view returns (bool);
}
