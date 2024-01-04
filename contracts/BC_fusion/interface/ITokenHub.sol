// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ITokenHub {
    function recoverBCAsset(bytes32 tokenSymbol, address recipient, uint256 amount) external;
    function cancelTokenRecoverLock(bytes32 tokenSymbol, address attacker) external;
    function claimMigrationFund(uint256 amount) external returns (bool);
}
