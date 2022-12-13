pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract RelayerIncentivizeTest is Deployer {
  event distributeCollectedReward(uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer);
  event paramChange(string key, bytes value);
  event rewardToRelayer(address relayer, uint256 amount);

  uint256 public roundSize;
  uint256 public maximumWeight;
  uint256 public gasPrice;

  function setUp() public {
    gasPrice = tx.gasprice;
    roundSize = incentivize.ROUND_SIZE();
    maximumWeight = incentivize.MAXIMUM_WEIGHT();

    bytes memory key = "dynamicExtraIncentiveAmount";
    bytes memory valueBytes = abi.encode(uint256(0));
    updateParamByGovHub(key, valueBytes, address(incentivize));
  }

  function testHeaderRelay() public {
    console2.log("round size is:", roundSize);
    console2.log("max weight is:", maximumWeight);

    uint256 roundSeq = incentivize.roundSequence();
    vm.startPrank(address(crossChain));
    while (incentivize.roundSequence() == roundSeq) {
      incentivize.addReward(addrSet[99], address(crossChain), 1e16, false);
    }
    ++roundSeq;

    address[] memory addrs = new address[](8);
    uint256[] memory bals = new uint256[](8);
    for (uint256 i; i < 8; ++i) {
      addrs[i] = addrSet[addrIdx++];
      vm.label(addrs[i], vm.toString(i));
      bals[i] = addrs[i].balance;
    }

    for (uint256 i; i < 1; ++i) {
      incentivize.addReward(addrs[0], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 2; ++i) {
      incentivize.addReward(addrs[1], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 3; ++i) {
      incentivize.addReward(addrs[2], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 4; ++i) {
      incentivize.addReward(addrs[3], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 5; ++i) {
      incentivize.addReward(addrs[4], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 40; ++i) {
      incentivize.addReward(addrs[5], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 41; ++i) {
      incentivize.addReward(addrs[6], address(crossChain), 1e16, false);
    }
    for (uint256 i; i < 4; ++i) {
      incentivize.addReward(addrs[7], address(crossChain), 1e16, false);
    }

    assertEq(incentivize.roundSequence(), roundSeq + 1, "wrong sequence");

    uint256[] memory rewards = new uint256[](8);
    for (uint256 i; i < 8; ++i) {
      incentivize.claimRelayerReward(addrs[i]);
      rewards[i] = addrs[i].balance - bals[i];
    }

    assertGe(rewards[1], rewards[0], "wrong reward");
    assertGe(rewards[2], rewards[1], "wrong reward");
    assertGe(rewards[3], rewards[2], "wrong reward");
    assertGe(rewards[4], rewards[3], "wrong reward");
    assertGe(rewards[5], rewards[4], "wrong reward");
    assertEq(rewards[6], rewards[5], "wrong reward");
    assertEq(rewards[7], rewards[3], "wrong reward");

    vm.stopPrank();
  }

  function testPackageRelay() public {
    uint256 roundSeq = incentivize.roundSequence();
    vm.startPrank(address(crossChain));
    while (incentivize.roundSequence() == roundSeq) {
      incentivize.addReward(addrSet[99], address(crossChain), 1e16, false);
    }
    ++roundSeq;

    address[] memory addrs = new address[](8);
    uint256[] memory bals = new uint256[](8);
    uint256[] memory txFees = new uint256[](8);
    for (uint256 i; i < 8; ++i) {
      addrs[i] = addrSet[addrIdx++];
      vm.label(addrs[i], vm.toString(i));
      bals[i] = addrs[i].balance;
    }

    uint256 gas;
    gas = gasleft();
    for (uint256 i; i < 1; ++i) {
      incentivize.addReward(address(crossChain), addrs[0], 1e16, false);
    }
    txFees[0] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 2; ++i) {
      incentivize.addReward(address(crossChain), addrs[1], 1e16, false);
    }
    txFees[1] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 3; ++i) {
      incentivize.addReward(address(crossChain), addrs[2], 1e16, false);
    }
    txFees[2] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 4; ++i) {
      incentivize.addReward(address(crossChain), addrs[3], 1e16, false);
    }
    txFees[3] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 5; ++i) {
      incentivize.addReward(address(crossChain), addrs[4], 1e16, false);
    }
    txFees[4] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 40; ++i) {
      incentivize.addReward(address(crossChain), addrs[5], 1e16, false);
    }
    txFees[5] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 41; ++i) {
      incentivize.addReward(address(crossChain), addrs[6], 1e16, false);
    }
    txFees[6] = gasPrice * (gas - gasleft());
    gas = gasleft();
    for (uint256 i; i < 4; ++i) {
      incentivize.addReward(address(crossChain), addrs[7], 1e16, false);
    }
    txFees[7] = gasPrice * (gas - gasleft());

    assertEq(incentivize.roundSequence(), roundSeq + 1, "wrong sequence");

    uint256[] memory rewards = new uint256[](8);
    for (uint256 i; i < 8; ++i) {
      incentivize.claimRelayerReward(addrs[i]);
      rewards[i] = addrs[i].balance - bals[i] - txFees[i];
    }

    assertGe(rewards[1], rewards[0], "wrong reward");
    assertGe(rewards[2], rewards[1], "wrong reward");
    assertGe(rewards[3], rewards[2], "wrong reward");
    assertGe(rewards[4], rewards[3], "wrong reward");
    assertGe(rewards[5], rewards[4], "wrong reward");
    assertGe(rewards[5], rewards[6], "wrong reward");
    assertGe(rewards[7], rewards[3], "wrong reward"); // get extra 1/80 of total reward
    assertGe(rewards[5], rewards[7], "wrong reward"); // get extra 1/80 of total reward

    vm.stopPrank();
  }

  function testNonPayableAddress() public {
    uint256 roundSeq = incentivize.roundSequence();
    vm.startPrank(address(crossChain));
    while (incentivize.roundSequence() == roundSeq) {
      incentivize.addReward(addrSet[99], address(crossChain), 1e16, false);
    }
    ++roundSeq;

    uint256 balanceSystemReward = address(systemReward).balance;
    for (uint256 i; i < 50; ++i) {
      incentivize.addReward(address(lightClient), relayer, 1e16, false);
    }
    for (uint256 i; i < 49; ++i) {
      incentivize.addReward(relayer, address(lightClient), 1e16, false);
    }
    incentivize.addReward(relayer, address(lightClient), 1e16, false);

    incentivize.claimRelayerReward(address(lightClient));
    incentivize.claimRelayerReward(relayer);
    uint256 newBalanceSystemReward = address(systemReward).balance;

    assertEq(newBalanceSystemReward, balanceSystemReward + 506250000000000000, "wrong amount to systemReward contract");
    assertEq(incentivize.roundSequence(), roundSeq + 1, "wrong sequence");

    vm.stopPrank();
  }

  function testDynamicExtraIncentive() public {
    uint256 roundSeq = incentivize.roundSequence();
    vm.startPrank(address(crossChain));
    while (incentivize.roundSequence() == roundSeq) {
      incentivize.addReward(addrSet[99], address(crossChain), 1e16, false);
    }
    ++roundSeq;
    incentivize.claimRelayerReward(relayer);

    uint256 balance = relayer.balance;
    for (uint256 i; i < roundSize; ++i) {
      incentivize.addReward(relayer, address(crossChain), 2e16, false);
    }
    assertEq(incentivize.roundSequence(), ++roundSeq, "wrong sequence");
    incentivize.claimRelayerReward(relayer);
    uint256 reward1 = relayer.balance - balance;
    balance = relayer.balance;

    vm.stopPrank();
    bytes memory key = "dynamicExtraIncentiveAmount";
    bytes memory valueBytes = abi.encode(uint256(1e16));
    updateParamByGovHub(key, valueBytes, address(incentivize));

    vm.startPrank(address(crossChain));
    for (uint256 i; i < roundSize; ++i) {
      incentivize.addReward(relayer, address(crossChain), 1e16, false);
    }
    assertEq(incentivize.roundSequence(), ++roundSeq, "wrong sequence");
    incentivize.claimRelayerReward(relayer);
    uint256 reward2 = relayer.balance - balance;
    assertEq(reward2, reward1, "wrong reward");

    vm.stopPrank();
  }
}
