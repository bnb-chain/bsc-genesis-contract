// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface BSCGovernor {
    type ProposalState is uint8;

    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    error AlreadyPaused();
    error Empty();
    error InBlackList();
    error InvalidValue(string key, bytes value);
    error NotPaused();
    error NotWhitelisted();
    error OneLiveProposalPerProposer();
    error OnlyCoinbase();
    error OnlyProtector();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error TotalSupplyNotEnough();
    error UnknownParam(string key, bytes value);

    event BlackListed(address indexed target);
    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event LateQuorumVoteExtensionSet(uint64 oldVoteExtension, uint64 newVoteExtension);
    event ParamChange(string key, bytes value);
    event Paused();
    event ProposalCanceled(uint256 proposalId);
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalExecuted(uint256 proposalId);
    event ProposalExtended(uint256 indexed proposalId, uint64 extendedDeadline);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event ProtectorChanged(address indexed oldProtector, address indexed newProtector);
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);
    event Resumed();
    event TimelockChange(address oldTimelock, address newTimelock);
    event UnBlackListed(address indexed target);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    receive() external payable;

    function BALLOT_TYPEHASH() external view returns (bytes32);
    function BC_FUSION_CHANNELID() external view returns (uint8);
    function CLOCK_MODE() external view returns (string memory);
    function COUNTING_MODE() external pure returns (string memory);
    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);
    function STAKING_CHANNELID() external view returns (uint8);
    function addToBlackList(address account) external;
    function blackList(address) external view returns (bool);
    function cancel(uint256 proposalId) external;
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);
    function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason) external returns (uint256);
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params
    ) external returns (uint256);
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string memory reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);
    function clock() external view returns (uint48);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);
    function execute(uint256 proposalId) external payable;
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);
    function getVotes(address account, uint256 timepoint) external view returns (uint256);
    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    ) external view returns (uint256);
    function hasVoted(uint256 proposalId, address account) external view returns (bool);
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);
    function initialize() external;
    function isPaused() external view returns (bool);
    function lateQuorumVoteExtension() external view returns (uint64);
    function latestProposalIds(address) external view returns (uint256);
    function name() external view returns (string memory);
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external returns (bytes4);
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);
    function pause() external;
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalEta(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function proposals(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool canceled,
            bool executed
        );
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
    function proposeStarted() external view returns (bool);
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256 proposalId);
    function queue(uint256 proposalId) external;
    function quorum(uint256 timepoint) external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function quorumNumerator(uint256 timepoint) external view returns (uint256);
    function quorumNumerator() external view returns (uint256);
    function quorumVotes() external view returns (uint256);
    function relay(address target, uint256 value, bytes memory data) external payable;
    function removeFromBlackList(address account) external;
    function resume() external;
    function setLateQuorumVoteExtension(uint64 newVoteExtension) external;
    function setProposalThreshold(uint256 newProposalThreshold) external;
    function setVotingDelay(uint256 newVotingDelay) external;
    function setVotingPeriod(uint256 newVotingPeriod) external;
    function state(uint256 proposalId) external view returns (ProposalState);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function timelock() external view returns (address);
    function token() external view returns (address);
    function updateParam(string memory key, bytes memory value) external;
    function updateQuorumNumerator(uint256 newQuorumNumerator) external;
    function updateTimelock(address newTimelock) external;
    function version() external view returns (string memory);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function whitelistTargets(address) external view returns (bool);
}
