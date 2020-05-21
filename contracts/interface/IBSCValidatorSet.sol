pragma solidity 0.6.4;

interface IBSCValidatorSet {
  function misdemeanor(address validator) external;
  function felony(address validator)external;
}