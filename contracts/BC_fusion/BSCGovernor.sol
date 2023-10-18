// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/compatibility/GovernorCompatibilityBravoUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorPreventLateQuorumUpgradeable.sol";
import "./System.sol";


contract BSCGovernor is
    System,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCompatibilityBravoUpgradeable,
    GovernorVotesUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorPreventLateQuorumUpgradeable
{
    function initialize(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorumNumerator,
        uint256 _proposalThreshold,
        uint64 _minPeriodAfterQuorum
    ) external initializer onlyCoinbase onlyZeroGasPrice {
        __Governor_init("BSCGovernor");
        __GovernorSettings_init(_votingDelay, _votingPeriod, _proposalThreshold);
        __GovernorCompatibilityBravo_init();
        __GovernorVotes_init(IVotesUpgradeable(GOV_TOKEN_ADDR));
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(payable(TIMELOCK_ADDR)));
        __GovernorVotesQuorumFraction_init(_quorumNumerator);
        __GovernorPreventLateQuorum_init(_minPeriodAfterQuorum);
    }

    function state(
        uint256 proposalId
    ) public view override(GovernorUpgradeable, IGovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (ProposalState) {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable, IGovernorUpgradeable) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable, IGovernorUpgradeable) returns (uint256) {
        return super.cancel(targets, values, calldatas, descriptionHash);
    }

    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        uint256 valueLength = value.length;
        if (_compareStrings(key, "votingDelay")) {
            require(valueLength == 32, "invalid votingDelay value length");
            uint256 newVotingDelay = _bytesToUint256(valueLength, value);
            require(newVotingDelay > 0, "invalid votingDelay");
            _setVotingDelay(newVotingDelay);
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    )
    internal
    override(GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable)
    returns (uint256)
    {
        return GovernorPreventLateQuorumUpgradeable._castVote(
            proposalId, account, support, reason, params
        );
    }

    function _executor() internal view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (address) {
        return super._executor();
    }

    function proposalThreshold()
    public
    view
    override(GovernorSettingsUpgradeable, GovernorUpgradeable)
    returns (uint256)
    {
        return GovernorSettingsUpgradeable.proposalThreshold();
    }

    function proposalDeadline(uint256 proposalId)
    public
    view
    override(IGovernorUpgradeable, GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable)
    returns (uint256)
    {
        return GovernorPreventLateQuorumUpgradeable.proposalDeadline(proposalId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(GovernorUpgradeable, IERC165Upgradeable, GovernorTimelockControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
