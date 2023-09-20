pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "./System.sol";
import "./interface/IBSCValidatorSetV2.sol";
import "./lib/SafeMath.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";

interface IGovHub {
  function updateParam(string calldata key, bytes calldata value, address target) external;
}

interface IShare {
  function lockToGovernance(address from, uint256 shareAmount) external;
  function unlockFromGovernance(address to, uint256 shareAmount) external;
  function getVotingPower(uint256 shareAmount) external returns (uint256 votingPower);
}

// TODO: add IGovernance extend
contract Governance is System {
  using SafeMath for uint256;

  uint256 public constant INIT_VOTING_PERIOD = 1 weeks;
  uint256 public constant INIT_POLL_VOTING_PERIOD = 2 weeks;
  uint256 public constant INIT_EXECUTION_DELAY = 1 days;
  uint256 public constant INIT_EXECUTION_EXPIRATION = 3 days;
  uint256 public constant INIT_QUORUM_VOTING_POWER = 1e7 ether;
  uint256 public constant INIT_POLL_SUBMIT_THRESHOLD = 50 ether;
  uint256 public constant INIT_PROPOSAL_EXECUTE_SUPPORT_RATE = 50;
  uint256 public constant PROPOSAL_EXECUTE_SUPPORT_RATE_SCALE = 100;

  // locker => share contract => LockShare
  mapping(address => mapping(address => LockShare)) private lockShareMap;
  ParamProposal[] public paramProposals;
  Poll[] public polls;
  uint256 public votingPeriod;
  uint256 public pollVotingPeriod;
  uint256 public executionDelay;
  uint256 public executionExpiration;
  uint256 public quorumVotingPower;
  uint256 public pollSubmitThreshold;
  uint256 public executeSupportRate;

  enum ProposalState { Pending, Active, Defeated, Canceled, Timelocked, AwaitingExecution, Executed, Expired }
  struct ParamProposalRequest {
    string key;
    bytes value;
    address target;
  }

  struct ParamProposal {
    ParamProposalRequest[] requests;

    address proposer;
    string description;

    // vote starts at
    uint256 startAt;
    // vote ends at
    uint256 endAt;
    uint256 forVotingPower;
    uint256 againstVotingPower;
    bool executed;
    bool canceled;
  }

  struct Poll {
    address proposer;
    string description;

    // vote starts at
    uint256 startAt;
    // vote ends at
    uint256 endAt;
    uint256 forVotingPower;
    uint256 againstVotingPower;
  }

  struct LockShare {
    uint256 amount;
    uint256 votingPower;

    uint256[] votedProposalIds;
    uint256[] votedPollIds;
  }

  event paramChange(string key, bytes value);
  event ProposalCreated(
    uint256 indexed id,

    address indexed proposer,
    string description,
    uint256 startAt,
    uint256 endAt
  );
  event ProposalExecuted(uint256 indexed proposalId, address indexed executor);
  event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool indexed support, address shareContract, uint256 shareAmount, uint256 votingPower);

  event PollCreated(
    uint256 indexed id,

    address indexed proposer,
    string description,
    uint256 startAt,
    uint256 endAt
  );
  event PollVoted(uint256 indexed proposalId, address indexed voter, bool indexed support, address shareContract, uint256 shareAmount, uint256 votingPower);

  modifier onlyCabinet() {
    uint256 indexPlus = IBSCValidatorSetV2(VALIDATOR_CONTRACT_ADDR).currentValidatorSetMap(msg.sender);
    uint256 numOfCabinets = IBSCValidatorSetV2(VALIDATOR_CONTRACT_ADDR).numOfCabinets();
    if (numOfCabinets == 0) {
      numOfCabinets = 21;
    }

    require(indexPlus > 0 && indexPlus <= numOfCabinets, "not cabinet");
    _;
  }

  function submitProposal(ParamProposalRequest[] calldata requests, string calldata description, uint256 voteAt) external onlyCabinet {
    _paramInit();

    require(voteAt == 0 || voteAt >= block.timestamp, "invalid voteAt");
    if (voteAt == 0) {
      voteAt = block.timestamp;
    }

    require(requests.length > 0, "empty proposal");
    ParamProposal memory proposal = ParamProposal(requests, msg.sender, description, voteAt, voteAt + votingPeriod, 0, 0, false, false);
    paramProposals.push(proposal);

    emit ProposalCreated(paramProposals.length - 1, msg.sender, description, voteAt, voteAt + votingPeriod);
  }

  function cancelProposal(uint256 proposalId) external {
    _paramInit();

    ParamProposal storage proposal = paramProposals[proposalId];
    require(msg.sender == proposal.proposer, "only proposer");
    ProposalState _state = proposalState(proposalId);
    require(
      _state == ProposalState.Pending &&
      _state == ProposalState.Active &&
      _state == ProposalState.Timelocked &&
      _state == ProposalState.AwaitingExecution,
      "invalid proposal state"
    );

    proposal.canceled = true;
  }

  function executeProposal(uint256 proposalId) external onlyCabinet {
    _paramInit();

    require(proposalState(proposalId) == ProposalState.AwaitingExecution, "vote not awaiting execution");

    ParamProposal storage proposal = paramProposals[proposalId];
    proposal.executed = true;

    ParamProposalRequest memory request;
    for (uint256 i = 0; i < proposal.requests.length; i++) {
      request = proposal.requests[i];
      IGovHub(GOV_HUB_ADDR).updateParam(request.key, request.value, request.target);
    }

    emit ProposalExecuted(proposalId, msg.sender);
  }

  function submitPoll(string calldata description, uint256 voteAt, address shareContract) external {
    _paramInit();
    address proposer = msg.sender;
    LockShare memory lockShare = lockShareMap[proposer][shareContract];
    require(lockShare.votingPower >= pollSubmitThreshold, "locked voting power not enough");

    require(voteAt == 0 || voteAt >= block.timestamp, "invalid voteAt");
    if (voteAt == 0) {
      voteAt = block.timestamp;
    }

    Poll memory poll = Poll(proposer, description, voteAt, voteAt + votingPeriod, 0, 0);
    polls.push(poll);

    emit PollCreated(polls.length - 1, msg.sender, description, voteAt, voteAt + votingPeriod);
  }

  function lockShare(address shareContract, uint256 shareAmount) external {
    address voter = msg.sender;
    LockShare storage lockShare = lockShareMap[voter][shareContract];
    require(lockShare.votedProposalIds.length == 0, "still voting");

    IShare(shareContract).lockToGovernance(voter, shareAmount);
    lockShare.amount = lockShare.amount.add(shareAmount);
    lockShare.votingPower = IShare(shareContract).getVotingPower(lockShare.amount);
  }

  function unlockShare(address shareContract, uint256 shareAmount) external {
    address voter = msg.sender;
    LockShare storage lockShare = lockShareMap[voter][shareContract];
    require(shareAmount <= lockShare.amount, "invalid share amount");

    if (lockShare.votedProposalIds.length > 0) {
      for (uint256 i = 0; i < lockShare.votedProposalIds.length; i++) {
        require(proposalState(lockShare.votedProposalIds[i]) != ProposalState.Active, "still voting");
      }
      delete lockShare.votedProposalIds;
    }

    IShare(shareContract).unlockFromGovernance(voter, shareAmount);
    lockShare.amount = lockShare.amount.sub(shareAmount);
    lockShare.votingPower = IShare(shareContract).getVotingPower(lockShare.amount);
  }

  function castVote(bool isProposal, uint256 id, bool support, address shareContract) external {
    if (isProposal) {
      _voteForProposal(msg.sender, id, support, shareContract);
    } else {
      _voteForPoll(msg.sender, id, support, shareContract);
    }
  }

  function updateParam(string calldata key, bytes calldata value) external onlyGov {
    require(value.length == 32, "expected value length is 32");

    if (Memory.compareStrings(key, "votingPeriod")) {
      uint256 newVotingPeriod = BytesToTypes.bytesToUint256(32, value);
      require(newVotingPeriod > 0 && newVotingPeriod <= 10 weeks, "invalid new votingPeriod");
      votingPeriod = newVotingPeriod;
    } else if (Memory.compareStrings(key, "pollVotingPeriod")) {
      uint256 newPollVotingPeriod = BytesToTypes.bytesToUint256(32, value);
      require(newPollVotingPeriod > 1 weeks && newPollVotingPeriod <= 10 weeks, "invalid new pollVotingPeriod");
      pollVotingPeriod = newPollVotingPeriod;
    } else if (Memory.compareStrings(key, "executionDelay")) {
      uint256 newExecutionDelay = BytesToTypes.bytesToUint256(32, value);
      require(newExecutionDelay > 0 && newExecutionDelay <= 7 days, "invalid new executionDelay");
      executionDelay = newExecutionDelay;
    } else if (Memory.compareStrings(key, "executionExpiration")) {
      uint256 newExecutionExpiration = BytesToTypes.bytesToUint256(32, value);
      require(newExecutionExpiration > 0 && newExecutionExpiration <= 7 days, "invalid new executionExpiration");
      executionExpiration = newExecutionExpiration;
    } else if (Memory.compareStrings(key, "quorumVotingPower")) {
      uint256 newQuorumVotingPower = BytesToTypes.bytesToUint256(32, value);
      require(newQuorumVotingPower >= 10000 ether && newQuorumVotingPower <= 2e8 ether, "invalid new quorumVotingPower");
      quorumVotingPower = newQuorumVotingPower;
    } else if (Memory.compareStrings(key, "pollSubmitThreshold")) {
      uint256 newPollSubmitThreshold = BytesToTypes.bytesToUint256(32, value);
      require(newPollSubmitThreshold >= 10 ether && newPollSubmitThreshold <= 2e8 ether, "invalid new pollSubmitThreshold");
      pollSubmitThreshold = newPollSubmitThreshold;
    } else if (Memory.compareStrings(key, "executeSupportRate")) {
      uint256 newExecuteSupportRate = BytesToTypes.bytesToUint256(32, value);
      require(newExecuteSupportRate >= 50 && newExecuteSupportRate <= 100, "invalid new executeSupportRate");
      executeSupportRate = newExecuteSupportRate;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  function _voteForProposal(address voter, uint256 proposalId, bool support, address shareContract) internal {
    require(proposalState(proposalId) == ProposalState.Active, "vote not active");

    LockShare storage lockShare = lockShareMap[voter][shareContract];
    ParamProposal storage proposal = paramProposals[proposalId];

    for (uint256 i = 0; i < lockShare.votedProposalIds.length; i++) {
      require(lockShare.votedProposalIds[i] != proposalId, "already voted");
    }

    lockShare.votedProposalIds.push(proposalId);
    if (support) {
      proposal.forVotingPower = proposal.forVotingPower.add(lockShare.votingPower);
    } else {
      proposal.againstVotingPower = proposal.againstVotingPower.add(lockShare.votingPower);
    }

    emit ProposalVoted(proposalId, voter, support, shareContract, lockShare.amount, lockShare.votingPower);
  }

  function _voteForPoll(address voter, uint256 pollId, bool support, address shareContract) internal {
    require(pollState(pollId) == ProposalState.Active, "vote not active");

    LockShare storage lockShare = lockShareMap[voter][shareContract];
    Poll storage poll = polls[pollId];

    for (uint256 i = 0; i < lockShare.votedPollIds.length; i++) {
      require(lockShare.votedPollIds[i] != pollId, "already voted");
    }

    lockShare.votedPollIds.push(pollId);
    if (support) {
      poll.forVotingPower = poll.forVotingPower.add(lockShare.votingPower);
    } else {
      poll.againstVotingPower = poll.againstVotingPower.add(lockShare.votingPower);
    }

    emit PollVoted(pollId, voter, support, shareContract, lockShare.amount, lockShare.votingPower);
  }

  function _paramInit() internal {
    if (votingPeriod == 0) {
      votingPeriod = INIT_VOTING_PERIOD;
    }
    if (pollVotingPeriod == 0) {
      pollVotingPeriod = INIT_POLL_VOTING_PERIOD;
    }
    if (executionDelay == 0) {
      executionDelay = INIT_EXECUTION_DELAY;
    }
    if (executionExpiration == 0) {
      executionExpiration = INIT_EXECUTION_EXPIRATION;
    }
    if (quorumVotingPower == 0) {
      quorumVotingPower = INIT_QUORUM_VOTING_POWER;
    }
    if (pollSubmitThreshold == 0) {
      pollSubmitThreshold = INIT_POLL_SUBMIT_THRESHOLD;
    }
    if (executeSupportRate == 0) {
      executeSupportRate = INIT_PROPOSAL_EXECUTE_SUPPORT_RATE;
    }
  }

  function proposalState(uint256 proposalId) public view returns (ProposalState) {
    require(proposalId < proposalLength(), "invalid proposal id");
    ParamProposal storage proposal = paramProposals[proposalId];

    uint256 totalVotingPower = proposal.forVotingPower + proposal.againstVotingPower;
    uint256 executionVotingPowerThreshold = totalVotingPower.mul(executeSupportRate).div(PROPOSAL_EXECUTE_SUPPORT_RATE_SCALE);

    if (proposal.canceled) {
      return ProposalState.Canceled;
    } else if (block.timestamp <= proposal.startAt) {
      return ProposalState.Pending;
    } else if (block.timestamp <= proposal.endAt) {
      return ProposalState.Active;
    } else if (proposal.forVotingPower <= executionVotingPowerThreshold ||  totalVotingPower < quorumVotingPower) {
      return ProposalState.Defeated;
    } else if (proposal.executed) {
      return ProposalState.Executed;
    } else if (block.timestamp >= proposal.endAt.add(executionDelay).add(executionExpiration)) {
      return ProposalState.Expired;
    } else if (block.timestamp >= proposal.endAt.add(executionDelay)) {
      return ProposalState.AwaitingExecution;
    } else {
      return ProposalState.Timelocked;
    }
  }

  function pollState(uint256 pollId) public view returns (ProposalState) {
    require(pollId < pollLength(), "invalid poll id");
    Poll storage poll = polls[pollId];

    if (block.timestamp <= poll.startAt) {
      return ProposalState.Pending;
    } else if (block.timestamp <= poll.endAt) {
      return ProposalState.Active;
    } else if (poll.forVotingPower <= poll.againstVotingPower || poll.forVotingPower + poll.againstVotingPower < quorumVotingPower) {
      return ProposalState.Defeated;
    } else {
      return ProposalState.AwaitingExecution;
    }
  }

  function proposalLength() public view returns (uint256) {
    return paramProposals.length;
  }

  function pollLength() public view returns (uint256) {
    return polls.length;
  }
}
