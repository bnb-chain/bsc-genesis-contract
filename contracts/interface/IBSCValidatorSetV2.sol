interface IBSCValidatorSetV2 {
  function currentValidatorSetMap(address validator) external view returns(uint256);
  function numOfCabinets() external view returns(uint256);
}
