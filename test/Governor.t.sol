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
    }

    function testDelegateVote() public {
        address delegator = _getNextUserAddress();
        (address validator,, address credit,) = _createValidator(2000 ether);
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

    function testProposeErrorCase() public {
        address delegator = _getNextUserAddress();
        (address validator,, address credit,) = _createValidator(2000 ether);
        vm.startPrank(delegator);
        assert(governor.proposeStarted());
        vm.deal(delegator, 20_000_000 ether);
        uint256 bnbAmount = 10_000_000 ether - 2000 ether - 1 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);
        uint256 shares = IStakeCredit(credit).balanceOf(delegator);
        assertEq(shares, bnbAmount);

        uint256 govBNBBalance = govToken.balanceOf(delegator);
        assertEq(govBNBBalance, bnbAmount);

        assertEq(govToken.getVotes(delegator), 0);
        govToken.delegate(delegator);
        assertEq(govToken.getVotes(delegator), govBNBBalance);
        console.log("govBNBBalance", govBNBBalance);

        // text Propose
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;

        vm.roll(block.number + 1);

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

        //        assertEq(governor.proposeStarted(), true, "propose should not start");

        // mainnet totalSupply is already enough
        // // govBNB totalSupply not enough
        // string memory description = "test";
        // vm.expectRevert();
        // uint256 proposalId = governor.propose(targets, values, calldatas, description);
        // assertEq(governor.proposeStarted(), false, "propose should not start");
        //
        // bnbAmount = 1 ether;
        // stakeHub.delegate{ value: bnbAmount }(validator, false);
        // proposalId = governor.propose(targets, values, calldatas, description);
        // assertEq(governor.proposeStarted(), true, "propose should start");
        //
        // bnbAmount = 10000000 ether - 2000 ether;
        // govBNBBalance = govToken.balanceOf(delegator);
        // console.log("govBNBBalance", govBNBBalance);
        // assertEq(govBNBBalance, bnbAmount);
        // assertEq(govToken.getVotes(delegator), govBNBBalance);
        // console.log("voting power before undelegate", govToken.getVotes(delegator));

        // voting power changed after undelegating staking share
        bnbAmount = 1 ether;
        stakeHub.undelegate(validator, bnbAmount);
        console.log("voting power after undelegate", govToken.getVotes(delegator));
        assertEq(govToken.getVotes(delegator), govBNBBalance - bnbAmount);
    }

    function testProposalNotApproved() public {
        address delegator = _getNextUserAddress();
        (address validator,,,) = _createValidator(2000 ether);
        vm.startPrank(delegator);
        assert(governor.proposeStarted());
        vm.deal(delegator, 20_000_000 ether);
        uint256 bnbAmount = 10_000_000 ether - 2000 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);

        assertEq(govToken.getVotes(delegator), 0);
        govToken.delegate(delegator);
        assertEq(govToken.getVotes(delegator), bnbAmount);
        console.log("govToken.getVotes(delegator)", govToken.getVotes(delegator));

        address delegator2 = _getNextUserAddress();
        vm.startPrank(delegator2);
        vm.deal(delegator2, 20_000_000 ether);
        bnbAmount = 10_000_000 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);

        assertEq(govToken.getVotes(delegator2), 0);
        govToken.delegate(delegator2);
        assertEq(govToken.getVotes(delegator2), bnbAmount);
        console.log("govToken.getVotes(delegator2)", govToken.getVotes(delegator2));
        vm.stopPrank();

        // text Propose
        vm.startPrank(delegator);
        address[] memory targets = new address[](1);
        targets[0] = GOV_HUB_ADDR;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "test";

        vm.roll(block.number + 1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        uint256 _nowBlock = block.number;
        uint256 _now = block.timestamp;
        vm.roll(_nowBlock + 1);
        vm.warp(_now + 3);
        // support vote
        governor.castVote(proposalId, 1);
        vm.stopPrank();

        vm.startPrank(delegator2);
        // against vote
        governor.castVote(proposalId, 0);
        vm.stopPrank();

        uint256 deadline = governor.proposalDeadline(proposalId);
        vm.roll(deadline + 1);

        // against > support
        vm.expectRevert("Governor: proposal not successful");
        governor.queue(proposalId);
    }

    function testProposalQuorumNotReached() public {
        address delegator = _getNextUserAddress();
        (address validator,,,) = _createValidator(2000 ether);
        vm.startPrank(delegator);
        assert(governor.proposeStarted());
        vm.deal(delegator, 20_000_000 ether);
        uint256 bnbAmount = 10_000_000 ether - 2000 ether;
        stakeHub.delegate{ value: bnbAmount }(validator, false);

        assertEq(govToken.getVotes(delegator), 0);
        govToken.delegate(delegator);
        assertEq(govToken.getVotes(delegator), bnbAmount);
        console.log("govToken.getVotes(delegator)", govToken.getVotes(delegator));

        address delegator2 = _getNextUserAddress();
        vm.startPrank(delegator2);
        vm.deal(delegator2, 20_000_000 ether);
        bnbAmount = bnbAmount / 10;
        stakeHub.delegate{ value: bnbAmount }(validator, false);

        assertEq(govToken.getVotes(delegator2), 0);
        govToken.delegate(delegator2);
        assertEq(govToken.getVotes(delegator2), bnbAmount);
        console.log("govToken.getVotes(delegator2)", govToken.getVotes(delegator2));
        vm.stopPrank();

        // text Propose
        vm.startPrank(delegator);
        address[] memory targets = new address[](1);
        targets[0] = GOV_HUB_ADDR;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "test";

        vm.roll(block.number + 1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        uint256 _nowBlock = block.number;
        uint256 _now = block.timestamp;
        vm.roll(_nowBlock + 1);
        vm.warp(_now + 3);
        vm.stopPrank();

        vm.startPrank(delegator2);
        // support vote, support quorum < 10%
        governor.castVote(proposalId, 1);
        vm.stopPrank();

        uint256 deadline = governor.proposalDeadline(proposalId);
        vm.roll(deadline + 1);

        // quorum not reached
        uint256 quorumVote = governor.quorumVotes();

        (,,,,, uint256 forVotes, uint256 againstVotes,,,) = governor.proposals(proposalId);

        console.log("quorumVote", quorumVote);
        console.log("forVotes", forVotes);
        console.log("againstVotes", againstVotes);

        assertEq(forVotes < quorumVote, true, "quorum not reached");

        vm.expectRevert("Governor: proposal not successful");
        governor.queue(proposalId);
    }

    function testProposeQuorumReached() public {
        address delegator = _getNextUserAddress();
        (address validator,, address credit,) = _createValidator(2000 ether);
        vm.startPrank(delegator);
        assert(governor.proposeStarted());

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

        uint256 BLOCK_INTERVAL = 3 seconds;
        uint256 INIT_VOTING_PERIOD = 7 days / BLOCK_INTERVAL;
        uint256 NEW_VOTING_PERIOD = INIT_VOTING_PERIOD * 2;
        uint64 INIT_MIN_PERIOD_AFTER_QUORUM = uint64(1 days / BLOCK_INTERVAL);
        uint64 NEW_MIN_PERIOD_AFTER_QUORUM = INIT_MIN_PERIOD_AFTER_QUORUM * 2;
        vm.roll(_nowBlock + NEW_VOTING_PERIOD - 1);
        vm.warp(_now + (NEW_VOTING_PERIOD - 1) * BLOCK_INTERVAL / 2);

        uint256 deadline = governor.proposalDeadline(proposalId);
        console.log("block.number", block.number);
        console.log("deadline block", deadline);
        assertEq(deadline, block.number + 1);

        governor.castVote(proposalId, 1);

        deadline = governor.proposalDeadline(proposalId);
        console.log("block.number", block.number);
        console.log("deadline block", deadline);
        // quorum reached, deadline should be added 1 day
        assertEq(deadline, block.number + NEW_MIN_PERIOD_AFTER_QUORUM);
    }

    function testPropose() public {
        address delegator = _getNextUserAddress();
        (address validator,, address credit,) = _createValidator(2000 ether);
        vm.startPrank(delegator);
        assert(governor.proposeStarted());

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
        (address validator,, address credit,) = _createValidator(2000 ether);
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
}
