// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/compatibility/GovernorCompatibilityBravoUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorPreventLateQuorumUpgradeable.sol";

import "./System.sol";
import "./lib/Utils.sol";
import "./interface/IGovToken.sol";

contract BSCGovernor is
    System,
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCompatibilityBravoUpgradeable,
    GovernorVotesUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorPreventLateQuorumUpgradeable
{
    using Utils for bytes;
    using Utils for string;

    /*----------------- constants -----------------*/
    uint256 private constant INIT_VOTING_DELAY = 24 hours;
    uint256 private constant INIT_VOTING_PERIOD = 14 days;
    uint256 private constant INIT_PROPOSAL_THRESHOLD = 100 ether; //  = 100 BNB
    uint256 private constant INIT_QUORUM_NUMERATOR = 10; // for >= 10%

    // starting propose requires totalSupply of GovBNB >= 10000000 * 1e18
    uint256 private constant PROPOSE_START_GOVBNB_SUPPLY_THRESHOLD = 10_000_000 ether;
    // ensures there is a minimum voting period (1 days) after quorum is reached
    uint64 private constant INIT_MIN_PERIOD_AFTER_QUORUM = uint64(1 days);

    /*----------------- errors -----------------*/
    error NotWhitelisted();
    error TotalSupplyNotEnough();

    /*----------------- storage -----------------*/
    // target contract => is whitelisted for governance
    mapping(address => bool) public whitelistTargets;

    bool public proposeStarted;

    /*----------------- init -----------------*/
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        __Governor_init("BSCGovernor");
        __GovernorSettings_init(INIT_VOTING_DELAY, INIT_VOTING_PERIOD, INIT_PROPOSAL_THRESHOLD);
        __GovernorCompatibilityBravo_init();
        __GovernorVotes_init(IVotesUpgradeable(GOV_TOKEN_ADDR));
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(payable(TIMELOCK_ADDR)));
        __GovernorVotesQuorumFraction_init(INIT_QUORUM_NUMERATOR);
        __GovernorPreventLateQuorum_init(INIT_MIN_PERIOD_AFTER_QUORUM);

        whitelistTargets[VALIDATOR_CONTRACT_ADDR] = true;
        whitelistTargets[SLASH_CONTRACT_ADDR] = true;
        whitelistTargets[SYSTEM_REWARD_ADDR] = true;
        whitelistTargets[LIGHT_CLIENT_ADDR] = true;
        whitelistTargets[TOKEN_HUB_ADDR] = true;
        whitelistTargets[INCENTIVIZE_ADDR] = true;
        whitelistTargets[RELAYERHUB_CONTRACT_ADDR] = true;
        whitelistTargets[GOV_HUB_ADDR] = true;
        whitelistTargets[TOKEN_MANAGER_ADDR] = true;
        whitelistTargets[CROSS_CHAIN_CONTRACT_ADDR] = true;
        whitelistTargets[STAKING_CONTRACT_ADDR] = true;
        whitelistTargets[STAKE_HUB_ADDR] = true;
        whitelistTargets[GOVERNOR_ADDR] = true;
        whitelistTargets[GOV_TOKEN_ADDR] = true;
        whitelistTargets[TIMELOCK_ADDR] = true;
    }

    /*----------------- external functions -----------------*/
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        _checkAndStartPropose();

        for (uint256 i = 0; i < targets.length; i++) {
            if (!whitelistTargets[targets[i]]) revert NotWhitelisted();
        }

        return GovernorCompatibilityBravoUpgradeable.propose(targets, values, calldatas, description);
    }

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        public
        override(GovernorUpgradeable, GovernorCompatibilityBravoUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        return GovernorCompatibilityBravoUpgradeable.cancel(targets, values, calldatas, descriptionHash);
    }

    /*----------------- system functions -----------------*/
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("votingDelay")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newVotingDelay = value.bytesToUint256(32);
            if (newVotingDelay == 0) revert InvalidValue(key, value);
            _setVotingDelay(newVotingDelay);
        } else if (key.compareStrings("votingPeriod")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newVotingPeriod = value.bytesToUint256(32);
            if (newVotingPeriod == 0) revert InvalidValue(key, value);
            _setVotingPeriod(newVotingPeriod);
        } else if (key.compareStrings("proposalThreshold")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newProposalThreshold = value.bytesToUint256(32);
            if (newProposalThreshold == 0) revert InvalidValue(key, value);
            _setProposalThreshold(newProposalThreshold);
        } else if (key.compareStrings("quorumNumerator")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newQuorumNumerator = value.bytesToUint256(32);
            if (newQuorumNumerator == 0) revert InvalidValue(key, value);
            _updateQuorumNumerator(newQuorumNumerator);
        } else if (key.compareStrings("minPeriodAfterQuorum")) {
            if (value.length != 8) revert InvalidValue(key, value);
            uint64 newMinPeriodAfterQuorum = value.bytesToUint64(8);
            if (newMinPeriodAfterQuorum == 0) revert InvalidValue(key, value);
            _setLateQuorumVoteExtension(newMinPeriodAfterQuorum);
        } else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, IERC165Upgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return GovernorTimelockControlUpgradeable.supportsInterface(interfaceId);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, IGovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return GovernorTimelockControlUpgradeable.state(proposalId);
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

    /*----------------- internal functions -----------------*/
    function _checkAndStartPropose() internal {
        if (!proposeStarted) {
            if (IGovToken(GOV_TOKEN_ADDR).totalSupply() < PROPOSE_START_GOVBNB_SUPPLY_THRESHOLD) {
                revert TotalSupplyNotEnough();
            }
            proposeStarted = true;
        }
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        for (uint256 i = 0; i < targets.length; i++) {
            if (!whitelistTargets[targets[i]]) revert NotWhitelisted();
        }

        GovernorTimelockControlUpgradeable._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return GovernorTimelockControlUpgradeable._cancel(targets, values, calldatas, descriptionHash);
    }

    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override(GovernorUpgradeable, GovernorPreventLateQuorumUpgradeable) returns (uint256) {
        return GovernorPreventLateQuorumUpgradeable._castVote(proposalId, account, support, reason, params);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return GovernorTimelockControlUpgradeable._executor();
    }
}
