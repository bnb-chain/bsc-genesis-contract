pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract ValidatorSetTest is Deployer {
  using RLPEncode for *;

  event validatorSetUpdated();
  event validatorJailed(address indexed validator);
  event validatorEmptyJailed(address indexed validator);
  event batchTransfer(uint256 amount);
  event batchTransferFailed(uint256 indexed amount, string reason);
  event batchTransferLowerFailed(uint256 indexed amount, bytes reason);
  event systemTransfer(uint256 amount);
  event directTransfer(address payable indexed validator, uint256 amount);
  event directTransferFail(address payable indexed validator, uint256 amount);
  event deprecatedDeposit(address indexed validator, uint256 amount);
  event validatorDeposit(address indexed validator, uint256 amount);
  event validatorMisdemeanor(address indexed validator, uint256 amount);
  event validatorFelony(address indexed validator, uint256 amount);
  event failReasonWithStr(string message);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);
  event paramChange(string key, bytes value);
  event feeBurned(uint256 amount);
  event validatorEnterMaintenance(address indexed validator);
  event validatorExitMaintenance(address indexed validator);
  event finalityRewardDeposit(address indexed validator, uint256 amount);
  event deprecatedFinalityRewardDeposit(address indexed validator, uint256 amount);
  event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);

  uint256 public totalInComing;
  uint256 public burnRatio;
  uint256 public burnRatioScale;
  uint256 public maxNumOfWorkingCandidates;
  uint256 public numOfCabinets;
  address public coinbase;
  address[] public validators;

  mapping(address => bool) public cabinets;

  function setUp() public {
    bytes memory rewardCode = vm.getDeployedCode("SystemReward.sol");
    vm.etch(address(systemReward), rewardCode);
    bytes memory slashCode = vm.getDeployedCode("SlashIndicator.sol");
    vm.etch(address(slash), slashCode);
    bytes memory validatorCode = vm.getDeployedCode("BSCValidatorSet.sol");
    vm.etch(address(validator), validatorCode);
    bytes memory stakeHubCode = vm.getDeployedCode("StakeHub.sol");
    vm.etch(address(stakeHub), stakeHubCode);

    // add operator
    bytes memory key = "addOperator";
    bytes memory valueBytes = abi.encodePacked(address(validator));
    vm.expectEmit(false, false, false, true, address(systemReward));
    emit paramChange(string(key), valueBytes);
    updateParamByGovHub(key, valueBytes, address(systemReward));
    assertTrue(systemReward.isOperator(address(validator)));

    burnRatio = validator.burnRatioInitialized() ? validator.burnRatio() : validator.INIT_BURN_RATIO();
    burnRatioScale = validator.BURN_RATIO_SCALE();
    validators = validator.getValidators();
    totalInComing = validator.totalInComing();
    maxNumOfWorkingCandidates = validator.maxNumOfWorkingCandidates();
    numOfCabinets = validator.numOfCabinets();

    coinbase = block.coinbase;
    vm.deal(coinbase, 100 ether);

    // remove this after fusion fork launched
    vm.prank(coinbase);
    vm.txGasPrice(0);
    stakeHub.initialize();
  }

  function testDeposit(uint256 amount) public {
    vm.assume(amount >= 1e16);
    vm.assume(amount <= 1e19);
    vm.expectRevert("the message sender must be the block producer");
    validator.deposit{value: amount}(validators[0]);

    vm.startPrank(coinbase);
    vm.expectRevert("deposit value is zero");
    validator.deposit(validators[0]);

    uint256 realAmount = amount - amount * burnRatio / burnRatioScale;
    vm.expectEmit(true, false, false, true, address(validator));
    emit validatorDeposit(validators[0], realAmount);
    validator.deposit{value: amount}(validators[0]);

    address newAccount = addrSet[addrIdx++];
    vm.expectEmit(true, false, false, true, address(validator));
    emit deprecatedDeposit(newAccount, realAmount);
    validator.deposit{value: amount}(newAccount);

    assertEq(validator.totalInComing(), totalInComing + realAmount);
    vm.stopPrank();
  }

  function testBurn(uint8 coefficient) public {
    vm.assume(coefficient < 10000);
    bytes32 co = bytes32(uint256(coefficient));
    bytes memory key = "burnRatio";
    bytes memory value = new bytes(32);
    assembly {
      mstore(add(value, 32), co)
      mstore(add(add(value, 32), 32), add(co, 32))
    }

    updateParamByGovHub(key, value, address(validator));

    burnRatio = validator.burnRatio();
    assertEq(burnRatio, coefficient);

    uint256 amount = 1 ether;
    uint256 realAmount = amount - amount * burnRatio / burnRatioScale;
    vm.expectEmit(true, false, false, true, address(validator));
    emit validatorDeposit(validators[0], realAmount);
    vm.prank(coinbase);
    validator.deposit{value: amount}(validators[0]);
  }

  function testGov() public {
    bytes memory key = "maxNumOfWorkingCandidates";
    bytes memory value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000015"); // 21
    vm.expectEmit(false, false, false, true, address(govHub));
    emit failReasonWithStr("the maxNumOfWorkingCandidates must be not greater than maxNumOfCandidates");
    updateParamByGovHub(key, value, address(validator));
    assertEq(validator.maxNumOfWorkingCandidates(), maxNumOfWorkingCandidates);

    value = bytes(hex"000000000000000000000000000000000000000000000000000000000000000a"); // 10
    updateParamByGovHub(key, value, address(validator));
    assertEq(validator.maxNumOfWorkingCandidates(), 10);

    key = "maxNumOfCandidates";
    value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000005"); // 5
    updateParamByGovHub(key, value, address(validator));
    assertEq(validator.maxNumOfCandidates(), 5);
    assertEq(validator.maxNumOfWorkingCandidates(), 5);
  }

  function testGetMiningValidatorsWith41Vals() public {
    address[] memory newValidators = new address[](41);
    for (uint256 i; i < 41; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidators));

    address[] memory vals = validator.getValidators();
    (address[] memory miningVals,) = validator.getMiningValidators();

    uint256 count;
    uint256 _numOfCabinets;
    uint256 _maxNumOfWorkingCandidates = maxNumOfWorkingCandidates;
    if (numOfCabinets == 0) {
      _numOfCabinets = validator.INIT_NUM_OF_CABINETS();
    } else {
      _numOfCabinets = numOfCabinets;
    }
    if ((vals.length - _numOfCabinets) < _maxNumOfWorkingCandidates) {
      _maxNumOfWorkingCandidates = vals.length - _numOfCabinets;
    }

    for (uint256 i; i < _numOfCabinets; ++i) {
      cabinets[vals[i]] = true;
    }
    for (uint256 i; i < _numOfCabinets; ++i) {
      if (!cabinets[miningVals[i]]) {
        ++count;
      }
    }
    assertGe(_maxNumOfWorkingCandidates, count);
    assertGe(count, 0);
  }

  function testDistributeAlgorithm() public {
    address[] memory newValidator = new address[](1);
    newValidator[0] = addrSet[addrIdx++];

    // To reset the incoming
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidator));

    address val = newValidator[0];
    address tmp = addrSet[addrIdx++];
    vm.deal(address(validator), 0);

    vm.startPrank(coinbase);
    for (uint256 i; i < 5; ++i) {
      validator.deposit{value: 1 ether}(val);
      validator.deposit{value: 1 ether}(tmp);
      validator.deposit{value: 0.1 ether}(val);
      validator.deposit{value: 0.1 ether}(tmp);
    }
    vm.stopPrank();

    uint256 expectedBalance = 11 ether - 11 ether * burnRatio / burnRatioScale;
    uint256 expectedIncoming = 5.5 ether - 5.5 ether * burnRatio / burnRatioScale;
    uint256 balance = address(validator).balance;
    uint256 incoming = validator.totalInComing();
    assertEq(balance, expectedBalance);
    assertEq(incoming, expectedIncoming);

    newValidator[0] = addrSet[addrIdx++];

    vm.expectEmit(false, false, false, true, address(validator));
    emit batchTransfer(expectedIncoming);
    vm.expectEmit(false, false, false, true, address(validator));
    emit systemTransfer(expectedBalance - expectedIncoming);
    vm.expectEmit(false, false, false, false, address(validator));
    emit validatorSetUpdated();
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidator));
  }

  function testMassiveDistribute() public {
    address[] memory newValidators = new address[](41);
    for (uint256 i; i < 41; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }

    // To reset the incoming
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidators));

    vm.startPrank(coinbase);
    for (uint256 i; i < 41; ++i) {
      validator.deposit{value: 1 ether}(newValidators[i]);
    }
    vm.stopPrank();

    for (uint256 i; i < 41; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidators));
  }

  function testDistribute41Plus() public {
    address[] memory newValidators = new address[](42);
    for (uint256 i; i < 42; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }

    // To reset the incoming
    vm.expectEmit(false, false, false, true, address(validator));
    emit failReasonWithStr("the number of validators exceed the limit");
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidators));
  }

  function testComplicateDistribute1() public {
    address[] memory newValidators = new address[](5);
    address deprecated = addrSet[addrIdx++];
    uint256 balance = deprecated.balance;
    for (uint256 i; i < 5; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }
    bytes memory pack = encodeOldValidatorSetUpdatePack(0x00, newValidators);
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, pack);

    vm.startPrank(coinbase);
    validator.deposit{value: 1e16}(newValidators[0]);
    validator.deposit{value: 1e16}(newValidators[1]);
    validator.deposit{value: 1e17}(newValidators[2]); // middle case
    validator.deposit{value: 1e18}(newValidators[3]);
    validator.deposit{value: 1e18}(newValidators[4]);
    validator.deposit{value: 1e18}(deprecated); // deprecated case
    validator.deposit{value: 1e5}(newValidators[4]); // dust case
    vm.stopPrank();

    uint256 directTransferAmount = 1e16 - 1e16 * burnRatio / burnRatioScale;
    uint256 crossTransferAmount = 1e18 - 1e18 * burnRatio / burnRatioScale;
    uint256 middleCase = 1e17 - 1e17 * burnRatio / burnRatioScale;
    uint256 batchTransferAmount = 2 * crossTransferAmount;
    if (middleCase >= 1e17) {
      batchTransferAmount += middleCase;
    }
    uint256 systemTransferAmount = crossTransferAmount + (1e5 - 1e5 * burnRatio / burnRatioScale);

    vm.expectEmit(false, false, false, true, address(validator));
    emit batchTransfer(batchTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransfer(payable(newValidators[0]), directTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransfer(payable(newValidators[1]), directTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    if (middleCase < 1e17) {
      vm.expectEmit(true, false, false, true, address(validator));
      emit directTransfer(payable(newValidators[2]), middleCase);
    }
    emit systemTransfer(systemTransferAmount);
    vm.expectEmit(false, false, false, false, address(validator));
    emit validatorSetUpdated();

    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, pack);

    assertEq(newValidators[0].balance, balance + directTransferAmount);
    assertEq(newValidators[1].balance, balance + directTransferAmount);
    if (middleCase < 1e17) {
      assertEq(newValidators[2].balance, balance + middleCase);
    } else {
      assertEq(newValidators[2].balance, balance);
    }
    assertEq(newValidators[3].balance, balance);
    assertEq(newValidators[4].balance, balance);
    assertEq(deprecated.balance, balance);
  }

  function testValidateSetChange() public {
    address[][] memory newValSet = new address[][](5);
    for (uint256 i; i < 5; ++i) {
      address[] memory valSet = new address[](5+i);
      for (uint256 j; j < 5 + i; ++j) {
        valSet[j] = addrSet[addrIdx++];
      }
      newValSet[i] = valSet;
    }

    vm.startPrank(address(crossChain));
    for (uint256 k; k < 5; ++k) {
      validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValSet[k]));
      address[] memory valSet = validator.getValidators();
      for (uint256 l; l < 5 + k; ++l) {
        assertEq(valSet[l], newValSet[k][l], "consensusAddr not equal");
        assertTrue(validator.isCurrentValidator(newValSet[k][l]), "the address should be a validator");
      }
    }
    vm.stopPrank();
  }

  function testCannotUpdateValidatorSet() public {
    address[][] memory newValSet = new address[][](4);
    newValSet[0] = new address[](3);
    newValSet[0][0] = addrSet[addrIdx];
    newValSet[0][1] = addrSet[addrIdx++];
    newValSet[0][2] = addrSet[addrIdx++];
    newValSet[1] = new address[](3);
    newValSet[1][0] = addrSet[addrIdx++];
    newValSet[1][1] = addrSet[addrIdx];
    newValSet[1][2] = addrSet[addrIdx++];
    newValSet[2] = new address[](4);
    newValSet[2][0] = addrSet[addrIdx++];
    newValSet[2][1] = addrSet[addrIdx++];
    newValSet[2][2] = addrSet[addrIdx++];
    newValSet[2][3] = addrSet[addrIdx++];

    vm.startPrank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValSet[2]));
    for (uint256 i; i < 2; ++i) {
      vm.expectEmit(false, false, false, true, address(validator));
      emit failReasonWithStr("duplicate consensus address of validatorSet");
      validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValSet[i]));
    }
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValSet[3]));
    vm.stopPrank();

    uint64 _height = crossChain.channelSyncedHeaderMap(STAKING_CHANNELID);
    uint64 _sequence = crossChain.channelReceiveSequenceMap(STAKING_CHANNELID);
    vm.expectRevert(bytes("the msg sender is not a relayer"));
    crossChain.handlePackage(bytes("1"), bytes("2"), _height, _sequence, STAKING_CHANNELID);

    vm.expectRevert(bytes("light client not sync the block yet"));
    vm.startPrank(address(relayer));
    crossChain.handlePackage(bytes("1"), bytes("2"), _height+1, _sequence, STAKING_CHANNELID);

    vm.expectEmit(true, false, false, true, address(crossChain));
    emit unsupportedPackage(_sequence, STAKING_CHANNELID, bytes("1"));
    vm.mockCall(address(0x65), "", hex"0000000000000000000000000000000000000000000000000000000000000001");
    crossChain.handlePackage(bytes("1"), bytes("2"), _height, _sequence, STAKING_CHANNELID);

    vm.stopPrank();
  }

  // one validator's fee addr is a contract
  function testComplicateDistribute2() public {
    address[] memory newValidators = new address[](5);
    address deprecated = addrSet[addrIdx++];
    uint256 balance = deprecated.balance;
    newValidators[0] = address(slash); // set fee addr to a contract
    vm.deal(newValidators[0], 0);
    for (uint256 i = 1; i < 5; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }
    bytes memory pack = encodeOldValidatorSetUpdatePack(0x00, newValidators);
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, pack);

    vm.startPrank(coinbase);
    validator.deposit{value: 1e16}(newValidators[0]); // fee addr is a contract
    validator.deposit{value: 1e16}(newValidators[1]);
    validator.deposit{value: 1e17}(newValidators[2]); // middle case
    validator.deposit{value: 1e18}(newValidators[3]);
    validator.deposit{value: 1e18}(newValidators[4]);
    validator.deposit{value: 1e18}(deprecated); // deprecated case
    validator.deposit{value: 1e5}(newValidators[4]); // dust case
    vm.stopPrank();

    uint256 directTransferAmount = 1e16 - 1e16 * burnRatio / burnRatioScale;
    uint256 crossTransferAmount = 1e18 - 1e18 * burnRatio / burnRatioScale;
    uint256 middleCase = 1e17 - 1e17 * burnRatio / burnRatioScale;
    uint256 batchTransferAmount = 2 * crossTransferAmount;
    if (middleCase >= 1e17) {
      batchTransferAmount += middleCase;
    }
    uint256 systemTransferAmount = directTransferAmount + crossTransferAmount + (1e5 - 1e5 * burnRatio / burnRatioScale);

    vm.expectEmit(false, false, false, true, address(validator));
    emit batchTransfer(batchTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransferFail(payable(newValidators[0]), directTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransfer(payable(newValidators[1]), directTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    if (middleCase < 1e17) {
      vm.expectEmit(true, false, false, true, address(validator));
      emit directTransfer(payable(newValidators[2]), middleCase);
    }
    emit systemTransfer(systemTransferAmount);
    vm.expectEmit(false, false, false, false, address(validator));
    emit validatorSetUpdated();

    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, pack);

    assertEq(newValidators[0].balance, 0);
    assertEq(newValidators[1].balance, balance + directTransferAmount);
    if (middleCase < 1e17) {
      assertEq(newValidators[2].balance, balance + middleCase);
    } else {
      assertEq(newValidators[2].balance, balance);
    }
    assertEq(newValidators[3].balance, balance);
    assertEq(newValidators[4].balance, balance);
    assertEq(deprecated.balance, balance);
  }

  // cross chain transfer failed
  function testComplicateDistribute3() public {
    address[] memory newValidators = new address[](5);
    address deprecated = addrSet[addrIdx++];
    uint256 balance = deprecated.balance;
    newValidators[0] = address(slash);  // set fee addr to a contract
    vm.deal(newValidators[0], 0);
    for (uint256 i = 1; i < 5; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }
    // set mock tokenHub
    address mockTokenHub = deployCode("MockTokenHub.sol");
    vm.etch(address(tokenHub), mockTokenHub.code);
    (bool success,) = address(tokenHub).call(abi.encodeWithSignature("setPanicBatchTransferOut(bool)", true));
    require(success);

    bytes memory pack = encodeOldValidatorSetUpdatePack(0x00, newValidators);
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, pack);

    vm.startPrank(coinbase);
    validator.deposit{value: 1e16}(newValidators[0]); // fee addr is a contract
    validator.deposit{value: 1e16}(newValidators[1]);
    validator.deposit{value: 1e17}(newValidators[2]); // middle case
    validator.deposit{value: 1e18}(newValidators[3]);
    validator.deposit{value: 1e18}(newValidators[4]);
    validator.deposit{value: 1e18}(deprecated); // deprecated case
    validator.deposit{value: 1e5}(newValidators[4]); // dust case
    vm.stopPrank();

    uint256 directTransferAmount = 1e16 - 1e16 * burnRatio / burnRatioScale;
    uint256 crossTransferAmount = 1e18 - 1e18 * burnRatio / burnRatioScale;
    uint256 middleCase = 1e17 - 1e17 * burnRatio / burnRatioScale;
    uint256 batchTransferAmount = 2 * crossTransferAmount;
    if (middleCase >= 1e17) {
      batchTransferAmount += middleCase;
    }
    uint256 systemTransferAmount = directTransferAmount + crossTransferAmount;

    vm.expectEmit(false, false, false, true, address(validator));
    emit batchTransferFailed(batchTransferAmount, "panic in batchTransferOut");
    vm.expectEmit(true, false, false, false, address(validator));
    emit directTransfer(payable(newValidators[3]), crossTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransfer(payable(newValidators[4]), crossTransferAmount + 1e5 - 1e5 * burnRatio / burnRatioScale);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransferFail(payable(newValidators[0]), directTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    emit directTransfer(payable(newValidators[1]), directTransferAmount);
    vm.expectEmit(true, false, false, true, address(validator));
    if (middleCase < 1e17) {
      vm.expectEmit(true, false, false, true, address(validator));
      emit directTransfer(payable(newValidators[2]), middleCase);
    }
    emit systemTransfer(systemTransferAmount);
    vm.expectEmit(false, false, false, false, address(validator));
    emit validatorSetUpdated();

    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, pack);

    assertEq(newValidators[0].balance, 0);
    assertEq(newValidators[1].balance, balance + directTransferAmount);
    assertEq(newValidators[2].balance, balance + middleCase);
    assertEq(newValidators[3].balance, balance + crossTransferAmount);
    assertEq(newValidators[4].balance, balance + crossTransferAmount + 1e5 - 1e5 * burnRatio / burnRatioScale);
    assertEq(deprecated.balance, balance);
  }

  function testJail() public {
    address[] memory newValidators = new address[](3);
    for (uint256 i; i < 3; ++i) {
      newValidators[i] = addrSet[addrIdx++];
    }

    vm.startPrank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x00, newValidators));

    address[] memory remainVals = validator.getValidators();
    assertEq(remainVals.length, 3);
    for (uint256 i; i < 3; ++i) {
      assertEq(remainVals[i], newValidators[i]);
    }

    vm.expectEmit(false, false, false, true, address(validator));
    emit failReasonWithStr("length of jail validators must be one");
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x01, newValidators));

    address[] memory jailVal = new address[](1);
    jailVal[0] = newValidators[0];
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x01, jailVal));

    remainVals = validator.getValidators();
    assertEq(remainVals.length, 2);
    for (uint256 i; i < 2; ++i) {
      assertEq(remainVals[i], newValidators[i + 1]);
    }

    jailVal[0] = newValidators[1];
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x01, jailVal));
    remainVals = validator.getValidators();
    assertEq(remainVals.length, 1);
    assertEq(remainVals[0], newValidators[2]);

    jailVal[0] = newValidators[2];
    validator.handleSynPackage(STAKING_CHANNELID, encodeOldValidatorSetUpdatePack(0x01, jailVal));
    remainVals = validator.getValidators();
    assertEq(remainVals.length, 1);
    assertEq(remainVals[0], newValidators[2]);
    vm.stopPrank();
  }

  function testDecodeNewCrossChainPack() public {
    uint256 maxElectedValidators = stakeHub.maxElectedValidators();

    address[] memory newValidators = new address[](maxElectedValidators);
    bytes[] memory newVoteAddrs = new bytes[](maxElectedValidators);
    for (uint256 i; i < newValidators.length; ++i) {
      newValidators[i] = addrSet[addrIdx++];
      newVoteAddrs[i] = abi.encodePacked(newValidators[i]);
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeNewValidatorSetUpdatePack(0x00, newValidators, newVoteAddrs));

    (address[] memory vals, bytes[] memory voteAddrs) = validator.getLivingValidators();
    for (uint256 i; i < maxElectedValidators; ++i) {
      assertEq(voteAddrs[i], abi.encodePacked(vals[i]));
    }

    // edit vote addr for existed validator
    for (uint256 i; i < maxElectedValidators; ++i) {
      newVoteAddrs[i] = abi.encodePacked(newValidators[i], "0x1234567890");
    }
    vm.prank(address(crossChain));
    validator.handleSynPackage(STAKING_CHANNELID, encodeNewValidatorSetUpdatePack(0x00, newValidators, newVoteAddrs));

    (vals, voteAddrs) = validator.getLivingValidators();
    for (uint256 i; i < maxElectedValidators; ++i) {
      assertEq(voteAddrs[i], abi.encodePacked(newValidators[i], "0x1234567890"));
    }
  }

  function testDistributeFinalityReward() public {
    address[] memory addrs = new address[](20);
    uint256[] memory weights = new uint256[](20);
    address[] memory vals = validator.getValidators();
    for (uint256 i; i < 10; ++i) {
      addrs[i] = vals[i];
      weights[i] = 1;
    }

    for (uint256 i = 10; i < 20; ++i) {
      vals[i] = addrSet[addrIdx++];
      weights[i] = 1;
    }

    vm.deal(address(systemReward), 90 ether);
    vm.expectRevert(bytes("the message sender must be the block producer"));
    validator.distributeFinalityReward(addrs, weights);

    // distribute to set previousBalanceOfSystemReward(90 ether)
    vm.startPrank(address(coinbase));
    validator.distributeFinalityReward(addrs, weights);

    // 0. distribute failed (twice in one height)
    vm.expectRevert(bytes("can not do this twice in one block"));
    validator.distributeFinalityReward(addrs, weights);

    // 1. 100 ether >= balanceOfSystemReward > previousBalanceOfSystemReward(90 ether)
    vm.deal(address(systemReward), 100 ether);
    vm.roll(block.number + 1);

    uint256 previousBalanceOfSystemReward = validator.previousBalanceOfSystemReward();
    uint256 finalityRewardRatio = validator.finalityRewardRatio();
    uint256 expectReward = ((100 ether - previousBalanceOfSystemReward) * finalityRewardRatio) / (100 * 20);

    vm.expectEmit(true, false, false, true, address(validator));
    emit finalityRewardDeposit(addrs[0], expectReward);
    vm.expectEmit(true, false, false, true, address(validator));
    emit finalityRewardDeposit(addrs[9], expectReward);
    vm.expectEmit(true, false, false, true, address(validator));
    emit deprecatedFinalityRewardDeposit(addrs[10], expectReward);
    vm.expectEmit(true, false, false, true, address(validator));
    emit deprecatedFinalityRewardDeposit(addrs[19], expectReward);
    validator.distributeFinalityReward(addrs, weights);

    // 2. balanceOfSystemReward <= previousBalanceOfSystemReward
    previousBalanceOfSystemReward = validator.previousBalanceOfSystemReward();
    vm.roll(block.number + 1);

    validator.distributeFinalityReward(addrs, weights);
    assertEq(address(systemReward).balance, previousBalanceOfSystemReward);

    // 3. balanceOfSystemReward > 100 ether
    // total reward = 1 ether (balanceOfSystemReward / 100 > MAX_REWARDS
    vm.deal(address(systemReward), 110 ether);
    vm.roll(block.number + 1);

    expectReward = 1 ether / 20;

    vm.expectEmit(true, false, false, true, address(validator));
    emit finalityRewardDeposit(addrs[0], expectReward);
    vm.expectEmit(true, false, false, true, address(validator));
    emit finalityRewardDeposit(addrs[9], expectReward);
    vm.expectEmit(true, false, false, true, address(validator));
    emit deprecatedFinalityRewardDeposit(addrs[10], expectReward);
    vm.expectEmit(true, false, false, true, address(validator));
    emit deprecatedFinalityRewardDeposit(addrs[19], expectReward);
    validator.distributeFinalityReward(addrs, weights);
    assertEq(address(systemReward).balance, 109 ether);

    vm.stopPrank();
  }
}
