// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IGovToken {
    function delegateVote(address delegator, address delegatee) external;
    function sync(address[] calldata validatorPools, address account) external;
}
