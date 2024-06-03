pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract ValidatorSetTest is Deployer {
    using RLPEncode for *;

    event validatorSetUpdated();
    event batchTransfer(uint256 amount);
    event batchTransferFailed(uint256 indexed amount, string reason);
    event systemTransfer(uint256 amount);
    event directTransfer(address payable indexed validator, uint256 amount);
    event directTransferFail(address payable indexed validator, uint256 amount);
    event deprecatedDeposit(address indexed validator, uint256 amount);
    event validatorDeposit(address indexed validator, uint256 amount);
    event failReasonWithStr(string message);
    event finalityRewardDeposit(address indexed validator, uint256 amount);
    event deprecatedFinalityRewardDeposit(address indexed validator, uint256 amount);
    event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);

    uint256 public totalInComing;
    uint256 public burnRatio;
    uint256 public burnRatioScale;
    uint256 public maxNumOfWorkingCandidates;
    uint256 public numOfCabinets;
    uint256 public systemRewardRatio;
    uint256 public systemRewardRatioScale;

    address public coinbase;
    address public validator0;
    mapping(address => bool) public cabinets;

    function setUp() public {
        // add operator
        bytes memory key = "addOperator";
        bytes memory valueBytes = abi.encodePacked(address(bscValidatorSet));
        vm.expectEmit(false, false, false, true, address(systemReward));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(systemReward));
        assertTrue(systemReward.isOperator(address(bscValidatorSet)));

        burnRatio =
            bscValidatorSet.isSystemRewardIncluded() ? bscValidatorSet.burnRatio() : bscValidatorSet.INIT_BURN_RATIO();
        burnRatioScale = bscValidatorSet.BLOCK_FEES_RATIO_SCALE();
        systemRewardRatio = bscValidatorSet.isSystemRewardIncluded()
            ? bscValidatorSet.systemRewardRatio()
            : bscValidatorSet.INIT_SYSTEM_REWARD_RATIO();
        systemRewardRatioScale = bscValidatorSet.BLOCK_FEES_RATIO_SCALE();
        totalInComing = bscValidatorSet.totalInComing();
        maxNumOfWorkingCandidates = bscValidatorSet.maxNumOfWorkingCandidates();
        numOfCabinets = bscValidatorSet.numOfCabinets();

        address[] memory validators = bscValidatorSet.getValidators();
        validator0 = validators[0];

        coinbase = block.coinbase;
        vm.deal(coinbase, 100 ether);

        // set gas price to zero to send system slash tx
        vm.txGasPrice(0);
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount >= 1e16);
        vm.assume(amount <= 1e19);

        vm.expectRevert("the message sender must be the block producer");
        bscValidatorSet.deposit{ value: amount }(validator0);

        vm.startPrank(coinbase);
        vm.expectRevert("deposit value is zero");
        bscValidatorSet.deposit(validator0);

        uint256 realAmount = _calcIncoming(amount);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit validatorDeposit(validator0, realAmount);
        bscValidatorSet.deposit{ value: amount }(validator0);

        address newAccount = _getNextUserAddress();
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit deprecatedDeposit(newAccount, realAmount);
        bscValidatorSet.deposit{ value: amount }(newAccount);

        assertEq(bscValidatorSet.totalInComing(), totalInComing + realAmount);
        vm.stopPrank();
    }

    function testGov() public {
        bytes memory key = "maxNumOfWorkingCandidates";
        bytes memory value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000015"); // 21
        vm.expectEmit(false, false, false, true, address(govHub));
        emit failReasonWithStr("the maxNumOfWorkingCandidates must be not greater than maxNumOfCandidates");
        _updateParamByGovHub(key, value, address(bscValidatorSet));
        assertEq(bscValidatorSet.maxNumOfWorkingCandidates(), maxNumOfWorkingCandidates);

        value = bytes(hex"000000000000000000000000000000000000000000000000000000000000000a"); // 10
        _updateParamByGovHub(key, value, address(bscValidatorSet));
        assertEq(bscValidatorSet.maxNumOfWorkingCandidates(), 10);

        key = "maxNumOfCandidates";
        value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000005"); // 5
        _updateParamByGovHub(key, value, address(bscValidatorSet));
        assertEq(bscValidatorSet.maxNumOfCandidates(), 5);
        assertEq(bscValidatorSet.maxNumOfWorkingCandidates(), 5);
    }

    // todo: fix this after bc-fusion second sunset
    //    function testGetMiningValidatorsWith41Vals() public {
    //        address[] memory newValidators = new address[](41);
    //        for (uint256 i; i < 41; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidators));
    //
    //        address[] memory vals = bscValidatorSet.getValidators();
    //        (address[] memory miningVals,) = bscValidatorSet.getMiningValidators();
    //
    //        uint256 count;
    //        uint256 _numOfCabinets;
    //        uint256 _maxNumOfWorkingCandidates = maxNumOfWorkingCandidates;
    //        if (numOfCabinets == 0) {
    //            _numOfCabinets = bscValidatorSet.INIT_NUM_OF_CABINETS();
    //        } else {
    //            _numOfCabinets = numOfCabinets;
    //        }
    //        if ((vals.length - _numOfCabinets) < _maxNumOfWorkingCandidates) {
    //            _maxNumOfWorkingCandidates = vals.length - _numOfCabinets;
    //        }
    //
    //        for (uint256 i; i < _numOfCabinets; ++i) {
    //            cabinets[vals[i]] = true;
    //        }
    //        for (uint256 i; i < _numOfCabinets; ++i) {
    //            if (!cabinets[miningVals[i]]) {
    //                ++count;
    //            }
    //        }
    //        assertGe(_maxNumOfWorkingCandidates, count);
    //        assertGe(count, 0);
    //    }
    //
    //    function testDistributeAlgorithm() public {
    //        address[] memory newValidator = new address[](1);
    //        newValidator[0] = _getNextUserAddress();
    //
    //        // To reset the incoming
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidator));
    //
    //        address val = newValidator[0];
    //        address tmp = _getNextUserAddress();
    //        vm.deal(address(bscValidatorSet), 0);
    //
    //        vm.startPrank(coinbase);
    //        for (uint256 i; i < 5; ++i) {
    //            bscValidatorSet.deposit{ value: 1 ether }(val);
    //            bscValidatorSet.deposit{ value: 1 ether }(tmp);
    //            bscValidatorSet.deposit{ value: 0.1 ether }(val);
    //            bscValidatorSet.deposit{ value: 0.1 ether }(tmp);
    //        }
    //        vm.stopPrank();
    //
    //        uint256 expectedBalance = _calcIncoming(11 ether);
    //        uint256 expectedIncoming = _calcIncoming(5.5 ether);
    //        uint256 balance = address(bscValidatorSet).balance;
    //        uint256 incoming = bscValidatorSet.totalInComing();
    //        assertEq(balance, expectedBalance);
    //        assertEq(incoming, expectedIncoming);
    //
    //        newValidator[0] = _getNextUserAddress();
    //
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit batchTransfer(expectedIncoming);
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit systemTransfer(expectedBalance - expectedIncoming);
    //        vm.expectEmit(false, false, false, false, address(bscValidatorSet));
    //        emit validatorSetUpdated();
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidator));
    //    }
    //
    //    function testMassiveDistribute() public {
    //        address[] memory newValidators = new address[](41);
    //        for (uint256 i; i < 41; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //
    //        // To reset the incoming
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidators));
    //
    //        vm.startPrank(coinbase);
    //        for (uint256 i; i < 41; ++i) {
    //            bscValidatorSet.deposit{ value: 1 ether }(newValidators[i]);
    //        }
    //        vm.stopPrank();
    //
    //        for (uint256 i; i < 41; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidators));
    //    }
    //
    //    function testUpdateValidatorExceedCap() public {
    //        uint256 cap = bscValidatorSet.MAX_NUM_OF_VALIDATORS();
    //        address[] memory newValidators = new address[](cap + 1);
    //        for (uint256 i; i < cap + 1; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //
    //        // To reset the incoming
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit failReasonWithStr("the number of validators exceed the limit");
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidators));
    //    }
    //
    //    function testComplicateDistribute1() public {
    //        address[] memory newValidators = new address[](5);
    //        address deprecated = _getNextUserAddress();
    //        uint256 balance = deprecated.balance;
    //        for (uint256 i; i < 5; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //        bytes memory pack = _encodeOldValidatorSetUpdatePack(0x00, newValidators);
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, pack);
    //
    //        vm.startPrank(coinbase);
    //        bscValidatorSet.deposit{ value: 1e16 }(newValidators[0]);
    //        bscValidatorSet.deposit{ value: 1e16 }(newValidators[1]);
    //        bscValidatorSet.deposit{ value: 1e17 }(newValidators[2]); // middle case
    //        bscValidatorSet.deposit{ value: 1e18 }(newValidators[3]);
    //        bscValidatorSet.deposit{ value: 1e18 }(newValidators[4]);
    //        bscValidatorSet.deposit{ value: 1e18 }(deprecated); // deprecated case
    //        bscValidatorSet.deposit{ value: 1e5 }(newValidators[4]); // dust case
    //        vm.stopPrank();
    //
    //        uint256 directTransferAmount = _calcIncoming(1e16);
    //        uint256 crossTransferAmount = _calcIncoming(1e18);
    //        uint256 middleCase = _calcIncoming(1e17);
    //        uint256 batchTransferAmount = 2 * crossTransferAmount;
    //        if (middleCase >= 1e17) {
    //            batchTransferAmount += middleCase;
    //        }
    //        uint256 systemTransferAmount = crossTransferAmount + (_calcIncoming(1e5));
    //
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit batchTransfer(batchTransferAmount);
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransfer(payable(newValidators[0]), directTransferAmount);
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransfer(payable(newValidators[1]), directTransferAmount);
    //        if (middleCase < 1e17) {
    //            vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //            emit directTransfer(payable(newValidators[2]), middleCase);
    //        }
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit systemTransfer(systemTransferAmount);
    //        vm.expectEmit(false, false, false, false, address(bscValidatorSet));
    //        emit validatorSetUpdated();
    //
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, pack);
    //
    //        assertEq(newValidators[0].balance, balance + directTransferAmount);
    //        assertEq(newValidators[1].balance, balance + directTransferAmount);
    //        if (middleCase < 1e17) {
    //            assertEq(newValidators[2].balance, balance + middleCase);
    //        } else {
    //            assertEq(newValidators[2].balance, balance);
    //        }
    //        assertEq(newValidators[3].balance, balance);
    //        assertEq(newValidators[4].balance, balance);
    //        assertEq(deprecated.balance, balance);
    //    }
    //
    //    function testCannotUpdateValidatorSet() public {
    //        address[][] memory newValSet = new address[][](4);
    //        newValSet[0] = new address[](3);
    //        newValSet[0][0] = _getNextUserAddress();
    //        newValSet[0][1] = newValSet[0][0];
    //        newValSet[0][2] = _getNextUserAddress();
    //        newValSet[1] = new address[](3);
    //        newValSet[1][0] = _getNextUserAddress();
    //        newValSet[1][1] = _getNextUserAddress();
    //        newValSet[1][2] = newValSet[1][1];
    //        newValSet[2] = new address[](4);
    //        newValSet[2][0] = _getNextUserAddress();
    //        newValSet[2][1] = _getNextUserAddress();
    //        newValSet[2][2] = _getNextUserAddress();
    //        newValSet[2][3] = _getNextUserAddress();
    //
    //        vm.startPrank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValSet[2]));
    //        for (uint256 i; i < 2; ++i) {
    //            vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //            emit failReasonWithStr("duplicate consensus address of validatorSet");
    //            bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValSet[i]));
    //        }
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValSet[3]));
    //        vm.stopPrank();
    //
    //        uint64 _height = crossChain.channelSyncedHeaderMap(STAKING_CHANNELID);
    //        uint64 _sequence = crossChain.channelReceiveSequenceMap(STAKING_CHANNELID);
    //        vm.expectRevert(bytes("the msg sender is not a relayer"));
    //        crossChain.handlePackage(bytes("1"), bytes("2"), _height, _sequence, STAKING_CHANNELID);
    //
    //        vm.expectRevert(bytes("light client not sync the block yet"));
    //        vm.startPrank(address(relayer));
    //        crossChain.handlePackage(bytes("1"), bytes("2"), type(uint64).max, _sequence, STAKING_CHANNELID);
    //
    //        vm.expectEmit(true, false, false, true, address(crossChain));
    //        emit unsupportedPackage(_sequence, STAKING_CHANNELID, bytes("1"));
    //        vm.mockCall(address(0x65), "", hex"0000000000000000000000000000000000000000000000000000000000000001");
    //        crossChain.handlePackage(bytes("1"), bytes("2"), _height, _sequence, STAKING_CHANNELID);
    //
    //        vm.stopPrank();
    //    }
    //
    //    // one validator's fee addr is a contract
    //    function testComplicateDistribute2() public {
    //        address[] memory newValidators = new address[](5);
    //        address deprecated = _getNextUserAddress();
    //        uint256 balance = deprecated.balance;
    //        newValidators[0] = address(slashIndicator); // set fee addr to a contract
    //        vm.deal(newValidators[0], 0);
    //        for (uint256 i = 1; i < 5; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //        bytes memory pack = _encodeOldValidatorSetUpdatePack(0x00, newValidators);
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, pack);
    //
    //        vm.startPrank(coinbase);
    //        bscValidatorSet.deposit{ value: 1e16 }(newValidators[0]); // fee addr is a contract
    //        bscValidatorSet.deposit{ value: 1e16 }(newValidators[1]);
    //        bscValidatorSet.deposit{ value: 1e17 }(newValidators[2]); // middle case
    //        bscValidatorSet.deposit{ value: 1e18 }(newValidators[3]);
    //        bscValidatorSet.deposit{ value: 1e18 }(newValidators[4]);
    //        bscValidatorSet.deposit{ value: 1e18 }(deprecated); // deprecated case
    //        bscValidatorSet.deposit{ value: 1e5 }(newValidators[4]); // dust case
    //        vm.stopPrank();
    //
    //        uint256 directTransferAmount = _calcIncoming(1e16);
    //        uint256 crossTransferAmount = _calcIncoming(1e18);
    //        uint256 middleCase = _calcIncoming(1e17);
    //        uint256 batchTransferAmount = 2 * crossTransferAmount;
    //        if (middleCase >= 1e17) {
    //            batchTransferAmount += middleCase;
    //        }
    //        uint256 systemTransferAmount = directTransferAmount + crossTransferAmount + (_calcIncoming(1e5));
    //
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit batchTransfer(batchTransferAmount);
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransferFail(payable(newValidators[0]), directTransferAmount);
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransfer(payable(newValidators[1]), directTransferAmount);
    //        if (middleCase < 1e17) {
    //            vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //            emit directTransfer(payable(newValidators[2]), middleCase);
    //        }
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit systemTransfer(systemTransferAmount);
    //        vm.expectEmit(false, false, false, false, address(bscValidatorSet));
    //        emit validatorSetUpdated();
    //
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, pack);
    //
    //        assertEq(newValidators[0].balance, 0);
    //        assertEq(newValidators[1].balance, balance + directTransferAmount);
    //        if (middleCase < 1e17) {
    //            assertEq(newValidators[2].balance, balance + middleCase);
    //        } else {
    //            assertEq(newValidators[2].balance, balance);
    //        }
    //        assertEq(newValidators[3].balance, balance);
    //        assertEq(newValidators[4].balance, balance);
    //        assertEq(deprecated.balance, balance);
    //    }
    //
    //    // cross chain transfer failed
    //    function testComplicateDistribute3() public {
    //        address[] memory newValidators = new address[](5);
    //        address deprecated = _getNextUserAddress();
    //        uint256 balance = deprecated.balance;
    //        newValidators[0] = address(slashIndicator); // set fee addr to a contract
    //        vm.deal(newValidators[0], 0);
    //        for (uint256 i = 1; i < 5; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //        // set mock tokenHub
    //        address mockTokenHub = deployCode("MockTokenHub.sol");
    //        vm.etch(address(tokenHub), mockTokenHub.code);
    //        (bool success,) = address(tokenHub).call(abi.encodeWithSignature("setPanicBatchTransferOut(bool)", true));
    //        require(success);
    //
    //        bytes memory pack = _encodeOldValidatorSetUpdatePack(0x00, newValidators);
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, pack);
    //
    //        vm.startPrank(coinbase);
    //        bscValidatorSet.deposit{ value: 1e16 }(newValidators[0]); // fee addr is a contract
    //        bscValidatorSet.deposit{ value: 1e16 }(newValidators[1]);
    //        bscValidatorSet.deposit{ value: 1e17 }(newValidators[2]); // middle case
    //        bscValidatorSet.deposit{ value: 1e18 }(newValidators[3]);
    //        bscValidatorSet.deposit{ value: 1e18 }(newValidators[4]);
    //        bscValidatorSet.deposit{ value: 1e18 }(deprecated); // deprecated case
    //        bscValidatorSet.deposit{ value: 1e5 }(newValidators[4]); // dust case
    //        vm.stopPrank();
    //
    //        uint256 directTransferAmount = _calcIncoming(1e16);
    //        uint256 crossTransferAmount = _calcIncoming(1e18);
    //        uint256 middleCase = _calcIncoming(1e17);
    //        uint256 batchTransferAmount = 2 * crossTransferAmount;
    //        if (middleCase >= 1e17) {
    //            batchTransferAmount += middleCase;
    //        }
    //        uint256 systemTransferAmount = directTransferAmount + crossTransferAmount;
    //
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit batchTransferFailed(batchTransferAmount, "panic in batchTransferOut");
    //        vm.expectEmit(true, false, false, false, address(bscValidatorSet));
    //        emit directTransfer(payable(newValidators[3]), crossTransferAmount);
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransfer(payable(newValidators[4]), crossTransferAmount + _calcIncoming(1e5));
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransferFail(payable(newValidators[0]), directTransferAmount);
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit directTransfer(payable(newValidators[1]), directTransferAmount);
    //        if (middleCase < 1e17) {
    //            vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //            emit directTransfer(payable(newValidators[2]), middleCase);
    //        }
    //        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
    //        emit systemTransfer(systemTransferAmount);
    //        vm.expectEmit(false, false, false, false, address(bscValidatorSet));
    //        emit validatorSetUpdated();
    //
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, pack);
    //
    //        assertEq(newValidators[0].balance, 0);
    //        assertEq(newValidators[1].balance, balance + directTransferAmount);
    //        assertEq(newValidators[2].balance, balance + middleCase);
    //        assertEq(newValidators[3].balance, balance + crossTransferAmount);
    //        assertEq(newValidators[4].balance, balance + crossTransferAmount + _calcIncoming(1e5));
    //        assertEq(deprecated.balance, balance);
    //    }

    //  function testValidateSetChange() public {
    //        address[][] memory newValSet = new address[][](5);
    //        for (uint256 i; i < 5; ++i) {
    //            address[] memory valSet = new address[](5 + i);
    //            for (uint256 j; j < 5 + i; ++j) {
    //                valSet[j] = _getNextUserAddress();
    //            }
    //            newValSet[i] = valSet;
    //        }
    //
    //        vm.startPrank(address(crossChain));
    //        for (uint256 k; k < 5; ++k) {
    //            bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValSet[k]));
    //            address[] memory valSet = bscValidatorSet.getValidators();
    //            for (uint256 l; l < 5 + k; ++l) {
    //                assertEq(valSet[l], newValSet[k][l], "consensusAddr not equal");
    //                assertTrue(bscValidatorSet.isCurrentValidator(newValSet[k][l]), "the address should be a validator");
    //            }
    //        }
    //        vm.stopPrank();
    //    }

    //    function testJail() public {
    //        address[] memory newValidators = new address[](3);
    //        for (uint256 i; i < 3; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //        }
    //
    //        vm.startPrank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newValidators));
    //
    //        address[] memory remainVals = bscValidatorSet.getValidators();
    //        assertEq(remainVals.length, 3);
    //        for (uint256 i; i < 3; ++i) {
    //            assertEq(remainVals[i], newValidators[i]);
    //        }
    //
    //        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
    //        emit failReasonWithStr("length of jail validators must be one");
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x01, newValidators));
    //
    //        address[] memory jailVal = new address[](1);
    //        jailVal[0] = newValidators[0];
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x01, jailVal));
    //
    //        remainVals = bscValidatorSet.getValidators();
    //        assertEq(remainVals.length, 2);
    //        for (uint256 i; i < 2; ++i) {
    //            assertEq(remainVals[i], newValidators[i + 1]);
    //        }
    //
    //        jailVal[0] = newValidators[1];
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x01, jailVal));
    //        remainVals = bscValidatorSet.getValidators();
    //        assertEq(remainVals.length, 1);
    //        assertEq(remainVals[0], newValidators[2]);
    //
    //        jailVal[0] = newValidators[2];
    //        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x01, jailVal));
    //        remainVals = bscValidatorSet.getValidators();
    //        assertEq(remainVals.length, 1);
    //        assertEq(remainVals[0], newValidators[2]);
    //        vm.stopPrank();
    //    }

    //    function testDecodeNewCrossChainPack() public {
    //        uint256 maxElectedValidators = stakeHub.maxElectedValidators();
    //
    //        address[] memory newValidators = new address[](maxElectedValidators);
    //        bytes[] memory newVoteAddrs = new bytes[](maxElectedValidators);
    //        for (uint256 i; i < newValidators.length; ++i) {
    //            newValidators[i] = _getNextUserAddress();
    //            newVoteAddrs[i] = abi.encodePacked(newValidators[i]);
    //        }
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(
    //            STAKING_CHANNELID, _encodeNewValidatorSetUpdatePack(0x00, newValidators, newVoteAddrs)
    //        );
    //
    //        (address[] memory vals, bytes[] memory voteAddrs) = bscValidatorSet.getLivingValidators();
    //        for (uint256 i; i < maxElectedValidators; ++i) {
    //            assertEq(voteAddrs[i], abi.encodePacked(vals[i]));
    //        }
    //
    //        // edit vote addr for existed validator
    //        for (uint256 i; i < maxElectedValidators; ++i) {
    //            newVoteAddrs[i] = abi.encodePacked(newValidators[i], "0x1234567890");
    //        }
    //        vm.prank(address(crossChain));
    //        bscValidatorSet.handleSynPackage(
    //            STAKING_CHANNELID, _encodeNewValidatorSetUpdatePack(0x00, newValidators, newVoteAddrs)
    //        );
    //
    //        (vals, voteAddrs) = bscValidatorSet.getLivingValidators();
    //        for (uint256 i; i < maxElectedValidators; ++i) {
    //            assertEq(voteAddrs[i], abi.encodePacked(newValidators[i], "0x1234567890"));
    //        }
    //    }

    function testDistributeFinalityReward() public {
        address[] memory addrs = new address[](20);
        uint256[] memory weights = new uint256[](20);
        address[] memory vals = bscValidatorSet.getValidators();
        for (uint256 i; i < 10; ++i) {
            addrs[i] = vals[i];
            weights[i] = 1;
        }

        for (uint256 i = 10; i < 20; ++i) {
            vals[i] = _getNextUserAddress();
            weights[i] = 1;
        }

        // failed case
        uint256 ceil = bscValidatorSet.MAX_SYSTEM_REWARD_BALANCE();
        vm.deal(address(systemReward), ceil - 1);
        vm.expectRevert(bytes("the message sender must be the block producer"));
        bscValidatorSet.distributeFinalityReward(addrs, weights);

        vm.startPrank(coinbase);
        bscValidatorSet.distributeFinalityReward(addrs, weights);
        vm.expectRevert(bytes("can not do this twice in one block"));
        bscValidatorSet.distributeFinalityReward(addrs, weights);

        // success case
        // balanceOfSystemReward > MAX_SYSTEM_REWARD_BALANCE
        uint256 reward = 1 ether;
        vm.deal(address(systemReward), ceil + reward);
        vm.roll(block.number + 1);

        uint256 expectReward = reward / 20;
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit finalityRewardDeposit(addrs[0], expectReward);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit finalityRewardDeposit(addrs[9], expectReward);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit deprecatedFinalityRewardDeposit(addrs[10], expectReward);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit deprecatedFinalityRewardDeposit(addrs[19], expectReward);
        bscValidatorSet.distributeFinalityReward(addrs, weights);
        assertEq(address(systemReward).balance, ceil);

        // cannot exceed MAX_REWARDS
        uint256 cap = systemReward.MAX_REWARDS();
        vm.deal(address(systemReward), ceil + cap * 2);
        vm.roll(block.number + 1);

        expectReward = cap / 20;
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit finalityRewardDeposit(addrs[0], expectReward);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit finalityRewardDeposit(addrs[9], expectReward);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit deprecatedFinalityRewardDeposit(addrs[10], expectReward);
        vm.expectEmit(true, false, false, true, address(bscValidatorSet));
        emit deprecatedFinalityRewardDeposit(addrs[19], expectReward);
        bscValidatorSet.distributeFinalityReward(addrs, weights);
        assertEq(address(systemReward).balance, ceil + cap);

        vm.stopPrank();
    }

    function _calcIncoming(uint256 value) internal view returns (uint256 incoming) {
        uint256 toSystemReward = (value * systemRewardRatio) / systemRewardRatioScale;
        uint256 toBurn = (value * burnRatio) / burnRatioScale;
        incoming = value - toSystemReward - toBurn;
    }
}
