interface IBSCValidatorSetV2 {
  function getValidators() external view returns(address[] memory);
  function numOfCabinets() external view returns(uint256);
}
