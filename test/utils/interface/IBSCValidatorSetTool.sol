pragma solidity ^0.8.10;

interface BSCValidatorSetTool {
    function INIT_VALIDATORSET_BYTES() external view returns (bytes memory);
    function decodePayloadHeader(bytes memory payload) external pure returns (bool, uint8, uint256, bytes memory);
    function init() external pure;
}
