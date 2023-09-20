pragma solidity 0.8.0;

interface IGovHub {
  function updateParam(string calldata key, bytes calldata value, address target) external;
}

interface IShare {
  function lockToGovernance(address from, uint256 shareAmount) external;
  function unlockFromGovernance(address to, uint256 shareAmount) external;
}

interface IStakeHub {
  function getVotingPower(address shareContract, uint256 shareAmount) external returns (uint256 votingPower);
}

interface IBSCValidatorSet {
  function currentValidatorSetMap(address validator) external view returns(uint256);
  function numOfCabinets() external view returns(uint256);
}


contract System {
  bool public alreadyInit;
  address public constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
  address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
  address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
  address public constant LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
  address public constant TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
  address public constant INCENTIVIZE_ADDR=0x0000000000000000000000000000000000001005;
  address public constant RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
  address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
  address public constant TOKEN_MANAGER_ADDR = 0x0000000000000000000000000000000000001008;
  address public constant CROSS_CHAIN_CONTRACT_ADDR = 0x0000000000000000000000000000000000002000;
  address public constant STAKING_CONTRACT_ADDR = 0x0000000000000000000000000000000000002001;
  address public constant STAKE_HUB_ADDR = 0x0000000000000000000000000000000000002002;
  address public constant GOVERNANCE_ADDR = 0x0000000000000000000000000000000000002003;

  modifier onlyNotInit() {
    require(!alreadyInit, "the contract already init");
    _;
  }

  modifier onlyInit() {
    require(alreadyInit, "the contract not init yet");
    _;
  }

  modifier onlyGov() {
    require(msg.sender == GOV_HUB_ADDR, "the message sender must be governance contract");
    _;
  }

  modifier onlyGovernance() {
    require(msg.sender == GOVERNANCE_ADDR, "the message sender must be governance v2 contract");
    _;
  }

  modifier onlyValidatorContract() {
    require(msg.sender == VALIDATOR_CONTRACT_ADDR, "the message sender must be validatorSet contract");
    _;
  }

  function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function _bytesToUint256(uint _offst, bytes memory _input) internal pure returns (uint256 _output) {
    assembly {
      _output := mload(add(_input, _offst))
    }
  }
}


// TODO: add IGovernance extend
contract Governance is System {
  uint256 public constant INIT_VOTING_PERIOD = 1 weeks;
  uint256 public constant INIT_POLL_VOTING_PERIOD = 2 weeks;
  uint256 public constant INIT_EXECUTION_DELAY = 1 days;
  uint256 public constant INIT_EXECUTION_EXPIRATION = 3 days;
  uint256 public constant INIT_QUORUM_VOTING_POWER = 1e7 ether;
  uint256 public constant INIT_POLL_SUBMIT_THRESHOLD = 50 ether;
  uint256 public constant INIT_MIN_EXECUTE_SUPPORT_RATE = 50;
  uint256 public constant PROPOSAL_EXECUTE_SUPPORT_RATE_SCALE = 100;

  // locker => share contract => LockShare
  mapping(address => mapping(address => ShareLock)) private lockShareMap;

  Vote[] public votes;
  // for proposal
  ParamChangeRequest[] public paramChangeRequests;
  Proposal[] public proposals;

  uint256 public votingPeriod;
  uint256 public executionDelay;
  uint256 public executionExpiration;
  uint256 public quorumVotingPower;
  uint256 public minExecutableSupportRate;

  // for poll
  Poll[] public polls;
  uint256 public pollVotingPeriod;
  uint256 public pollSubmitThreshold;

  enum ProposalState { Pending, Active, Defeated, Canceled, Timelocked, AwaitingExecution, Executed, Expired }
  struct ParamChangeRequest {
    string key;
    bytes value;
    address target;
  }

  struct Vote {
    address voter;
    uint256 votingPower;
    bool support;
  }

  struct Proposal {
    uint256[] requestIds;
    uint256[] voteIds;

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
    uint256[] voteIds;

    address proposer;
    string description;

    // vote starts at
    uint256 startAt;
    // vote ends at
    uint256 endAt;
    uint256 forVotingPower;
    uint256 againstVotingPower;
  }

  struct ShareLock {
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
    uint256 indexPlus = IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).currentValidatorSetMap(msg.sender);
    uint256 numOfCabinets = IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).numOfCabinets();
    if (numOfCabinets == 0) {
      numOfCabinets = 21;
    }

    require(indexPlus > 0 && indexPlus <= numOfCabinets, "not cabinet");
    _;
  }

  function submitProposal(ParamChangeRequest[] memory requests, string memory _description, uint256 voteAt) public onlyCabinet {
    _paramInit();

    require(voteAt == 0 || voteAt >= block.timestamp, "invalid voteAt");
    if (voteAt == 0) {
      voteAt = block.timestamp;
    }

    uint256 totalRequests = requests.length;
    require(totalRequests > 0, "empty param change request");
    uint256 endAt = voteAt + votingPeriod;

    Proposal memory proposal;
    uint256[] memory requestIds = new uint256[](totalRequests);
    uint256[] memory voteIds = new uint256[](totalRequests);

    for (uint256 i = 0; i < totalRequests; i++) {
      paramChangeRequests.push(requests[i]);
      requestIds[i] = requests.length - 1;
    }

    proposal.requestIds = requestIds;
    proposal.voteIds = voteIds;
    proposal.proposer = msg.sender;
    proposal.description = _description;
    proposal.startAt = voteAt;
    proposal.endAt = endAt;

    proposals.push(proposal);

    emit ProposalCreated(proposals.length - 1, msg.sender, _description, voteAt, endAt);
  }

  function cancelProposal(uint256 proposalId) external {
    _paramInit();

    Proposal storage proposal = proposals[proposalId];
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

    Proposal storage proposal = proposals[proposalId];
    proposal.executed = true;

    ParamChangeRequest memory request;
    for (uint256 i = 0; i < proposal.requestIds.length; i++) {
      request = paramChangeRequests[proposal.requestIds[i]];
      IGovHub(GOV_HUB_ADDR).updateParam(request.key, request.value, request.target);
    }

    emit ProposalExecuted(proposalId, msg.sender);
  }

  function submitPoll(string calldata description, uint256 voteAt, address shareContract) external {
    _paramInit();
    address proposer = msg.sender;
    ShareLock memory lock = lockShareMap[proposer][shareContract];
    require(lock.votingPower >= pollSubmitThreshold, "locked voting power not enough");

    require(voteAt == 0 || voteAt >= block.timestamp, "invalid voteAt");
    if (voteAt == 0) {
      voteAt = block.timestamp;
    }

    uint256 endAt = voteAt + pollVotingPeriod;
    Poll memory poll;
    poll.proposer = proposer;
    poll.description = description;
    poll.startAt = voteAt;
    poll.endAt = endAt;

    polls.push(poll);

    emit PollCreated(polls.length - 1, msg.sender, description, voteAt, endAt);
  }

  function lockShare(address shareContract, uint256 shareAmount) external {
    uint256 votingPower = IStakeHub(STAKE_HUB_ADDR).getVotingPower(shareContract, shareAmount);
    require(votingPower > 0, "no votingPower");

    address voter = msg.sender;
    ShareLock storage lock = lockShareMap[voter][shareContract];
    require(lock.votedProposalIds.length == 0, "still voting");

    IShare(shareContract).lockToGovernance(voter, shareAmount);
    lock.amount = lock.amount + shareAmount;
    lock.votingPower = IStakeHub(STAKE_HUB_ADDR).getVotingPower(shareContract, lock.amount);
  }

  function unlockShare(address shareContract, uint256 shareAmount) external {
    address voter = msg.sender;
    ShareLock storage lock = lockShareMap[voter][shareContract];
    require(shareAmount > 0 && shareAmount <= lock.amount, "invalid share amount");

    if (lock.votedProposalIds.length > 0) {
      ProposalState _state;
      for (uint256 i = 0; i < lock.votedProposalIds.length; i++) {
        _state = proposalState(lock.votedProposalIds[i]);
        require(_state != ProposalState.Pending && _state != ProposalState.Active, "vote not ended");
      }
      delete lock.votedProposalIds;
    }

    lock.amount = lock.amount - shareAmount;
    lock.votingPower = IStakeHub(STAKE_HUB_ADDR).getVotingPower(shareContract, lock.amount);

    IShare(shareContract).unlockFromGovernance(voter, shareAmount);
  }

  function castVote(bool isProposal, uint256 id, bool support, address shareContract) external {
    address voter = msg.sender;
    uint256 votingPower = lockShareMap[voter][shareContract].votingPower;
    require(votingPower > 0, "zero votingPower");
    Vote memory v = Vote(voter, votingPower, support);
    votes.push(v);

    if (isProposal) {
      _voteForProposal(voter, id, support, shareContract);
    } else {
      _voteForPoll(voter, id, support, shareContract);
    }
  }

  function updateParam(string calldata key, bytes calldata value) external onlyGov {
    require(value.length == 32, "expected value length is 32");

    if (_compareStrings(key, "votingPeriod")) {
      uint256 newVotingPeriod = _bytesToUint256(32, value);
      require(newVotingPeriod > 0 && newVotingPeriod <= 10 weeks, "invalid new votingPeriod");
      votingPeriod = newVotingPeriod;
    } else if (_compareStrings(key, "pollVotingPeriod")) {
      uint256 newPollVotingPeriod = _bytesToUint256(32, value);
      require(newPollVotingPeriod > 1 weeks && newPollVotingPeriod <= 10 weeks, "invalid new pollVotingPeriod");
      pollVotingPeriod = newPollVotingPeriod;
    } else if (_compareStrings(key, "executionDelay")) {
      uint256 newExecutionDelay = _bytesToUint256(32, value);
      require(newExecutionDelay > 0 && newExecutionDelay <= 7 days, "invalid new executionDelay");
      executionDelay = newExecutionDelay;
    } else if (_compareStrings(key, "executionExpiration")) {
      uint256 newExecutionExpiration = _bytesToUint256(32, value);
      require(newExecutionExpiration > 0 && newExecutionExpiration <= 7 days, "invalid new executionExpiration");
      executionExpiration = newExecutionExpiration;
    } else if (_compareStrings(key, "quorumVotingPower")) {
      uint256 newQuorumVotingPower = _bytesToUint256(32, value);
      require(newQuorumVotingPower >= 10000 ether && newQuorumVotingPower <= 2e8 ether, "invalid new quorumVotingPower");
      quorumVotingPower = newQuorumVotingPower;
    } else if (_compareStrings(key, "pollSubmitThreshold")) {
      uint256 newPollSubmitThreshold = _bytesToUint256(32, value);
      require(newPollSubmitThreshold >= 10 ether && newPollSubmitThreshold <= 2e8 ether, "invalid new pollSubmitThreshold");
      pollSubmitThreshold = newPollSubmitThreshold;
    } else if (_compareStrings(key, "minExecutableSupportRate")) {
      uint256 newMinExecutableSupportRate = _bytesToUint256(32, value);
      require(newMinExecutableSupportRate >= 50 && newMinExecutableSupportRate <= 100, "invalid new minExecutableSupportRate");
      minExecutableSupportRate = newMinExecutableSupportRate;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  function _voteForProposal(address voter, uint256 proposalId, bool support, address shareContract) internal {
    require(proposalState(proposalId) == ProposalState.Active, "vote not active");

    ShareLock storage lock = lockShareMap[voter][shareContract];
    Proposal storage proposal = proposals[proposalId];

    for (uint256 i = 0; i < lock.votedProposalIds.length; i++) {
      require(lock.votedProposalIds[i] != proposalId, "already voted");
    }

    lock.votedProposalIds.push(proposalId);

    proposal.voteIds.push(votes.length - 1);
    if (support) {
      proposal.forVotingPower = proposal.forVotingPower + lock.votingPower;
    } else {
      proposal.againstVotingPower = proposal.againstVotingPower + lock.votingPower;
    }

    emit ProposalVoted(proposalId, voter, support, shareContract, lock.amount, lock.votingPower);
  }

  function _voteForPoll(address voter, uint256 pollId, bool support, address shareContract) internal {
    require(pollState(pollId) == ProposalState.Active, "vote not active");

    ShareLock storage lock = lockShareMap[voter][shareContract];
    Poll storage poll = polls[pollId];

    for (uint256 i = 0; i < lock.votedPollIds.length; i++) {
      require(lock.votedPollIds[i] != pollId, "already voted");
    }

    lock.votedPollIds.push(pollId);

    poll.voteIds.push(votes.length - 1);
    if (support) {
      poll.forVotingPower = poll.forVotingPower + lock.votingPower;
    } else {
      poll.againstVotingPower = poll.againstVotingPower + lock.votingPower;
    }

    emit PollVoted(pollId, voter, support, shareContract, lock.amount, lock.votingPower);
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
    if (minExecutableSupportRate == 0) {
      minExecutableSupportRate = INIT_MIN_EXECUTE_SUPPORT_RATE;
    }
  }

  function proposalState(uint256 proposalId) public view returns (ProposalState) {
    require(proposalId < proposalLength(), "invalid proposal id");
    Proposal storage proposal = proposals[proposalId];

    uint256 totalVotingPower = proposal.forVotingPower + proposal.againstVotingPower;
    uint256 executionVotingPowerThreshold = totalVotingPower * minExecutableSupportRate / PROPOSAL_EXECUTE_SUPPORT_RATE_SCALE;

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
    } else if (block.timestamp >= proposal.endAt + executionDelay + executionExpiration) {
      return ProposalState.Expired;
    } else if (block.timestamp >= proposal.endAt + executionDelay) {
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
    return proposals.length;
  }

  function pollLength() public view returns (uint256) {
    return polls.length;
  }
}
