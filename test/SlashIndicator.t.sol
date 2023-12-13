pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract SlashIndicatorTest is Deployer {
    event validatorSlashed(address indexed validator0);
    event maliciousVoteSlashed(bytes32 indexed voteAddrSlice);

    uint256 public burnRatio;
    uint256 public burnRatioScale;
    uint256 public systemRewardRatio;
    uint256 public systemRewardRatioScale;

    address public coinbase;
    address public validator0;

    function setUp() public {
        burnRatio =
            bscValidatorSet.isSystemRewardIncluded() ? bscValidatorSet.burnRatio() : bscValidatorSet.INIT_BURN_RATIO();
        burnRatioScale = bscValidatorSet.BURN_RATIO_SCALE();

        systemRewardRatio = bscValidatorSet.isSystemRewardIncluded()
            ? bscValidatorSet.systemRewardRatio()
            : bscValidatorSet.INIT_SYSTEM_REWARD_RATIO();
        systemRewardRatioScale = bscValidatorSet.SYSTEM_REWARD_RATIO_SCALE();

        address[] memory validators = bscValidatorSet.getValidators();
        validator0 = validators[0];

        coinbase = block.coinbase;
        vm.deal(coinbase, 100 ether);

        vm.txGasPrice(0);

        // remove this after fusion fork launched
        vm.prank(block.coinbase);
        stakeHub.initialize();
    }

    function testGov() public {
        bytes memory key = "misdemeanorThreshold";
        bytes memory value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000064"); // 100
        _updateParamByGovHub(key, value, address(slashIndicator));
        assertEq(slashIndicator.misdemeanorThreshold(), 100);

        key = "felonyThreshold";
        value = bytes(hex"00000000000000000000000000000000000000000000000000000000000000c8"); // 200
        _updateParamByGovHub(key, value, address(slashIndicator));
        assertEq(slashIndicator.felonyThreshold(), 200);

        key = "felonySlashRewardRatio";
        value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000032"); // 50
        _updateParamByGovHub(key, value, address(slashIndicator));
        assertEq(slashIndicator.felonySlashRewardRatio(), 50);
    }

    function testSlash() public {
        vm.expectRevert(bytes("the message sender must be the block producer"));
        slashIndicator.slash(validator0);

        vm.startPrank(coinbase);
        vm.txGasPrice(0);
        (, uint256 origin) = slashIndicator.getSlashIndicator(validator0);
        for (uint256 i = 1; i < 10; ++i) {
            vm.expectEmit(true, false, false, true, address(slashIndicator));
            emit validatorSlashed(validator0);
            slashIndicator.slash(validator0);
            vm.roll(block.number + 1);
            (, uint256 count) = slashIndicator.getSlashIndicator(validator0);
            assertEq(origin + i, count);
        }
        vm.stopPrank();
    }

    function testMaintenance() public {
        vm.prank(validator0);
        bscValidatorSet.enterMaintenance();

        (, uint256 countBefore) = slashIndicator.getSlashIndicator(validator0);
        vm.prank(coinbase);
        slashIndicator.slash(validator0);
        (, uint256 countAfter) = slashIndicator.getSlashIndicator(validator0);
        assertEq(countAfter, countBefore);

        vm.prank(validator0);
        vm.expectRevert(bytes("can not enter Temporary Maintenance"));
        bscValidatorSet.enterMaintenance();

        // exit maintenance
        vm.prank(validator0);
        bscValidatorSet.exitMaintenance();
        vm.roll(block.number + 1);
        vm.prank(coinbase);
        slashIndicator.slash(validator0);
        (, countAfter) = slashIndicator.getSlashIndicator(validator0);
        assertEq(countAfter, countBefore + 1);

        vm.prank(validator0);
        vm.expectRevert(bytes("can not enter Temporary Maintenance"));
        bscValidatorSet.enterMaintenance();
    }

    function testMisdemeanor() public {
        address[] memory vals = new address[](21);
        for (uint256 i; i < vals.length; ++i) {
            vals[i] = _getNextUserAddress();
        }
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, vals));

        vm.startPrank(coinbase);
        uint256 _deposit = 1 ether;
        uint256 _incoming = _calcIncoming(_deposit);
        bscValidatorSet.deposit{ value: _deposit }(vals[0]);
        assertEq(_incoming, bscValidatorSet.getIncoming(vals[0]));

        for (uint256 i; i < 50; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(vals[0]);
        }
        (, uint256 count) = slashIndicator.getSlashIndicator(vals[0]);
        assertEq(50, count);
        assertEq(0, bscValidatorSet.getIncoming(vals[0]));

        // enter maintenance, cannot be slashed
        vm.roll(block.number + 1);
        slashIndicator.slash(vals[0]);
        (, count) = slashIndicator.getSlashIndicator(vals[0]);
        assertEq(50, count);
        vm.stopPrank();

        address[] memory newVals = new address[](3);
        for (uint256 i; i < newVals.length; ++i) {
            newVals[i] = vals[i];
        }
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, newVals));

        vm.startPrank(coinbase);
        bscValidatorSet.deposit{ value: 2 ether }(newVals[0]);
        assertEq(_incoming * 2, bscValidatorSet.getIncoming(newVals[0]));

        for (uint256 i; i < 37; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(newVals[0]);
        }
        (, count) = slashIndicator.getSlashIndicator(newVals[0]);
        assertEq(50, count);
        assertEq(0, bscValidatorSet.getIncoming(newVals[0]));
        assertEq(_incoming, bscValidatorSet.getIncoming(newVals[1]));
        assertEq(_incoming, bscValidatorSet.getIncoming(newVals[2]));

        bscValidatorSet.deposit{ value: _deposit }(newVals[1]);
        assertEq(_incoming * 2, bscValidatorSet.getIncoming(newVals[1]));
        for (uint256 i; i < 50; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(newVals[1]);
        }
        assertEq(_incoming, bscValidatorSet.getIncoming(newVals[0]));
        assertEq(0, bscValidatorSet.getIncoming(newVals[1]));
        assertEq(_incoming * 2, bscValidatorSet.getIncoming(newVals[2]));

        assertEq(_incoming * 2, bscValidatorSet.getIncoming(newVals[2]));
        for (uint256 i; i < 50; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(newVals[2]);
        }
        assertEq(_incoming * 2, bscValidatorSet.getIncoming(newVals[0]));
        assertEq(_incoming, bscValidatorSet.getIncoming(newVals[1]));
        assertEq(0, bscValidatorSet.getIncoming(newVals[2]));
        vm.stopPrank();
    }

    function testFelony() public {
        address[] memory vals = new address[](3);
        for (uint256 i; i < vals.length; ++i) {
            vals[i] = _getNextUserAddress();
        }
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, vals));

        vm.startPrank(coinbase);
        uint256 _deposit = 1 ether;
        uint256 _incoming = _calcIncoming(_deposit);
        bscValidatorSet.deposit{ value: _deposit }(vals[0]);
        assertEq(_incoming, bscValidatorSet.getIncoming(vals[0]));

        for (uint256 i; i < 50; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(vals[0]);
        }
        (, uint256 count) = slashIndicator.getSlashIndicator(vals[0]);
        assertEq(50, count);
        assertEq(0, bscValidatorSet.getIncoming(vals[0]));
        vm.stopPrank();

        vm.prank(vals[0]);
        bscValidatorSet.exitMaintenance();

        vm.startPrank(coinbase);
        bscValidatorSet.deposit{ value: _deposit }(vals[0]);
        for (uint256 i; i < 100; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(vals[0]);
        }
        (, count) = slashIndicator.getSlashIndicator(vals[0]);
        assertEq(0, count);
        assertEq(0, bscValidatorSet.getIncoming(vals[0]));
        assertEq(_incoming, bscValidatorSet.getIncoming(vals[1]));
        assertEq(_incoming, bscValidatorSet.getIncoming(vals[2]));

        vals = bscValidatorSet.getValidators();
        assertEq(2, vals.length);
        vm.stopPrank();
    }

    function testClean() public {
        // case 1: all clean.
        address[] memory vals = new address[](20);
        for (uint256 i; i < vals.length; ++i) {
            vals[i] = _getNextUserAddress();
        }
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, vals));

        vm.startPrank(coinbase);
        for (uint256 i; i < vals.length; ++i) {
            vm.roll(block.number + 1);
            slashIndicator.slash(vals[i]);
        }
        vm.stopPrank();

        // do clean
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, vals));

        uint256 count;
        for (uint256 i; i < vals.length; ++i) {
            (, count) = slashIndicator.getSlashIndicator(vals[i]);
            assertEq(0, count);
        }

        // case 2: all stay.
        uint256 slashCount = 1 + slashIndicator.felonyThreshold() / slashIndicator.DECREASE_RATE();
        vm.startPrank(coinbase);
        for (uint256 i; i < vals.length; ++i) {
            for (uint256 j; j < slashCount; ++j) {
                vm.roll(block.number + 1);
                slashIndicator.slash(vals[i]);
            }
        }
        vm.stopPrank();

        // do clean
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, vals));

        for (uint256 i; i < vals.length; ++i) {
            (, count) = slashIndicator.getSlashIndicator(vals[i]);
            assertEq(1, count);
        }

        // case 3: partial stay.
        vm.startPrank(coinbase);
        for (uint256 i; i < 10; ++i) {
            for (uint256 j; j < slashCount; ++j) {
                vm.roll(block.number + 1);
                slashIndicator.slash(vals[2 * i]);
            }
            vm.roll(block.number + 1);
            slashIndicator.slash(vals[2 * i + 1]);
        }
        vm.stopPrank();

        // do clean
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeOldValidatorSetUpdatePack(0x00, vals));

        for (uint256 i; i < 10; ++i) {
            (, count) = slashIndicator.getSlashIndicator(vals[i]);
            if (i % 2 == 0) {
                assertEq(2, count);
            } else {
                assertEq(0, count);
            }
        }
    }

    function testDoubleSignSlash() public {
        // mock data
        bytes memory headerA =
            hex"f9030ca01062d3d5015b9242bc193a9b0769f3d3780ecb55f97f40a752ae26d0b68cd0d8a0fae1a05fcb14bfd9b8a9f2b65007a9b6c2000de0627a73be644dd993d32342c49423618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8fa0f385cc58ed297ff0d66eb5580b02853d3478ba418b1819ac659ee05df49b9794a0bf88464af369ed6b8cf02db00f0b9556ffa8d49cd491b00952a7f83431446638a00a6d0870e586a76278fbfdcedf76ef6679af18fc1f9137cfad495f434974ea81b901000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001820163830f4240830f424084655701ddb90111d983010301846765746888676f312e32302e378664617277696e000031ddff9bf8ae07b86091eb7f48a70683109dbaa093154ed45de46209dac537872b9bf80fa664330cde6a79a14c67051e565a3cbfe74d80a1c800725e2d253b4772a906ffb5d6326edbdba83ef42175209485be88f1423e7d12a5e187d73822d1ba14b95113f33507fef8488201c5a0ae7d5e81dda55bbbb8f35e9dffb2f55b873a34d97a0ee58bd911ae284bcc882d8201c6a0009aa8034b82c1240a9f2c434bf691c0e56cf33ddc071db0cafeba26371c6e7980b9510a26a4a0d6440c512cb47f4ddb01aa64339a1008eef17ed5d93d5970a6e769cba8fc4ea33f0f47b1bd5e0192a5c1496d02609e0895e07f9ff8648bfc5e0b01a0232c9ba2d41b40d36ed794c306747bcbc49bf61a0f37409c18bfe2b5bef26a2d880000000000000000";
        bytes memory headerB =
            hex"f9030ca01062d3d5015b9242bc193a9b0769f3d3780ecb55f97f40a752ae26d0b68cd0d8a0b2789a5357827ed838335283e15c4dcc42b9bebcbf2919a18613246787e2f9609423618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8fa071ce4c09ee275206013f0063761bc19c93c13990582f918cc57333634c94ce89a00e095703e5c9b149f253fe89697230029e32484a410b4b1f2c61442d73c3095aa0d317ae19ede7c8a2d3ac9ef98735b049bcb7278d12f48c42b924538b60a25e12b901000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001820163830f4240830f424084655701ddb90111d983010301846765746888676f312e32302e378664617277696e000031ddff9bf8ae07b86091eb7f48a70683109dbaa093154ed45de46209dac537872b9bf80fa664330cde6a79a14c67051e565a3cbfe74d80a1c800725e2d253b4772a906ffb5d6326edbdba83ef42175209485be88f1423e7d12a5e187d73822d1ba14b95113f33507fef8488201c5a0ae7d5e81dda55bbbb8f35e9dffb2f55b873a34d97a0ee58bd911ae284bcc882d8201c6a0009aa8034b82c1240a9f2c434bf691c0e56cf33ddc071db0cafeba26371c6e79801afe0399603e09a642efbd06645b4af1509db8b1db7681ed91bc1366fd22b7332a5f6028f3e11f92e89b910902a16a632c88e8ee45216d37b96261bd7e40559601a0b56228685be711834d0f154292d07826dea42a0fad3e4f56c31470b7fbfbea26880000000000000000";

        vm.mockCall(
            address(0x68),
            "",
            hex"23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f00000000000000000000000000000000000000000000000000000000655701dd"
        );
        vm.mockCall(
            address(stakeHub),
            abi.encodeCall(stakeHub.consensusToOperator, (0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f)),
            hex"00000000000000000000000023618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f"
        );
        vm.prank(relayer);
        vm.expectRevert(); // as no such operator address existed
        slashIndicator.submitDoubleSignEvidence(headerA, headerB);
    }

    function testMaliciousVoteSlash() public {
        if (!slashIndicator.enableMaliciousVoteSlash()) {
            bytes memory key = "enableMaliciousVoteSlash";
            bytes memory value = bytes(hex"0000000000000000000000000000000000000000000000000000000000000001");
            _updateParamByGovHub(key, value, address(slashIndicator));
        }

        address[] memory vals = new address[](20);
        bytes[] memory voteAddrs = new bytes[](20);
        for (uint256 i; i < vals.length; ++i) {
            vals[i] = _getNextUserAddress();
            voteAddrs[i] =
                bytes.concat(hex"00000000000000000000000000000000000000000000000000000000", abi.encodePacked(vals[i])); // 28 + 20
        }
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(STAKING_CHANNELID, _encodeNewValidatorSetUpdatePack(0x00, vals, voteAddrs));

        // case1: valid finality evidence: same target block
        uint256 srcNumA = block.number - 20;
        uint256 tarNumA = block.number - 10;
        uint256 srcNumB = block.number - 15;
        uint256 tarNumB = tarNumA;
        SlashIndicator.VoteData memory voteA;
        voteA.srcNum = srcNumA;
        voteA.srcHash = blockhash(srcNumA);
        voteA.tarNum = tarNumA;
        voteA.tarHash = blockhash(tarNumA);
        voteA.sig =
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";

        SlashIndicator.VoteData memory voteB;
        voteB.srcNum = srcNumB;
        voteB.srcHash = blockhash(srcNumB);
        voteB.tarNum = tarNumB;
        voteB.tarHash = blockhash(tarNumB);
        voteB.sig =
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002";

        SlashIndicator.FinalityEvidence memory evidence;
        evidence.voteA = voteA;
        evidence.voteB = voteB;
        evidence.voteAddr = voteAddrs[0];

        vm.mockCall(address(0x66), "", hex"01");
        bytes32 voteAddrSlice; // empty. don't check this
        vm.expectEmit(false, false, false, false, address(slashIndicator));
        emit maliciousVoteSlashed(voteAddrSlice);
        vm.prank(relayer);
        slashIndicator.submitFinalityViolationEvidence(evidence);
    }

    function _calcIncoming(uint256 value) internal view returns (uint256 incoming) {
        uint256 toSystemReward = (value * systemRewardRatio) / systemRewardRatioScale;
        uint256 toBurn = (value * burnRatio) / burnRatioScale;
        incoming = value - toSystemReward - toBurn;
    }
}
