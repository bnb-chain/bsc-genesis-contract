pragma solidity 0.6.4;

interface IStaking {

  function delegate(address validator, uint256 amount) external payable;

  function undelegate(address validator, uint256 amount) external payable;

  function redelegate(address validatorSrc, address validatorDst, uint256 amount) external payable;

  function claimReward() external returns(uint256);

  function claimUndeldegated() external returns(uint256);

  function getDelegated(address delegator, address validator) external view returns(uint256);

  function getTotalDelegated(address delegator) external view returns(uint256);

  function getDistributedReward(address delegator) external view returns(uint256);

  function getPendingRedelegateTime(address delegator, address valSrc, address valDst)  external view returns(uint256);

  function getUndelegated(address delegator) external view returns(uint256);

  function getPendingUndelegateTime(address delegator, address validator) external view returns(uint256);

  function getOracleRelayerFee() external view returns(uint256);

  function getMinDelegation() external view returns(uint256);
}
