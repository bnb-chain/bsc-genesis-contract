pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract TendermintLightClientTest is Deployer {
  event relayerRegister(address _relayer);
  event relayerUnRegister(address _relayer);
  event paramChange(string key, bytes value);

  uint256 public requiredDeposit;
  uint256 public dues;

  function setUp() public {}

  function testInitConsensusState() public {
    assertEq(lightClient.initialHeight(), 110186855);
    assertEq(lightClient.chainID(), bytes32("Binance-Chain-Tigris"));
    assertTrue(lightClient.isHeaderSynced(uint64(255787329)));
    assertTrue(!lightClient.isHeaderSynced(uint64(255787330)));
  }
}
