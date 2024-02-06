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

contract GovernorTest is Deployer {
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
        vm.startPrank(block.coinbase);
        vm.txGasPrice(0);
        stakeHub.initialize();
        vm.txGasPrice(0);
        govToken.initialize();
        vm.txGasPrice(0);
        governor.initialize();
        vm.txGasPrice(0);
        timelock.initialize();
        vm.stopPrank();
    }

    function testDelegateVote() public {
        address delegator = _getNextUserAddress();
        (address validator, address credit) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        // success case
        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, bnbAmount);

        uint256 govBNBBalance = govToken.balanceOf(delegator);
        assertEq(govBNBBalance, bnbAmount);

        assertEq(govToken.getVotes(delegator), 0);
        govToken.delegate(delegator);
        assertEq(govToken.getVotes(delegator), govBNBBalance);

        address user2 = _getNextUserAddress();
        govToken.delegate(user2);
        assertEq(govToken.getVotes(delegator), 0);
        assertEq(govToken.getVotes(user2), govBNBBalance);

        vm.stopPrank();
    }

    function testPropose() public {
        address delegator = _getNextUserAddress();
        (address validator, address credit) = _createValidator(2000 ether);
        vm.startPrank(delegator);
        assert(!governor.proposeStarted());

        vm.deal(delegator, 20_000_000 ether);

        uint256 bnbAmount = 10_000_000 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, bnbAmount);

        uint256 govBNBBalance = govToken.balanceOf(delegator);
        assertEq(govBNBBalance, bnbAmount);

        assertEq(govToken.getVotes(delegator), 0);
        govToken.delegate(delegator);
        assertEq(govToken.getVotes(delegator), govBNBBalance);

        // text Propose
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        string memory description = "test";

        vm.roll(block.number + 1);
        console.log("delegator", delegator);
        console.log("govToken.getVotes(delegator)", govToken.getVotes(delegator));

        // param proposal
        targets = new address[](1);
        targets[0] = GOV_HUB_ADDR;
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);

        uint256 newVotingDelay = 7;
        calldatas[0] = abi.encodeWithSignature(
            "updateParam(string,bytes,address)", "votingDelay", abi.encodePacked(newVotingDelay), GOVERNOR_ADDR
        );

        console.log("calldatas[0]");
        console.logBytes(calldatas[0]);

        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(governor.proposeStarted(), true, "propose should start");

        bytes32 descHash = keccak256(bytes(description));
        console.logBytes32(descHash);
        assertEq(proposalId, governor.hashProposal(targets, values, calldatas, descHash), "hashProposal");

        console.log("proposalId", proposalId);
        console.log("proposalSnapshot", governor.proposalSnapshot(proposalId));
        console.log("now", governor.clock());

        uint256 _nowBlock = block.number;
        uint256 _now = block.timestamp;
        vm.roll(_nowBlock + 10);
        vm.warp(_now + 1 days);

        governor.castVote(proposalId, 1);

        vm.roll(_nowBlock + 100000000);
        vm.warp(block.timestamp + 100 days);

        governor.state(proposalId);

        governor.queue(proposalId);

        vm.warp(block.timestamp + 102 days);

        governor.execute(proposalId);

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
