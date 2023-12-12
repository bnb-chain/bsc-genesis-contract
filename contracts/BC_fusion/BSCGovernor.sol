// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/compatibility/GovernorCompatibilityBravoUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorPreventLateQuorumUpgradeable.sol";

interface IGovToken {
    function totalSupply() external view returns (uint256);
}

contract BSCGovernor is
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCompatibilityBravoUpgradeable,
    GovernorVotesUpgradeable,
    GovernorTimelockControlUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorPreventLateQuorumUpgradeable
{
    /*
        @dev caution:
        INIT_VOTING_DELAY, INIT_VOTING_PERIOD and INIT_MIN_PERIOD_AFTER_QUORUM are default in number of blocks, not seconds
    */
    // TODO
    uint256 private constant INIT_VOTING_DELAY = 60 seconds / 3;
    // TODO
    uint256 private constant INIT_VOTING_PERIOD = 10 minutes / 3;
    uint256 private constant INIT_PROPOSAL_THRESHOLD = 0.1 ether; //  = 100 BNB
    uint256 private constant INIT_QUORUM_NUMERATOR = 20; // for >= 10%

    // starting propose requires totalSupply of GovBNB >= 10000000 * 1e18
    uint256 private constant PROPOSE_START_GOVBNB_SUPPLY_THRESHOLD = 0.1 ether;
    // ensures there is a minimum voting period (1 days) after quorum is reached
    uint64 private constant INIT_MIN_PERIOD_AFTER_QUORUM = uint64(10 minutes / 3);

    // TODO modify these through deploy scripts
    address private constant GOV_HUB_ADDR = address(0);
    address private constant GOV_TOKEN_ADDR = address(0);
    address private constant TIMELOCK_ADDR = address(0);
    /*----------------- errors -----------------*/
    // @notice signature: 0x584a7938
    error NotWhitelisted();
    // @notice signature: 0x11b6707f
    error TotalSupplyNotEnough();
    // @notice signature: 0xe96776bf
    error GovernorPaused();
    // @notice signature: 0x286300de
    error OnlyGovernorProtector();

    /*----------------- events -----------------*/
    event Paused();
    event Resumed();

    /*----------------- storage -----------------*/
    // target contract => is whitelisted for governance
    mapping(address => bool) public whitelistTargets;
    bool public proposeStarted;
    bool public paused;
    address public governorProtector;

    /*----------------- modifier -----------------*/
    modifier whenNotPaused() {
        if (paused) revert GovernorPaused();
        _;
    }

    modifier onlyGovernorProtector() {
        if (msg.sender != governorProtector) revert OnlyGovernorProtector();
        _;
    }

    /*----------------- init -----------------*/
    function initialize() external initializer {
        __Governor_init("B");
        __GovernorSettings_init(INIT_VOTING_DELAY, INIT_VOTING_PERIOD, INIT_PROPOSAL_THRESHOLD);
        __GovernorCompatibilityBravo_init();
        __GovernorVotes_init(IVotesUpgradeable(GOV_TOKEN_ADDR));
        __GovernorTimelockControl_init(TimelockControllerUpgradeable(payable(TIMELOCK_ADDR)));
        __GovernorVotesQuorumFraction_init(INIT_QUORUM_NUMERATOR);
        __GovernorPreventLateQuorum_init(INIT_MIN_PERIOD_AFTER_QUORUM);

        // BSCGovernor => Timelock => GovHub => system contracts
        whitelistTargets[GOV_HUB_ADDR] = true;

        governorProtector = address(0); // TODO
    }

    /*----------------- onlyGovernorProtector -----------------*/
    /**
     * @dev Pause the whole system in emergency
     */
    function pause() external onlyGovernorProtector {
        paused = true;
        emit Paused();
    }

    /**
     * @dev Resume the whole system
     */
    function resume() external onlyGovernorProtector {
        paused = false;
        emit Resumed();
    }

    /*----------------- external functions -----------------*/
    /**
     * @dev Create a new proposal. Vote start after a delay specified by {IGovernor-votingDelay} and lasts for a
     * duration specified by {IGovernor-votingPeriod}.
     *
     * Emits a {ProposalCreated} event.
     */
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

    /**
     * @dev Cancel a proposal. A proposal is cancellable by the proposer, but only while it is Pending state, i.e.
     * before the vote starts.
     *
     * Emits a {ProposalCanceled} event.
     */
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
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) whenNotPaused {
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

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(GovernorUpgradeable, IERC165Upgradeable, GovernorTimelockControlUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
