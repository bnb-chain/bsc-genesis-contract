pragma solidity 0.6.4;

interface ISlashIndicator {
  function clean() external;
  function getSlashThresholds() external view returns (uint256, uint256);
}
