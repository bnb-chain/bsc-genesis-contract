// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

// Regression coverage for SRC-2026-966 / SRC-2026-916:
// the operator / consensus / agent address namespaces must be disjoint so that
// _bep563MsgSender() cannot be made to resolve a caller to the wrong validator.
contract StakeHubIdentityNamespaceTest is Deployer {
    function setUp() public {
        vm.txGasPrice(0);
        vm.mockCall(address(0x66), bytes(""), hex"01");

        vm.startPrank(block.coinbase);
        stakeHub.initialize();
        govToken.initialize();
        vm.stopPrank();
    }

    // SRC-2026-966: an attacker must not be able to register a validator whose
    // consensus address equals a victim validator's operator address.
    function testCreateValidatorRejectsConsensusEqualToExistingOperator() public {
        (address victimOperator,,,) = _createValidator(2_000 ether);

        address attackerOperator = _getNextUserAddress();
        bytes memory attackerVote = bytes.concat(
            hex"00000000000000000000000000000000000000000000000000000000", abi.encodePacked(attackerOperator)
        );
        StakeHub.Commission memory commission = StakeHub.Commission({ rate: 10, maxRate: 100, maxChangeRate: 5 });
        StakeHub.Description memory description =
            StakeHub.Description({ moniker: "Shadow", identity: "S", website: "S", details: "S" });

        // consensusAddress == victimOperator (an existing operator) must revert.
        vm.prank(attackerOperator);
        vm.expectRevert(StakeHub.InvalidConsensusAddress.selector);
        stakeHub.createValidator{ value: 2_001 ether }(
            victimOperator, attackerVote, new bytes(96), commission, description
        );
    }

    // SRC-2026-966: consensus address must not collide with an existing agent address.
    function testCreateValidatorRejectsConsensusEqualToExistingAgent() public {
        (address opA,,,) = _createValidator(2_000 ether);

        address agentX = _getNextUserAddress();
        vm.prank(opA);
        stakeHub.updateAgent(agentX);

        address attackerOperator = _getNextUserAddress();
        bytes memory attackerVote = bytes.concat(
            hex"00000000000000000000000000000000000000000000000000000000", abi.encodePacked(attackerOperator)
        );
        StakeHub.Commission memory commission = StakeHub.Commission({ rate: 10, maxRate: 100, maxChangeRate: 5 });
        StakeHub.Description memory description =
            StakeHub.Description({ moniker: "Shadow2", identity: "S", website: "S", details: "S" });

        vm.prank(attackerOperator);
        vm.expectRevert(StakeHub.InvalidConsensusAddress.selector);
        stakeHub.createValidator{ value: 2_001 ether }(
            agentX, attackerVote, new bytes(96), commission, description
        );
    }

    // SRC-2026-916: editConsensusAddress must reject a new consensus address that is
    // already someone's agent address.
    function testEditConsensusRejectsAddressThatIsAgent() public {
        (address opA,,,) = _createValidator(2_000 ether);
        (address opB,,,) = _createValidator(2_000 ether);

        address agentX = _getNextUserAddress();
        vm.prank(opB);
        stakeHub.updateAgent(agentX);

        vm.warp(block.timestamp + stakeHub.BREATHE_BLOCK_INTERVAL() + 1);
        vm.prank(opA);
        vm.expectRevert(StakeHub.InvalidConsensusAddress.selector);
        stakeHub.editConsensusAddress(agentX);
    }

    // SRC-2026-916: updateAgent must reject a new agent address that is already
    // someone's consensus address (covers the reverse ordering).
    function testUpdateAgentRejectsAddressThatIsConsensus() public {
        (, address consensusA,,) = _createValidator(2_000 ether);
        (address opB,,,) = _createValidator(2_000 ether);

        vm.prank(opB);
        vm.expectRevert(StakeHub.InvalidAgent.selector);
        stakeHub.updateAgent(consensusA);
    }

    // Sanity: a clean, fully-disjoint validator creation + agent + consensus rotation still works.
    function testLegitimateFlowStillWorks() public {
        (address opA,,,) = _createValidator(2_000 ether);

        address agentX = _getNextUserAddress();
        vm.prank(opA);
        stakeHub.updateAgent(agentX);

        address newConsensus = _getNextUserAddress();
        vm.warp(block.timestamp + stakeHub.BREATHE_BLOCK_INTERVAL() + 1);
        vm.prank(opA);
        stakeHub.editConsensusAddress(newConsensus);

        address consAfter = stakeHub.getValidatorConsensusAddress(opA);
        assertEq(consAfter, newConsensus, "legitimate consensus rotation should succeed");
    }
}
