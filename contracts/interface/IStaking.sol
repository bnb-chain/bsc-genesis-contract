pragma solidity 0.6.4;

interface IStaking {

  function delegate(address validator, uint256 amount) external payable;

  function undelegate(address validator, uint256 amount) external payable;

  function redelegate(address validatorSrc, address validatorDst, uint256 amount) external payable;

  function claimReward() external returns(uint256);

  function claimUndeldegated() external returns(uint256);

  function getPendingReward() external view returns(uint256);

  function getPendingUndelegated() external view returns(uint256);

  function getOracleRelayerFee() external view returns(uint256);
}