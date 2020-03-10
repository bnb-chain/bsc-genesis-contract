pragma solidity ^0.5.15;

interface IBSCValidatorSet {
  function misdemeanor(address validator) external;
  function felony(address validator)external;
}