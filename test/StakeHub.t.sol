pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./utils/Deployer.sol";

interface IStakeCredit {
    function balanceOf(address account) external view returns (uint256);
    function totalPooledBNB() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getPooledBNBByShares(uint256 shares) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
}

contract StakeHubTest is Deployer {
    using RLPEncode for *;

    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event DescriptionEdited(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event ValidatorSlashed(address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, uint8 slashType);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);

    receive() external payable { }

    function setUp() public {
        vm.mockCall(address(0x66), "", hex"01");

        // remove this after fusion fork launched
        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        stakeHub.initialize();
    }

    function testCreateAndEditValidator() public {
        // 1. create validator
        (address validator,) = _createValidator(2000 ether);
        vm.startPrank(validator);

        vm.expectRevert();
        stakeHub.editConsensusAddress(address(1));

        // 2. edit consensus address
        vm.warp(block.timestamp + 1 days);
        address newConsensusAddress = address(0x1234);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit ConsensusAddressEdited(validator, newConsensusAddress);
        stakeHub.editConsensusAddress(newConsensusAddress);
        (address realAddr,,,,,) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(realAddr, newConsensusAddress);

        // 3. edit commission rate
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert();
        stakeHub.editCommissionRate(110);
        vm.expectRevert();
        stakeHub.editCommissionRate(16);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit CommissionRateEdited(validator, 15);
        stakeHub.editCommissionRate(15);
        StakeHub.Commission memory realComm = stakeHub.getValidatorCommission(validator);
        assertEq(realComm.rate, 15);

        // 4. edit description
        vm.warp(block.timestamp + 1 days);
        StakeHub.Description memory description = stakeHub.getValidatorDescription(validator);
        // invalid moniker
        description.moniker = "test";
        vm.expectRevert();
        stakeHub.editDescription(description);

        description.moniker = "T";
        vm.expectRevert();
        stakeHub.editDescription(description);

        description.moniker = "Test;";
        vm.expectRevert();
        stakeHub.editDescription(description);

        description.moniker = "Test ";
        vm.expectRevert();
        stakeHub.editDescription(description);

        // valid moniker
        description.moniker = "Test";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit DescriptionEdited(validator);
        stakeHub.editDescription(description);
        StakeHub.Description memory realDesc = stakeHub.getValidatorDescription(validator);
        assertEq(realDesc.moniker, "Test");

        // 5. edit vote address
        vm.warp(block.timestamp + 1 days);
        bytes memory newVoteAddress =
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001234";
        bytes memory blsProof = new bytes(96);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit VoteAddressEdited(validator, newVoteAddress);
        stakeHub.editVoteAddress(newVoteAddress, blsProof);
        (,,, bytes memory realVoteAddr,,) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(realVoteAddr, newVoteAddress);

        vm.stopPrank();
    }

    function testDelegate() public {
        address delegator = _getNextUserAddress();
        (address validator, address credit) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        // failed with too small delegation amount
        vm.expectRevert();
        stakeHub.delegate{ value: 1 }(validator, false);

        // success case
        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, bnbAmount);

        vm.stopPrank();
    }

    function testUndelegate() public {
        address delegator = _getNextUserAddress();
        (address validator, address credit) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);

        // failed with not enough shares
        vm.expectRevert();
        stakeHub.undelegate(validator, shares + 1);

        // success case
        stakeHub.undelegate(validator, shares / 2);

        // claim failed
        vm.expectRevert();
        stakeHub.claim(validator, 0);

        // claim success
        vm.warp(block.timestamp + 7 days);
        uint256 balanceBefore = delegator.balance;
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit Claimed(validator, delegator, bnbAmount / 2);
        stakeHub.claim(validator, 0);
        uint256 balanceAfter = delegator.balance;
        assertEq(balanceAfter - balanceBefore, bnbAmount / 2);

        vm.stopPrank();
    }

    function testUndelegateAll() public {
        uint256 selfDelegation = 2000 ether;
        uint256 toLock = stakeHub.LOCK_AMOUNT();
        (address validator, address credit) = _createValidator(selfDelegation);
        uint256 _totalShares = IStakeCredit(credit).totalSupply();
        assertEq(_totalShares, selfDelegation + toLock, "wrong total shares");
        uint256 _totalPooledBNB = IStakeCredit(credit).totalPooledBNB();
        assertEq(_totalPooledBNB, selfDelegation + toLock, "wrong total pooled BNB");

        vm.startPrank(validator);

        // 1. undelegate all
        stakeHub.undelegate(validator, selfDelegation);
        _totalShares = IStakeCredit(credit).totalSupply();
        assertEq(_totalShares, toLock, "wrong total shares");
        _totalPooledBNB = IStakeCredit(credit).totalPooledBNB();
        assertEq(_totalPooledBNB, toLock, "wrong total pooled BNB");

        // 2. delegate again
        stakeHub.delegate{ value: selfDelegation }(validator, false);
        _totalShares = IStakeCredit(credit).totalSupply();
        assertEq(_totalShares, selfDelegation + toLock, "wrong total shares");
        _totalPooledBNB = IStakeCredit(credit).totalPooledBNB();
        assertEq(_totalPooledBNB, selfDelegation + toLock, "wrong total pooled BNB");

        vm.stopPrank();
    }

    function testRedelegate() public {
        address delegator = _getNextUserAddress();
        (address validator1, address credit1) = _createValidator(2000 ether);
        (address validator2, address credit2) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator1, false);
        uint256 oldShares = IStakeCredit(credit1).balanceOf(delegator);

        // failed with too small redelegation amount
        vm.expectRevert();
        stakeHub.redelegate(validator1, validator2, 1, false);

        // failed with not enough shares
        vm.expectRevert();
        stakeHub.redelegate(validator1, validator2, oldShares + 1, false);

        // success case
        uint256 redelegateFeeRate = stakeHub.redelegateFeeRate();
        uint256 feeBase = stakeHub.REDELEGATE_FEE_RATE_BASE();
        uint256 redelegateFee = bnbAmount * redelegateFeeRate / feeBase;
        uint256 expectedShares = (bnbAmount - redelegateFee) * IStakeCredit(credit2).totalSupply()
            / (IStakeCredit(credit2).totalPooledBNB() + redelegateFee);
        stakeHub.redelegate(validator1, validator2, oldShares, false);
        uint256 newShares = IStakeCredit(credit2).balanceOf(delegator);
        assertEq(newShares, expectedShares);

        vm.stopPrank();

        // self redelegate
        vm.startPrank(validator1);
        uint256 selfDelegation = 2000 ether;
        vm.expectRevert();
        stakeHub.redelegate(validator1, validator2, selfDelegation, false);
    }

    function testReceiveBNB() public {
        // send to stakeHub directly
        (bool success,) = address(stakeHub).call{ value: 1 ether }("");
        assertTrue(!success);
        (success,) = address(stakeHub).call{ value: 1 ether }(hex"12");
        assertTrue(!success);

        // send to credit contract directly
        (, address credit) = _createValidator(2000 ether);
        (success,) = credit.call{ value: 1 ether }("");
        assertTrue(!success);
        (success,) = credit.call{ value: 1 ether }(hex"12");
        assertTrue(!success);

        // send to credit contract by stakeHub
        vm.deal(address(stakeHub), 1 ether);
        vm.prank(address(stakeHub));
        (success,) = credit.call{ value: 1 ether }("");
        assertTrue(success);
    }

    function testDistributeReward() public {
        address delegator = _getNextUserAddress();
        uint256 selfDelegation = 2000 ether;
        (address validator, address credit) = _createValidator(selfDelegation);

        // 1. delegate 100 BNB and get 100 * 1e18 shares
        uint256 delegation = 100 ether;
        vm.prank(delegator);
        stakeHub.delegate{ value: delegation }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, delegation);

        // 2. distribute reward
        uint256 reward = 100 ether;
        (address consensusAddress,,,,,) = stakeHub.getValidatorBasicInfo(validator);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit RewardDistributed(validator, reward);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{ value: reward }(consensusAddress);

        // 3. check shares
        // reward: 100 ether
        // commissionToValidator: reward(100 ether) * commissionRate(10/10000) = 0.1 ether
        // preTotalPooledBNB: locked amount(1 ether) + selfDelegation(2000 ether) + delegation(100 ether) + (reward - commissionToValidator)(99.9 ether) = 2200.9 ether
        // preTotalShares: locked shares(1 ether) + selfDelegation(2000 ether) + delegation(100 ether)
        // curTotalShares: preTotalShares + commissionToValidator * preTotalShares  / preTotalPooledBNB = 2101095460947794084238
        // curTotalPooledBNB: preTotalPooledBNB + commissionToValidator = 2201 ether
        // expectedBnbAmount: shares(100 ether) * curTotalPooledBNB / curTotalShares
        uint256 _totalShares = IStakeCredit(credit).totalSupply();
        assertEq(_totalShares, 2101095460947794084238, "wrong total shares");
        uint256 expectedBnbAmount = shares * 2201 ether / uint256(2101095460947794084238);
        uint256 realBnbAmount = IStakeCredit(credit).getPooledBNBByShares(shares);
        assertEq(realBnbAmount, expectedBnbAmount, "wrong BNB amount");

        // 4. undelegate and submit new delegate
        vm.prank(delegator);
        stakeHub.undelegate(validator, shares);

        // totalShares: 2101095460947794084238 - 100 ether = 2001095460947794084238
        // totalPooledBNB: 2201 ether - (100 ether + 99.9 ether * 100 / 2101 ) = 2096245121370775821038
        // newShares: 100 ether * totalShares / totalPooledBNB
        uint256 _totalPooledBNB = IStakeCredit(credit).totalPooledBNB();
        assertEq(_totalPooledBNB, 2096245121370775821038, "wrong total pooled BNB");
        uint256 expectedShares = 100 ether * uint256(2001095460947794084238) / uint256(2096245121370775821038);
        address newDelegator = _getNextUserAddress();
        vm.prank(newDelegator);
        stakeHub.delegate{ value: delegation }(validator, false);
        uint256 newShares = IStakeCredit(credit).balanceOf(newDelegator);
        assertEq(newShares, expectedShares, "wrong new shares");
    }

    function testDowntimeSlash() public {
        // totalShares: 2100095458884494749761
        // totalPooledBNB: 2200 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address credit) = _createValidator(selfDelegation);
        _createValidator(selfDelegation); // create 2 validator to avoid empty jail

        address delegator = _getNextUserAddress();
        vm.prank(delegator);
        stakeHub.delegate{ value: 100 ether }(validator, false);

        (address consensusAddress,,,,,) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{ value: reward }(consensusAddress);

        uint256 preDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));
        uint256 preValidatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(validator));

        vm.startPrank(SLASH_CONTRACT_ADDR);

        // downtime slash type: 1
        uint256 slashAmt = stakeHub.downtimeSlashAmount();
        uint256 slashTime = stakeHub.downtimeJailTime();
        vm.expectEmit(true, false, false, false, address(stakeHub));
        emit ValidatorSlashed(validator, block.timestamp + slashTime, slashAmt, 1);
        stakeHub.downtimeSlash(consensusAddress);
        uint256 curValidatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(validator));
        assertApproxEqAbs(preValidatorBnbAmount, curValidatorBnbAmount + slashAmt, 1); // there may be 1 delta due to the precision

        // check delegator's share
        uint256 curDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision

        // unjail
        (,,,, bool jailed,) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(jailed, true);
        vm.expectRevert();
        stakeHub.unjail(validator);
        vm.warp(block.timestamp + slashTime + 1);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorUnjailed(validator);
        stakeHub.unjail(validator);
        (,,,, jailed,) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(jailed, false);

        vm.stopPrank();
    }

    function testDoubleSignSlash() public {
        // totalShares: 2100095458884494749761
        // totalPooledBNB: 2200 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address credit) = _createValidator(selfDelegation);

        address delegator = _getNextUserAddress();
        vm.prank(delegator);
        stakeHub.delegate{ value: 100 ether }(validator, false);

        (address consensusAddress,,,,,) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{ value: reward }(consensusAddress);

        uint256 preDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));

        vm.startPrank(SLASH_CONTRACT_ADDR);

        // double sign slash type: 0
        vm.expectEmit(true, false, false, false, address(stakeHub)); // as slash amount may vary by 1, we don't check the event data
        emit ValidatorSlashed(validator, 0, 0, 0);
        stakeHub.doubleSignSlash(consensusAddress);

        // check delegator's share
        uint256 curDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision
    }

    function testMaliciousVoteSlash() public {
        // totalShares: 2100095458884494749761
        // totalPooledBNB: 2200 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address credit) = _createValidator(selfDelegation);

        address delegator = _getNextUserAddress();
        vm.prank(delegator);
        stakeHub.delegate{ value: 100 ether }(validator, false);

        (address consensusAddress,,, bytes memory voteAddr,,) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{ value: reward }(consensusAddress);

        uint256 preDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));

        vm.startPrank(SLASH_CONTRACT_ADDR);

        // malicious vote slash type: 2
        vm.expectEmit(true, false, false, false, address(stakeHub)); // as slash amount may vary by 1, we don't check the event data
        emit ValidatorSlashed(validator, 0, 0, 2);
        stakeHub.maliciousVoteSlash(voteAddr);

        // check delegator's share
        uint256 curDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision
    }

    function testUpdateValidatorSetTransitionStage() public {
        // open staking channel
        if (!crossChain.registeredContractChannelMap(VALIDATOR_CONTRACT_ADDR, STAKING_CHANNELID)) {
            bytes memory key = "enableOrDisableChannel";
            bytes memory value = bytes(hex"0801");
            _updateParamByGovHub(key, value, address(crossChain));
            assertTrue(crossChain.registeredContractChannelMap(VALIDATOR_CONTRACT_ADDR, STAKING_CHANNELID));
        }

        uint256 length = stakeHub.maxElectedValidators();
        address[] memory newConsensusAddrs = new address[](length);
        uint64[] memory newVotingPower = new uint64[](length);
        bytes[] memory newVoteAddrs = new bytes[](length);
        address operatorAddress;
        address consensusAddress;
        uint64 votingPower;
        bytes memory voteAddress;
        for (uint256 i; i < length; ++i) {
            votingPower = (2000 + uint64(i) * 2 + 1) * 1e8;
            (operatorAddress,) = _createValidator(uint256(votingPower) * 1e10);
            (consensusAddress,,, voteAddress,,) = stakeHub.getValidatorBasicInfo(operatorAddress);
            newConsensusAddrs[length - i - 1] = consensusAddress;
            newVotingPower[length - i - 1] = votingPower;
            newVoteAddrs[length - i - 1] = voteAddress;
        }
        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        bscValidatorSet.updateValidatorSetV2(newConsensusAddrs, newVotingPower, newVoteAddrs);

        for (uint256 i; i < length; ++i) {
            votingPower = (2000 + uint64(i) * 2) * 1e8;
            newConsensusAddrs[length - i - 1] = _getNextUserAddress();
            newVotingPower[length - i - 1] = votingPower;
            newVoteAddrs[length - i - 1] = bytes(vm.toString(newConsensusAddrs[i]));
        }
        vm.prank(address(crossChain));
        bscValidatorSet.handleSynPackage(
            STAKING_CHANNELID, _encodeValidatorSetUpdatePack(newConsensusAddrs, newVotingPower, newVoteAddrs)
        );

        (,,, uint64 preVotingPower,,) = bscValidatorSet.currentValidatorSet(0);
        uint64 curVotingPower;
        for (uint256 i = 1; i < length; ++i) {
            (,,, curVotingPower,,) = bscValidatorSet.currentValidatorSet(i);
            assert(curVotingPower <= preVotingPower);
            preVotingPower = curVotingPower;
        }
    }

    function testUpdateValidatorSetV2() public {
        // close staking channel
        if (crossChain.registeredContractChannelMap(VALIDATOR_CONTRACT_ADDR, STAKING_CHANNELID)) {
            bytes memory key = "enableOrDisableChannel";
            bytes memory value = bytes(hex"0800");
            _updateParamByGovHub(key, value, address(crossChain));
            assertFalse(crossChain.registeredContractChannelMap(VALIDATOR_CONTRACT_ADDR, STAKING_CHANNELID));
        }

        uint256 length = stakeHub.maxElectedValidators();
        address[] memory newConsensusAddrs = new address[](length);
        uint64[] memory newVotingPower = new uint64[](length);
        bytes[] memory newVoteAddrs = new bytes[](length);
        address operatorAddress;
        address consensusAddress;
        uint64 votingPower;
        bytes memory voteAddress;
        for (uint256 i; i < length; ++i) {
            votingPower = (2000 + uint64(i) * 2 + 1) * 1e8;
            (operatorAddress,) = _createValidator(uint256(votingPower) * 1e10);
            (consensusAddress,,, voteAddress,,) = stakeHub.getValidatorBasicInfo(operatorAddress);
            newConsensusAddrs[length - i - 1] = consensusAddress;
            newVotingPower[length - i - 1] = votingPower;
            newVoteAddrs[length - i - 1] = voteAddress;
        }
        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        bscValidatorSet.updateValidatorSetV2(newConsensusAddrs, newVotingPower, newVoteAddrs);
    }

    function testEncodeLegacyBytes() public {
        address[] memory cAddresses = new address[](3);
        bytes[] memory vAddresses = new bytes[](3);

        cAddresses[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        cAddresses[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        cAddresses[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

        vAddresses[0] =
            hex"b86b3146bdd2200b1dbdb1cea5e40d3451c028cbb4fb03b1826f7f2d82bee76bbd5cd68a74a16a7eceea093fd5826b92";
        vAddresses[1] =
            hex"87ce273bb9b51fd69e50de7a8d9a99cfb3b1a5c6a7b85f6673d137a5a2ce7df3d6ee4e6d579a142d58b0606c4a7a1c27";
        vAddresses[2] =
            hex"a33ac14980d85c0d154c5909ebf7a11d455f54beb4d5d0dc1d8b3670b9c4a6b6c450ee3d623ecc48026f09ed1f0b5c12";

        bytes memory cBz = abi.encode(cAddresses);
        bytes memory vBz = abi.encode(vAddresses);
        emit log_named_bytes("consensus address bytes", cBz);
        emit log_named_bytes("vote address bytes", vBz);
    }

    function _createValidator(uint256 delegation) internal returns (address operatorAddress, address credit) {
        operatorAddress = _getNextUserAddress();
        StakeHub.Commission memory commission = StakeHub.Commission({ rate: 10, maxRate: 100, maxChangeRate: 5 });
        StakeHub.Description memory description = StakeHub.Description({
            moniker: string.concat("T", vm.toString(uint24(uint160(operatorAddress)))),
            identity: vm.toString(operatorAddress),
            website: vm.toString(operatorAddress),
            details: vm.toString(operatorAddress)
        });
        bytes memory blsPubKey = bytes.concat(
            hex"00000000000000000000000000000000000000000000000000000000", abi.encodePacked(operatorAddress)
        );
        bytes memory blsProof = new bytes(96);
        address consensusAddress = address(uint160(uint256(keccak256(blsPubKey))));

        uint256 toLock = stakeHub.LOCK_AMOUNT();
        vm.prank(operatorAddress);
        stakeHub.createValidator{ value: delegation + toLock }(
            consensusAddress, blsPubKey, blsProof, commission, description
        );

        (, credit,,,,) = stakeHub.getValidatorBasicInfo(operatorAddress);
    }

    function _encodeValidatorSetUpdatePack(
        address[] memory valSet,
        uint64[] memory votingPowers,
        bytes[] memory voteAddrs
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = uint8(0).encodeUint();

        bytes[] memory vals = new bytes[](valSet.length);
        for (uint256 i; i < valSet.length; ++i) {
            bytes[] memory tmp = new bytes[](5);
            tmp[0] = valSet[i].encodeAddress();
            tmp[1] = valSet[i].encodeAddress();
            tmp[2] = valSet[i].encodeAddress();
            tmp[3] = votingPowers[i].encodeUint();
            tmp[4] = voteAddrs[i].encodeBytes();
            vals[i] = tmp.encodeList();
        }

        elements[1] = vals.encodeList();
        return elements.encodeList();
    }
}
