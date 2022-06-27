pragma solidity 0.6.4;

interface IStaking {

  function delegate(address validator, uint256 amount) external;

  function undelegate(address validator, uint256 amount) external;

  function claimReward(address receiver, uint256 _oracleRelayerFee) external;

  function claimUndeldegated(address receiver, uint256 _oracleRelayerFee) external;

  function reinvest(address validator, uint256 amount) external;

  function redelegate(address validatorSrc, address validatorDst, uint256 amount) external;
}