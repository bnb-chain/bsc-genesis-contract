pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

// Regression coverage for SRC-2026-950:
// BSCGovernor._castVote must reject a blacklisted VOTER (the EIP-712-recovered `account`),
// not only a blacklisted msg.sender, so a blacklisted voter cannot bypass the blacklist by
// having a clean relayer submit its signed ballot via castVoteBySig.
contract GovernorBlacklistBySigTest is Deployer {
    address private constant GOVERNOR_PROTECTOR = 0x08E68Ec70FA3b629784fDB28887e206ce8561E08;

    function setUp() public {
        vm.mockCall(address(0x66), bytes(""), hex"01");
    }

    function _ballotDigest(uint256 proposalId, uint8 support) internal view returns (bytes32) {
        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            governor.eip712Domain();
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
        bytes32 structHash = keccak256(abi.encode(governor.BALLOT_TYPEHASH(), proposalId, support));
        return keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
    }

    // Sets up a validator, gives `voter` voting power, creates an active proposal, returns its id.
    function _setupActiveProposal(address voter) internal returns (uint256 proposalId) {
        (address validator,,,) = _createValidator(2000 ether);

        // proposer with enough voting power to clear the proposal threshold
        address proposer = _getNextUserAddress();
        vm.deal(proposer, 20_000_000 ether);
        vm.startPrank(proposer);
        stakeHub.delegate{ value: 10_000_000 ether }(validator, false);
        govToken.delegate(proposer);
        vm.stopPrank();

        // voter gets its own voting power (self-delegated) before the proposal snapshot
        vm.deal(voter, 200_000 ether);
        vm.startPrank(voter);
        stakeHub.delegate{ value: 100_000 ether }(validator, false);
        govToken.delegate(voter);
        vm.stopPrank();

        // create the proposal
        address[] memory targets = new address[](1);
        targets[0] = GOV_HUB_ADDR;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "blacklist-bysig regression";

        vm.roll(block.number + 1);
        vm.prank(proposer);
        proposalId = governor.propose(targets, values, calldatas, description);

        // advance past the voting delay so the proposal is Active
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 3);
    }

    function testBlacklistedVoterCannotBypassViaCastVoteBySig() public {
        uint256 voterPk = 0xA11CE;
        address voter = vm.addr(voterPk);

        uint256 proposalId = _setupActiveProposal(voter);

        // protector blacklists the voter (emergency containment)
        vm.prank(GOVERNOR_PROTECTOR);
        governor.addToBlackList(voter);
        assertTrue(governor.blackList(voter), "voter blacklisted");

        // direct vote by the blacklisted voter reverts (baseline)
        vm.prank(voter);
        vm.expectRevert(BSCGovernor.InBlackList.selector);
        governor.castVote(proposalId, 1);

        // sign the ballot off-chain with the voter's key
        bytes32 digest = _ballotDigest(proposalId, 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPk, digest);

        // a CLEAN relayer submits the blacklisted voter's signed ballot -> must revert post-fix
        address relayer = _getNextUserAddress();
        assertFalse(governor.blackList(relayer), "relayer is clean");
        vm.prank(relayer);
        vm.expectRevert(BSCGovernor.InBlackList.selector);
        governor.castVoteBySig(proposalId, 1, v, r, s);

        assertFalse(governor.hasVoted(proposalId, voter), "blacklisted voter must not have voted");
    }

    function testCleanVoterCanStillVoteViaCastVoteBySig() public {
        uint256 voterPk = 0xB0B;
        address voter = vm.addr(voterPk);

        uint256 proposalId = _setupActiveProposal(voter);

        // no blacklist; clean voter signs and a relayer submits -> must succeed (no false positive)
        bytes32 digest = _ballotDigest(proposalId, 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPk, digest);

        address relayer = _getNextUserAddress();
        vm.prank(relayer);
        governor.castVoteBySig(proposalId, 1, v, r, s);

        assertTrue(governor.hasVoted(proposalId, voter), "clean voter's relayed vote should be recorded");
    }
}
