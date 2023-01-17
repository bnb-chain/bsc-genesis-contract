pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract SlashIndicatorTest is Deployer {
  event validatorSlashed(address indexed validator);
  event indicatorCleaned();
  event paramChange(string key, bytes value);

  address public coinbase;
  address[] public validators;

  function setUp() public {
    bytes memory slashCode = vm.getDeployedCode("SlashIndicator.sol");
    vm.etch(address(slash), slashCode);

    validators = validator.getValidators();

    coinbase = block.coinbase;
    vm.deal(coinbase, 100 ether);
  }

  function testGov() public {
    bytes memory key = "misdemeanorThreshold";
    bytes memory value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000064"); // 100
    updateParamByGovHub(key, value, address(slash));
    assertEq(slash.misdemeanorThreshold(), 100);

    key = "felonyThreshold";
    value = bytes(hex"00000000000000000000000000000000000000000000000000000000000000c8"); // 200
    updateParamByGovHub(key, value, address(slash));
    assertEq(slash.felonyThreshold(), 200);

    key = "finalitySlashRewardRatio";
    value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000032"); // 50
    updateParamByGovHub(key, value, address(slash));
    assertEq(slash.finalitySlashRewardRatio(), 50);
  }

  function testSlash() public {
    address validator = validators[0];

    vm.expectRevert(bytes("the message sender must be the block producer"));
    slash.slash(validator);

    vm.startPrank(coinbase);
    (, uint256 origin) = slash.getSlashIndicator(validator);
    for (uint256 i = 1; i < 10; ++i) {
      vm.expectEmit(true, false, false, true, address(slash));
      emit validatorSlashed(validator);
      slash.slash(validator);
      vm.roll(block.number + 1);
      (, uint256 count) = slash.getSlashIndicator(validator);
      assertEq(origin + i, count);
    }
    vm.stopPrank();
  }

  function testMaintenance() public {
    vm.prank(validators[0]);
    validator.enterMaintenance();

    (, uint256 countBefore) = slash.getSlashIndicator(validators[0]);
    vm.prank(coinbase);
    slash.slash(validators[0]);
    (, uint256 countAfter) = slash.getSlashIndicator(validators[0]);
    assertEq(countAfter, countBefore);

    vm.prank(validators[0]);
    vm.expectRevert(bytes("can not enter Temporary Maintenance"));
    validator.enterMaintenance();

    // exit maintenance
    vm.prank(validators[0]);
    validator.exitMaintenance();
    vm.roll(block.number + 1);
    vm.prank(coinbase);
    slash.slash(validators[0]);
    (, countAfter) = slash.getSlashIndicator(validators[0]);
    assertEq(countAfter, countBefore + 1);

    vm.prank(validators[0]);
    vm.expectRevert(bytes("can not enter Temporary Maintenance"));
    validator.enterMaintenance();
  }

  function testMisdemeanor() public {
    address[] memory vals = new address[](21);
    for (uint256 i; i < vals.length; ++i) {
      vals[i] = addrSet[addrIdx++];
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, vals));

    vm.startPrank(coinbase);
    validator.deposit{value: 1 ether}(vals[0]);
    assertEq(9e17, validator.getIncoming(vals[0]));

    for (uint256 i; i < 50; ++i) {
      vm.roll(block.number + 1);
      slash.slash(vals[0]);
    }
    (, uint256 count) = slash.getSlashIndicator(vals[0]);
    assertEq(50, count);
    assertEq(0, validator.getIncoming(vals[0]));

    // enter maintenance, cannot be slashed
    vm.roll(block.number + 1);
    slash.slash(vals[0]);
    (, count) = slash.getSlashIndicator(vals[0]);
    assertEq(50, count);
    vm.stopPrank();

    address[] memory newVals = new address[](3);
    for (uint256 i; i < newVals.length; ++i) {
      newVals[i] = vals[i];
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newVals));

    vm.startPrank(coinbase);
    validator.deposit{value: 2 ether}(newVals[0]);
    assertEq(18e17, validator.getIncoming(newVals[0]));

    for (uint256 i; i < 37; ++i) {
      vm.roll(block.number + 1);
      slash.slash(newVals[0]);
    }
    (, count) = slash.getSlashIndicator(newVals[0]);
    assertEq(50, count);
    assertEq(0, validator.getIncoming(newVals[0]));
    assertEq(9e17, validator.getIncoming(newVals[1]));
    assertEq(9e17, validator.getIncoming(newVals[2]));

    validator.deposit{value: 1 ether}(newVals[1]);
    assertEq(18e17, validator.getIncoming(newVals[1]));
    for (uint256 i; i < 50; ++i) {
      vm.roll(block.number + 1);
      slash.slash(newVals[1]);
    }
    assertEq(9e17, validator.getIncoming(newVals[0]));
    assertEq(0, validator.getIncoming(newVals[1]));
    assertEq(18e17, validator.getIncoming(newVals[2]));

    assertEq(18e17, validator.getIncoming(newVals[2]));
    for (uint256 i; i < 50; ++i) {
      vm.roll(block.number + 1);
      slash.slash(newVals[2]);
    }
    assertEq(18e17, validator.getIncoming(newVals[0]));
    assertEq(9e17, validator.getIncoming(newVals[1]));
    assertEq(0, validator.getIncoming(newVals[2]));
    vm.stopPrank();
  }

  function testFelony() public {
    address[] memory vals = new address[](3);
    for (uint256 i; i < vals.length; ++i) {
      vals[i] = addrSet[addrIdx++];
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, vals));

    vm.startPrank(coinbase);
    validator.deposit{value: 1 ether}(vals[0]);
    assertEq(9e17, validator.getIncoming(vals[0]));

    for (uint256 i; i < 50; ++i) {
      vm.roll(block.number + 1);
      slash.slash(vals[0]);
    }
    (, uint256 count) = slash.getSlashIndicator(vals[0]);
    assertEq(50, count);
    assertEq(0, validator.getIncoming(vals[0]));
    vm.stopPrank();

    vm.prank(vals[0]);
    validator.exitMaintenance();

    vm.startPrank(coinbase);
    validator.deposit{value: 1 ether}(vals[0]);
    for (uint256 i; i < 100; ++i) {
      vm.roll(block.number + 1);
      slash.slash(vals[0]);
    }
    (, count) = slash.getSlashIndicator(vals[0]);
    assertEq(0, count);
    assertEq(0, validator.getIncoming(vals[0]));
    assertEq(9e17, validator.getIncoming(vals[1]));
    assertEq(9e17, validator.getIncoming(vals[2]));

    vals = validator.getValidators();
    assertEq(2, vals.length);
    vm.stopPrank();
  }

  function testClean() public {
    // case 1: all clean.
    address[] memory vals = new address[](20);
    for (uint256 i; i < vals.length; ++i) {
      vals[i] = addrSet[addrIdx++];
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, vals));

    vm.startPrank(coinbase);
    for (uint256 i; i < vals.length; ++i) {
      vm.roll(block.number + 1);
      slash.slash(vals[i]);
    }
    vm.stopPrank();

    // do clean
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, vals));

    uint256 count;
    for (uint256 i; i < vals.length; ++i) {
      (, count) = slash.getSlashIndicator(vals[i]);
      assertEq(0, count);
    }

    // case 2: all stay.
    // felonyThreshold/DECREASE_RATE = 37
    vm.startPrank(coinbase);
    for (uint256 i; i < vals.length; ++i) {
      for (uint256 j; j < 38; ++j) {
        vm.roll(block.number + 1);
        slash.slash(vals[i]);
      }
    }
    vm.stopPrank();

    // do clean
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, vals));

    for (uint256 i; i < vals.length; ++i) {
      (, count) = slash.getSlashIndicator(vals[i]);
      assertEq(1, count);
    }

    // case 3: partial stay.
    vm.startPrank(coinbase);
    for (uint256 i; i < 10; ++i) {
      for (uint256 j; j < 38; ++j) {
        vm.roll(block.number + 1);
        slash.slash(vals[2 * i]);
      }
      vm.roll(block.number + 1);
      slash.slash(vals[2 * i + 1]);
    }
    vm.stopPrank();

    // do clean
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, vals));

    for (uint256 i; i < 10; ++i) {
      (, count) = slash.getSlashIndicator(vals[i]);
      if (i % 2 == 0) {
        assertEq(2, count);
      } else {
        assertEq(0, count);
      }
    }
  }

  //  function testFinality() public {
  //    address[] memory vals = new address[](20);
  //    bytes[] memory voteAddrs = new bytes[](20);
  //    for (uint256 i; i < vals.length; ++i) {
  //      vals[i] = addrSet[addrIdx++];
  //      voteAddrs[i] = abi.encodePacked(vals[i]);
  //    }
  //    vm.prank(address(crossChain));
  //    validator.handleSynPackage(STAKING_CHANNELID, encodeNewValidatorSetUpdatePack(0x00, vals, voteAddrs));
  //
  //    // case1: valid finality evidence: same target block
  //    uint256 srcNumA = block.number - 20;
  //    uint256 tarNumA = block.number - 10;
  //    uint256 srcNumB = block.number - 15;
  //    uint256 tarNumB = tarNumA;
  //    SlashIndicator.VoteData memory voteA;
  //    voteA.srcNum = srcNumA;
  //    voteA.srcHash = blockhash(srcNumA);
  //    voteA.tarNum = tarNumA;
  //    voteA.tarHash = blockhash(tarNumA);
  //    voteA.sig = abi.encode("sigA");
  //
  //    SlashIndicator.VoteData memory voteB;
  //    voteB.srcNum = srcNumB;
  //    voteB.srcHash = blockhash(srcNumB);
  //    voteB.tarNum = tarNumB;
  //    voteB.tarHash = blockhash(tarNumB);
  //    voteB.sig = abi.encode("sigB");
  //
  //    SlashIndicator.FinalityEvidence memory evidence;
  //    evidence.voteA = voteA;
  //    evidence.voteB = voteB;
  //    evidence.voteAddr = voteAddrs[0];
  //
  //    vm.prank(relayer);
  //    slash.submitFinalityViolationEvidence(evidence);
  //  }
}
