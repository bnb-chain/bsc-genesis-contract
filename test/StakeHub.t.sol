pragma solidity ^0.8.10;

import "forge-std/console.sol";
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

    // Add NodeID related events and errors
    event NodeIDAdded(address indexed validator, bytes32 nodeID);
    event NodeIDRemoved(address indexed validator, bytes32 nodeID);
    
    error ExceedsMaxNodeIDs();
    error DuplicateNodeID();
    error InvalidNodeID();

    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event DescriptionEdited(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event ValidatorSlashed(address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, uint8 slashType);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event MigrateSuccess(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event MigrateFailed(
        address indexed operatorAddress, address indexed delegator, uint256 bnbAmount, StakeMigrationRespCode respCode
    );
    event AgentChanged(address indexed operatorAddress, address indexed oldAgent, address indexed newAgent);

    enum StakeMigrationRespCode {
        MIGRATE_SUCCESS,
        CLAIM_FUND_FAILED,
        VALIDATOR_NOT_EXISTED,
        VALIDATOR_JAILED
    }

    receive() external payable { }

    function setUp() public {
        vm.mockCall(address(0x66), "", hex"01");
    }

    function testCreateValidator() public {
        // create validator success
        (address validator,,,) = _createValidator(2000 ether);
        address consensusAddress = stakeHub.getValidatorConsensusAddress(validator);
        bytes memory voteAddress = stakeHub.getValidatorVoteAddress(validator);

        address operatorAddress = _getNextUserAddress();
        vm.startPrank(operatorAddress);

        // create failed with duplicate consensus address
        uint256 delegation = 2000 ether;
        uint256 toLock = stakeHub.LOCK_AMOUNT();
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

        vm.expectRevert(StakeHub.DuplicateConsensusAddress.selector);
        stakeHub.createValidator{ value: delegation + toLock }(
            consensusAddress, blsPubKey, blsProof, commission, description
        );

        // create failed with duplicate vote address
        consensusAddress = address(uint160(uint256(keccak256(blsPubKey))));
        vm.expectRevert(StakeHub.DuplicateVoteAddress.selector);
        stakeHub.createValidator{ value: delegation + toLock }(
            consensusAddress, voteAddress, blsProof, commission, description
        );

        // create failed with duplicate moniker
        description = stakeHub.getValidatorDescription(validator);
        vm.expectRevert(StakeHub.DuplicateMoniker.selector);
        stakeHub.createValidator{ value: delegation + toLock }(
            consensusAddress, blsPubKey, blsProof, commission, description
        );
    }

    function testEditValidator() public {
        // create validator
        (address validator,,,) = _createValidator(2000 ether);
        vm.startPrank(validator);

        // edit failed because of `UpdateTooFrequently`
        vm.expectRevert(StakeHub.UpdateTooFrequently.selector);
        stakeHub.editConsensusAddress(address(1));

        // edit consensus address
        vm.warp(block.timestamp + 1 days);
        address newConsensusAddress = address(0x1234);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit ConsensusAddressEdited(validator, newConsensusAddress);
        stakeHub.editConsensusAddress(newConsensusAddress);
        address realConsensusAddr = stakeHub.getValidatorConsensusAddress(validator);
        assertEq(realConsensusAddr, newConsensusAddress);

        // edit commission rate
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(StakeHub.InvalidCommission.selector);
        stakeHub.editCommissionRate(110);
        vm.expectRevert(StakeHub.InvalidCommission.selector);
        stakeHub.editCommissionRate(16);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit CommissionRateEdited(validator, 15);
        stakeHub.editCommissionRate(15);
        StakeHub.Commission memory realComm = stakeHub.getValidatorCommission(validator);
        assertEq(realComm.rate, 15);

        // edit description
        vm.warp(block.timestamp + 1 days);
        StakeHub.Description memory description = stakeHub.getValidatorDescription(validator);
        description.moniker = "Test";
        description.website = "Test";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit DescriptionEdited(validator);
        stakeHub.editDescription(description);
        StakeHub.Description memory realDesc = stakeHub.getValidatorDescription(validator);
        assertNotEq(realDesc.moniker, "Test"); // edit moniker will be ignored
        assertEq(realDesc.website, "Test");

        // edit vote address
        vm.warp(block.timestamp + 1 days);
        bytes memory newVoteAddress =
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001234";
        bytes memory blsProof = new bytes(96);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit VoteAddressEdited(validator, newVoteAddress);
        stakeHub.editVoteAddress(newVoteAddress, blsProof);
        bytes memory realVoteAddr = stakeHub.getValidatorVoteAddress(validator);
        assertEq(realVoteAddr, newVoteAddress);

        vm.stopPrank();
    }

    function testDelegate() public {
        address delegator = _getNextUserAddress();
        (address validator,, address credit,) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        // failed with too small delegation amount
        vm.expectRevert(StakeHub.DelegationAmountTooSmall.selector);
        stakeHub.delegate{ value: 1 }(validator, false);

        // success case
        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, bnbAmount);
        uint256 pooledBNB = IStakeCredit(credit).getPooledBNBByShares(shares);
        assertEq(pooledBNB, bnbAmount);

        vm.stopPrank();
    }

    function testUndelegate() public {
        address delegator = _getNextUserAddress();
        (address validator,, address credit,) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);

        // failed with not enough shares
        vm.expectRevert(StakeCredit.InsufficientBalance.selector);
        stakeHub.undelegate(validator, shares + 1);

        // success case
        stakeHub.undelegate(validator, shares / 2);

        // claim failed
        vm.expectRevert(StakeCredit.NoClaimableUnbondRequest.selector);
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
        (address validator,, address credit,) = _createValidator(selfDelegation);
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
        (address validator1,, address credit1,) = _createValidator(2000 ether);
        (address validator2,, address credit2,) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator1, false);
        uint256 oldShares = IStakeCredit(credit1).balanceOf(delegator);

        // failed with too small redelegation amount
        vm.expectRevert(StakeHub.DelegationAmountTooSmall.selector);
        stakeHub.redelegate(validator1, validator2, 1, false);

        // failed with not enough shares
        vm.expectRevert(StakeCredit.InsufficientBalance.selector);
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

        // self redelegate failed because of `SelfDelegationNotEnough`
        uint256 selfDelegation = 2000 ether;
        vm.expectRevert(StakeHub.SelfDelegationNotEnough.selector);
        vm.prank(validator1);
        stakeHub.redelegate(validator1, validator2, selfDelegation, false);
    }

    function testReceiveBNB() public {
        // send to stakeHub directly
        (bool success,) = address(stakeHub).call{ value: 1 ether }("");
        assertTrue(!success);
        (success,) = address(stakeHub).call{ value: 1 ether }(hex"12");
        assertTrue(!success);

        // send to credit contract directly
        (,, address credit,) = _createValidator(2000 ether);
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
        (address validator,, address credit,) = _createValidator(selfDelegation);

        // 1. delegate 100 BNB and get 100 * 1e18 shares
        uint256 delegation = 100 ether;
        vm.prank(delegator);
        stakeHub.delegate{ value: delegation }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, delegation);

        // 2. distribute reward
        uint256 reward = 100 ether;
        address consensusAddress = stakeHub.getValidatorConsensusAddress(validator);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit RewardDistributed(validator, reward);
        vm.deal(VALIDATOR_CONTRACT_ADDR, VALIDATOR_CONTRACT_ADDR.balance + reward);
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
        (address validator,, address credit,) = _createValidator(selfDelegation);
        _createValidator(selfDelegation); // create 2 validator to avoid empty jail

        address delegator = _getNextUserAddress();
        vm.prank(delegator);
        stakeHub.delegate{ value: 100 ether }(validator, false);

        address consensusAddress = stakeHub.getValidatorConsensusAddress(validator);
        vm.deal(VALIDATOR_CONTRACT_ADDR, VALIDATOR_CONTRACT_ADDR.balance + reward);
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
        (, bool jailed,) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(jailed, true);
        vm.expectRevert();
        stakeHub.unjail(validator);
        vm.warp(block.timestamp + slashTime + 1);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorUnjailed(validator);
        stakeHub.unjail(validator);
        (, jailed,) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(jailed, false);

        vm.stopPrank();
    }

    function testDoubleSignSlash() public {
        // totalShares: 2100095458884494749761
        // totalPooledBNB: 2200 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator,, address credit,) = _createValidator(selfDelegation);

        address delegator = _getNextUserAddress();
        vm.prank(delegator);
        stakeHub.delegate{ value: 100 ether }(validator, false);

        address consensusAddress = stakeHub.getValidatorConsensusAddress(validator);
        vm.deal(VALIDATOR_CONTRACT_ADDR, VALIDATOR_CONTRACT_ADDR.balance + reward);
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
        (address validator,, address credit,) = _createValidator(selfDelegation);

        address delegator = _getNextUserAddress();
        vm.prank(delegator);
        stakeHub.delegate{ value: 100 ether }(validator, false);

        address consensusAddress = stakeHub.getValidatorConsensusAddress(validator);
        bytes memory voteAddr = stakeHub.getValidatorVoteAddress(validator);
        vm.deal(VALIDATOR_CONTRACT_ADDR, VALIDATOR_CONTRACT_ADDR.balance + reward);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{ value: reward }(consensusAddress);

        uint256 preDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));

        // malicious vote slash type: 2
        vm.expectEmit(true, false, false, false, address(stakeHub)); // as slash amount may vary by 1, we don't check the event data
        emit ValidatorSlashed(validator, 0, 0, 2);
        vm.prank(SLASH_CONTRACT_ADDR);
        stakeHub.maliciousVoteSlash(voteAddr);

        // check delegator's share
        uint256 curDelegatorBnbAmount =
            IStakeCredit(credit).getPooledBNBByShares(IStakeCredit(credit).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision
    }

    function testUpdateValidatorSetV2() public {
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
            (operatorAddress,,,) = _createValidator(uint256(votingPower) * 1e10);
            consensusAddress = stakeHub.getValidatorConsensusAddress(operatorAddress);
            voteAddress = stakeHub.getValidatorVoteAddress(operatorAddress);
            newConsensusAddrs[length - i - 1] = consensusAddress;
            newVotingPower[length - i - 1] = votingPower;
            newVoteAddrs[length - i - 1] = voteAddress;
        }
        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        bscValidatorSet.updateValidatorSetV2(newConsensusAddrs, newVotingPower, newVoteAddrs);
    }

    function testEncodeLegacyBytes() public {
        address[] memory cAddresses = new address[](56);
        bytes[] memory vAddresses = new bytes[](34);

        cAddresses[0] = 0x295e26495CEF6F69dFA69911d9D8e4F3bBadB89B;
        cAddresses[1] = 0x72b61c6014342d914470eC7aC2975bE345796c2b;
        cAddresses[2] = 0x2465176C461AfB316ebc773C61fAEe85A6515DAA;
        cAddresses[3] = 0x7AE2F5B9e386cd1B50A4550696D957cB4900f03a;
        cAddresses[4] = 0xb4dd66D7c2C7E57F628210187192fb89d4b99dD4;
        cAddresses[5] = 0xE9AE3261a475a27Bb1028f140bc2a7c843318afD;
        cAddresses[6] = 0xee226379dB83CfFC681495730c11fDDE79BA4c0C;
        cAddresses[7] = 0x3f349bBaFEc1551819B8be1EfEA2fC46cA749aA1;
        cAddresses[8] = 0x8b6C8fd93d6F4CeA42Bbb345DBc6F0DFdb5bEc73;
        cAddresses[9] = 0xEF0274E31810C9Df02F98FAFDe0f841F4E66a1Cd;
        cAddresses[10] = 0xa6f79B60359f141df90A0C745125B131cAAfFD12;
        cAddresses[11] = 0xe2d3A739EFFCd3A99387d015E260eEFAc72EBea1;
        cAddresses[12] = 0x61Dd481A114A2E761c554B641742C973867899D3;
        cAddresses[13] = 0xCc8E6d00C17eB431350C6c50d8b8F05176b90b11;
        cAddresses[14] = 0xea0A6E3c511bbD10f4519EcE37Dc24887e11b55d;
        cAddresses[15] = 0x2D4C407BBe49438ED859fe965b140dcF1aaB71a9;
        cAddresses[16] = 0x685B1ded8013785d6623CC18D214320b6Bb64759;
        cAddresses[17] = 0xD1d6bF74282782B0b3eb1413c901D6eCF02e8e28;
        cAddresses[18] = 0x70F657164e5b75689b64B7fd1fA275F334f28e18;
        cAddresses[19] = 0xBe807Dddb074639cD9fA61b47676c064fc50D62C;
        cAddresses[20] = 0xb218C5D6aF1F979aC42BC68d98A5A0D796C6aB01;
        cAddresses[21] = 0x9F8cCdaFCc39F3c7D6EBf637c9151673CBc36b88;
        cAddresses[22] = 0xd93DbfB27e027F5e9e6Da52B9E1C413CE35ADC11;
        cAddresses[23] = 0xce2FD7544e0B2Cc94692d4A704deBEf7bcB61328;
        cAddresses[24] = 0x0BAC492386862aD3dF4B666Bc096b0505BB694Da;
        cAddresses[25] = 0x733fdA7714a05960B7536330Be4DBB135bef0Ed6;
        cAddresses[26] = 0x35EBb5849518aFF370cA25E19e1072cC1a9FAbCa;
        cAddresses[27] = 0xeBE0B55aD7Bb78309180Cada12427d120fdBcc3a;
        cAddresses[28] = 0x6488Aa4D1955Ee33403f8ccB1d4dE5Fb97C7ade2;
        cAddresses[29] = 0x4396e28197653d0C244D95f8C1E57da902A72b4e;
        cAddresses[30] = 0x702Be18040aA2a9b1af9219941469f1a435854fC;
        cAddresses[31] = 0x12D810C13e42811E9907c02e02d1faD46cfA18BA;
        cAddresses[32] = 0x2a7cdd959bFe8D9487B2a43B33565295a698F7e2;
        cAddresses[33] = 0xB8f7166496996A7da21cF1f1b04d9B3E26a3d077;
        cAddresses[34] = 0x9bB832254BAf4E8B4cc26bD2B52B31389B56E98B;
        cAddresses[35] = 0x4430b3230294D12c6AB2aAC5C2cd68E80B16b581;
        cAddresses[36] = 0xc2Be4EC20253B8642161bC3f444F53679c1F3D47;
        cAddresses[37] = 0xEe01C3b1283AA067C58eaB4709F85e99D46de5FE;
        cAddresses[38] = 0x9ef9f4360c606c7AB4db26b016007d3ad0aB86a0;
        cAddresses[39] = 0x2f7bE8361C80A4c1e7e9aAF001d0877F1CFdE218;
        cAddresses[40] = 0x35E7a025f4da968De7e4D7E4004197917F4070F1;
        cAddresses[41] = 0xd6caA02BBebaEbB5d7e581e4B66559e635F805fF;
        cAddresses[42] = 0x8c4D90829CE8F72D0163c1D5Cf348a862d550630;
        cAddresses[43] = 0x68Bf0B8b6FB4E317a0f9D6F03eAF8CE6675BC60D;
        cAddresses[44] = 0x82012708DAfC9E1B880fd083B32182B869bE8E09;
        cAddresses[45] = 0x6BBad7Cf34b5fA511d8e963dbba288B1960E75D6;
        cAddresses[46] = 0x22B81f8E175FFde54d797FE11eB03F9E3BF75F1d;
        cAddresses[47] = 0x78f3aDfC719C99674c072166708589033e2d9afe;
        cAddresses[48] = 0x29a97C6EfFB8A411DABc6aDEEfaa84f5067C8bbe;
        cAddresses[49] = 0xAAcF6a8119F7e11623b5A43DA638e91F669A130f;
        cAddresses[50] = 0x2b3A6c089311b478Bf629C29D790A7A6db3fc1b9;
        cAddresses[51] = 0xFE6E72b223f6d6Cf4edc6bFf92f30e84b8258249;
        cAddresses[52] = 0xa6503279E8B5c7Bb5CF4deFD3ec8ABf3e009a80b;
        cAddresses[53] = 0x4ee63a09170C3f2207aeCa56134Fc2Bee1b28e3C;
        cAddresses[54] = 0xac0E15a038eedfc68ba3C35c73feD5bE4A07afB5;
        cAddresses[55] = 0x69C77a677C40C7FBeA129d4b171a39B7A8DDaBfA;

        vAddresses[0] =
            hex"977cf58294f7239d515e15b24cfeb82494056cf691eaf729b165f32c9757c429dba5051155903067e56ebe3698678e91";
        vAddresses[1] =
            hex"81db0422a5fd08e40db1fc2368d2245e4b18b1d0b85c921aaaafd2e341760e29fc613edd39f71254614e2055c3287a51";
        vAddresses[2] =
            hex"8a923564c6ffd37fb2fe9f118ef88092e8762c7addb526ab7eb1e772baef85181f892c731be0c1891a50e6b06262c816";
        vAddresses[3] =
            hex"b84f83ff2df44193496793b847f64e9d6db1b3953682bb95edd096eb1e69bbd357c200992ca78050d0cbe180cfaa018e";
        vAddresses[4] =
            hex"b0de8472be0308918c8bdb369bf5a67525210daffa053c52224c1d2ef4f5b38e4ecfcd06a1cc51c39c3a7dccfcb6b507";
        vAddresses[5] =
            hex"ae7bc6faa3f0cc3e6093b633fd7ee4f86970926958d0b7ec80437f936acf212b78f0cd095f4565fff144fd458d233a5b";
        vAddresses[6] =
            hex"84248a459464eec1a21e7fc7b71a053d9644e9bb8da4853b8f872cd7c1d6b324bf1922829830646ceadfb658d3de009a";
        vAddresses[7] =
            hex"a8a257074e82b881cfa06ef3eb4efeca060c2531359abd0eab8af1e3edfa2025fca464ac9c3fd123f6c24a0d78869485";
        vAddresses[8] =
            hex"98cbf822e4bc29f1701ac0350a3d042cd0756e9f74822c6481773ceb000641c51b870a996fe0f6a844510b1061f38cd0";
        vAddresses[9] =
            hex"b772e180fbf38a051c97dabc8aaa0126a233a9e828cdafcc7422c4bb1f4030a56ba364c54103f26bad91508b5220b741";
        vAddresses[10] =
            hex"956c470ddff48cb49300200b5f83497f3a3ccb3aeb83c5edd9818569038e61d197184f4aa6939ea5e9911e3e98ac6d21";
        vAddresses[11] =
            hex"8a80967d39e406a0a9642d41e9007a27fc1150a267d143a9f786cd2b5eecbdcc4036273705225b956d5e2f8f5eb95d25";
        vAddresses[12] =
            hex"b3a3d4feb825ae9702711566df5dbf38e82add4dd1b573b95d2466fa6501ccb81e9d26a352b96150ccbf7b697fd0a419";
        vAddresses[13] =
            hex"b2d4c6283c44a1c7bd503aaba7666e9f0c830e0ff016c1c750a5e48757a713d0836b1cabfd5c281b1de3b77d1c192183";
        vAddresses[14] =
            hex"93c1f7f6929d1fe2a17b4e14614ef9fc5bdc713d6631d675403fbeefac55611bf612700b1b65f4744861b80b0f7d6ab0";
        vAddresses[15] =
            hex"8a60f82a7bcf74b4cb053b9bfe83d0ed02a84ebb10865dfdd8e26e7535c43a1cccd268e860f502216b379dfc9971d358";
        vAddresses[16] =
            hex"939e8fb41b682372335be8070199ad3e8621d1743bcac4cc9d8f0f6e10f41e56461385c8eb5daac804fe3f2bca6ce739";
        vAddresses[17] =
            hex"96a26afa1295da81418593bd12814463d9f6e45c36a0e47eb4cd3e5b6af29c41e2a3a5636430155a466e216585af3ba7";
        vAddresses[18] =
            hex"b1f2c71577def3144fabeb75a8a1c8cb5b51d1d1b4a05eec67988b8685008baa17459ec425dbaebc852f496dc92196cd";
        vAddresses[19] =
            hex"b659ad0fbd9f515893fdd740b29ba0772dbde9b4635921dd91bd2963a0fc855e31f6338f45b211c4e9dedb7f2eb09de7";
        vAddresses[20] =
            hex"8819ec5ec3e97e1f03bbb4bb6055c7a5feac8f4f259df58349a32bb5cb377e2cb1f362b77f1dd398cfd3e9dba46138c3";
        vAddresses[21] =
            hex"b313f9cba57c63a84edb4079140e6dbd7829e5023c9532fce57e9fe602400a2953f4bf7dab66cca16e97be95d4de7044";
        vAddresses[22] =
            hex"b64abe25614c9cfd32e456b4d521f29c8357f4af4606978296c9be93494072ac05fa86e3d27cc8d66e65000f8ba33fbb";
        vAddresses[23] =
            hex"b0bec348681af766751cb839576e9c515a09c8bffa30a46296ccc56612490eb480d03bf948e10005bbcc0421f90b3d4e";
        vAddresses[24] =
            hex"b0245c33bc556cfeb013cd3643b30dbdef6df61a0be3ba00cae104b3c587083852e28f8911689c7033f7021a8a1774c9";
        vAddresses[25] =
            hex"a7f3e2c0b4b16ad183c473bafe30a36e39fa4a143657e229cd23c77f8fbc8e4e4e241695dd3d248d1e51521eee661914";
        vAddresses[26] =
            hex"8fdf49777b22f927d460fa3fcdd7f2ba0cf200634a3dfb5197d7359f2f88aaf496ef8c93a065de0f376d164ff2b6db9a";
        vAddresses[27] =
            hex"8ab17a9148339ef40aed8c177379c4db0bb5efc6f5c57a5d1a6b58b84d4b562e227196c79bda9a136830ed0c09f37813";
        vAddresses[28] =
            hex"8dd20979bd63c14df617a6939c3a334798149151577dd3f1fadb2bd1c1b496bf84c25c879da5f0f9dfdb88c6dd17b1e6";
        vAddresses[29] =
            hex"b679cbab0276ac30ff5f198e5e1dedf6b84959129f70fe7a07fcdf13444ba45b5dbaa7b1f650adf8b0acbecd04e2675b";
        vAddresses[30] =
            hex"8974616fe8ab950a3cded19b1d16ff49c97bf5af65154b3b097d5523eb213f3d35fc5c57e7276c7f2d83be87ebfdcdf9";
        vAddresses[31] =
            hex"ab764a39ff81dad720d5691b852898041a3842e09ecbac8025812d51b32223d8420e6ae51a01582220a10f7722de67c1";
        vAddresses[32] =
            hex"9025b6715c8eaabac0bfccdb2f25d651c9b69b0a184011a4a486b0b2080319d2396e7ca337f2abdf01548b2de1b3ba06";
        vAddresses[33] =
            hex"b2317f59d86abfaf690850223d90e9e7593d91a29331dfc2f84d5adecc75fc39ecab4632c1b4400a3dd1e1298835bcca";

        bytes memory cBz = abi.encode(cAddresses);
        bytes memory vBz = abi.encode(vAddresses);
        emit log_named_bytes("consensus address bytes", cBz);
        emit log_named_bytes("vote address bytes", vBz);
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

    function testAgent() external {
        // create validator
        (address validator,,,) = _createValidator(2000 ether);
        vm.startPrank(validator);

        // edit failed because of `UpdateTooFrequently`
        vm.expectRevert(StakeHub.UpdateTooFrequently.selector);
        stakeHub.editConsensusAddress(address(1));

        // update agent
        address newAgent = validator;
        vm.expectRevert(StakeHub.InvalidAgent.selector);
        stakeHub.updateAgent(newAgent);

        newAgent = address(0x1234);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit AgentChanged(validator, address(0), newAgent);
        stakeHub.updateAgent(newAgent);

        vm.stopPrank();

        vm.startPrank(newAgent);
        // edit consensus address
        vm.warp(block.timestamp + 1 days);
        address newConsensusAddress = address(0x1234);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit ConsensusAddressEdited(validator, newConsensusAddress);
        stakeHub.editConsensusAddress(newConsensusAddress);
        address realConsensusAddr = stakeHub.getValidatorConsensusAddress(validator);
        assertEq(realConsensusAddr, newConsensusAddress);

        // edit commission rate
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(StakeHub.InvalidCommission.selector);
        stakeHub.editCommissionRate(110);
        vm.expectRevert(StakeHub.InvalidCommission.selector);
        stakeHub.editCommissionRate(16);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit CommissionRateEdited(validator, 15);
        stakeHub.editCommissionRate(15);
        StakeHub.Commission memory realComm = stakeHub.getValidatorCommission(validator);
        assertEq(realComm.rate, 15);

        // edit description
        vm.warp(block.timestamp + 1 days);
        StakeHub.Description memory description = stakeHub.getValidatorDescription(validator);
        description.moniker = "Test";
        description.website = "Test";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit DescriptionEdited(validator);
        stakeHub.editDescription(description);
        StakeHub.Description memory realDesc = stakeHub.getValidatorDescription(validator);
        assertNotEq(realDesc.moniker, "Test"); // edit moniker will be ignored
        assertEq(realDesc.website, "Test");

        // edit vote address
        vm.warp(block.timestamp + 1 days);
        bytes memory newVoteAddress =
            hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001234";
        bytes memory blsProof = new bytes(96);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit VoteAddressEdited(validator, newVoteAddress);
        stakeHub.editVoteAddress(newVoteAddress, blsProof);
        bytes memory realVoteAddr = stakeHub.getValidatorVoteAddress(validator);
        assertEq(realVoteAddr, newVoteAddress);

        vm.stopPrank();
    }

    function testGetNodeIDs() public {
         // Set maxNodeIDs through governance
         uint256 currentMaxNodeIDs = stakeHub.maxNodeIDs();
         if (currentMaxNodeIDs != 5) {
             vm.prank(GOV_HUB_ADDR);
             stakeHub.updateParam("maxNodeIDs", abi.encode(uint256(5)));
         }
 
         // Create two validators
         (address validator1,,,) = _createValidator(2000 ether);
         (address validator2,,,) = _createValidator(2000 ether);
 
         // Add NodeIDs to validator1
         bytes32[] memory nodeIDs1 = new bytes32[](2);
         nodeIDs1[0] = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
         nodeIDs1[1] = bytes32(0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890);
         vm.startPrank(validator1);
         stakeHub.addNodeIDs(nodeIDs1);
         vm.stopPrank();
 
         // Add NodeIDs to validator2
         bytes32[] memory nodeIDs2 = new bytes32[](2);
         nodeIDs2[0] = bytes32(0x1111111111111111111111111111111111111111111111111111111111111111);
         nodeIDs2[1] = bytes32(0x2222222222222222222222222222222222222222222222222222222222222222);
         vm.startPrank(validator2);
         stakeHub.addNodeIDs(nodeIDs2);
         vm.stopPrank();
 
         // Test getNodeIDs with both validators
         address[] memory validatorsToQuery = new address[](2);
         validatorsToQuery[0] = validator1;
         validatorsToQuery[1] = validator2;
 
         (address[] memory consensusAddresses, bytes32[][] memory result) = stakeHub.getNodeIDs(validatorsToQuery);
         assertEq(result.length, 2, "Should return results for both validators");
         assertEq(consensusAddresses.length, 2, "Should return consensus addresses for both validators");
         assertEq(result[0].length, 2, "Validator1 should have 2 NodeIDs");
         assertEq(result[1].length, 2, "Validator2 should have 2 NodeIDs");
         assertEq(result[0][0], nodeIDs1[0], "First NodeID of validator1 should match");
         assertEq(result[0][1], nodeIDs1[1], "Second NodeID of validator1 should match");
         assertEq(result[1][0], nodeIDs2[0], "First NodeID of validator2 should match");
         assertEq(result[1][1], nodeIDs2[1], "Second NodeID of validator2 should match");
     }

    function testRemoveNodeIDs() public {
        // Set maxNodeIDs through governance
        uint256 currentMaxNodeIDs = stakeHub.maxNodeIDs();
        if (currentMaxNodeIDs != 5) {
            vm.prank(GOV_HUB_ADDR);
            stakeHub.updateParam("maxNodeIDs", abi.encode(uint256(5)));
        }

        // Create a validator
        (address validator,,,) = _createValidator(2000 ether);

        // Add initial NodeIDs
        bytes32[] memory initialNodeIDs = new bytes32[](3);
        initialNodeIDs[0] = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        initialNodeIDs[1] = bytes32(0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890);
        initialNodeIDs[2] = bytes32(0x1111111111111111111111111111111111111111111111111111111111111111);
        vm.startPrank(validator);
        stakeHub.addNodeIDs(initialNodeIDs);

        // Remove some NodeIDs
        bytes32[] memory nodeIDsToRemove = new bytes32[](2);
        nodeIDsToRemove[0] = initialNodeIDs[0];
        nodeIDsToRemove[1] = initialNodeIDs[2];

        // Test event emissions
        vm.expectEmit(true, true, false, false);
        emit NodeIDRemoved(validator, initialNodeIDs[0]);
        vm.expectEmit(true, true, false, false);
        emit NodeIDRemoved(validator, initialNodeIDs[2]);

        stakeHub.removeNodeIDs(nodeIDsToRemove);

        // Verify the removal
        address[] memory validatorsToQuery = new address[](1);
        validatorsToQuery[0] = validator;
        (, bytes32[][] memory result) = stakeHub.getNodeIDs(validatorsToQuery);
        
        assertEq(result[0].length, 1, "Should have 1 remaining NodeID");
        assertEq(result[0][0], initialNodeIDs[1], "Remaining NodeID should match");

        // Test removing all NodeIDs
        bytes32[] memory removeAll = new bytes32[](0);
        vm.expectEmit(true, true, false, false);
        emit NodeIDRemoved(validator, initialNodeIDs[1]);
        stakeHub.removeNodeIDs(removeAll);

        // Verify all NodeIDs are removed
        (, result) = stakeHub.getNodeIDs(validatorsToQuery);
        assertEq(result[0].length, 0, "Should have no NodeIDs remaining");
    }

    function testAddNodeIDs() public {
        // Set maxNodeIDs through governance
        uint256 currentMaxNodeIDs = stakeHub.maxNodeIDs();
        if (currentMaxNodeIDs != 5) {
            vm.prank(GOV_HUB_ADDR);
            stakeHub.updateParam("maxNodeIDs", abi.encode(uint256(5)));
        }

        // Create a validator
        (address validator,,,) = _createValidator(2000 ether);

        // Add initial NodeIDs to reach exactly 5
        bytes32[] memory initialNodeIDs = new bytes32[](5);
        initialNodeIDs[0] = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        initialNodeIDs[1] = bytes32(0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890);
        initialNodeIDs[2] = bytes32(0x1111111111111111111111111111111111111111111111111111111111111111);
        initialNodeIDs[3] = bytes32(0x2222222222222222222222222222222222222222222222222222222222222222);
        initialNodeIDs[4] = bytes32(0x3333333333333333333333333333333333333333333333333333333333333333);

        // Test event emissions
        vm.startPrank(validator);
        vm.expectEmit(true, true, false, false);
        emit NodeIDAdded(validator, initialNodeIDs[0]);
        vm.expectEmit(true, true, false, false);
        emit NodeIDAdded(validator, initialNodeIDs[1]);
        vm.expectEmit(true, true, false, false);
        emit NodeIDAdded(validator, initialNodeIDs[2]);
        vm.expectEmit(true, true, false, false);
        emit NodeIDAdded(validator, initialNodeIDs[3]);
        vm.expectEmit(true, true, false, false);
        emit NodeIDAdded(validator, initialNodeIDs[4]);

        stakeHub.addNodeIDs(initialNodeIDs);

        // Verify the addition
        address[] memory validatorsToQuery = new address[](1);
        validatorsToQuery[0] = validator;
        (, bytes32[][] memory result) = stakeHub.getNodeIDs(validatorsToQuery);
        
        assertEq(result[0].length, 5, "Should have 5 NodeIDs");
        assertEq(result[0][0], initialNodeIDs[0], "First NodeID should match");
        assertEq(result[0][1], initialNodeIDs[1], "Second NodeID should match");
        assertEq(result[0][2], initialNodeIDs[2], "Third NodeID should match");
        assertEq(result[0][3], initialNodeIDs[3], "Fourth NodeID should match");
        assertEq(result[0][4], initialNodeIDs[4], "Fifth NodeID should match");

        // Test error cases
        // Test with too many NodeIDs - use unique NodeIDs to avoid DuplicateNodeID error
        bytes32[] memory tooManyNodeIDs = new bytes32[](1);
        tooManyNodeIDs[0] = bytes32(0x4444444444444444444444444444444444444444444444444444444444444444);
        vm.expectRevert(ExceedsMaxNodeIDs.selector);
        stakeHub.addNodeIDs(tooManyNodeIDs);
    }
}
