pragma solidity 0.6.4;

interface ISlashIndicator {
    function clean() external;
    function downtimeSlash(address validator, uint256 count, bool shouldRevert) external;
    function sendFelonyPackage(address validator) external;
    function getSlashThresholds() external view returns (uint256, uint256);
}
