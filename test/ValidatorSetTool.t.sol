pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../lib/interface/IBSCValidatorSetTool.sol";

contract ToolTest is Test {
  BSCValidatorSetTool public tool;

  function setUp() public {
    // deploy tool contract
    address toolAddr = deployCode("BSCValidatorSetTool.sol");
    tool = BSCValidatorSetTool(toolAddr);
    vm.label(toolAddr, "BSCValidatorSetTool");
  }

  function testDecodeHeader() public {
    bytes memory payload =
      hex"00000000000000000000000000000000000000000000000000002386f26fc10000f85580a04142432d304237000000000000000000000000000000000000000000000000009450ee0de39df3b9c2bc8f8e33d9e4cd03dba9210c8b52b7d2dcc80cd2e40000008b31a17e847807b1bc00000012845f5efcc1";
    (,, uint256 relayFee,) = tool.decodePayloadHeader(payload);
    assertEq(relayFee, 10000000000000000);
  }
}
