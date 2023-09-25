pragma solidity 0.8.0;

interface IGovHub {
  function updateParam(string calldata key, bytes calldata value, address target) external;
}

interface IShare {
  function lockToGovernance(address from, uint256 stBNBAmount) external;
  function unlockFromGovernance(address to, uint256 stBNBAmount) external;
}

interface IStakeHub {
  function getVotingPower(address stBNBContract, uint256 stBNBAmount) external returns (uint256 votingPower);
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
  uint256 public constant INIT_EXECUTABLE_PROPOSAL_SUBMIT_THRESHOLD = 1000 ether;
  uint256 public constant INIT_TEXT_PROPOSAL_SUBMIT_THRESHOLD = 50 ether;
  uint256 public constant INIT_MIN_EXECUTE_SUPPORT_RATE = 50;
  uint256 public constant PROPOSAL_EXECUTE_SUPPORT_RATE_SCALE = 100;

  // locker => stBNB contract => LockShare
  mapping(address => mapping(address => ShareLock)) private lockShareMap;

  // whitelist contract for governance
  mapping(address => bool) public whitelist;

  Vote[] public votes;
  // for proposal
  ProposalTransaction[] public proposalTxs;
  ExecutableProposal[] public executableProposals;

  uint256 public votingPeriod;
  uint256 public executionDelay;
  uint256 public executionExpiration;
  uint256 public quorumVotingPower;
  uint256 public minExecutableSupportRate;
  uint256 public executableProposalThreshold;

  // for poll
  TextProposal[] public textProposals;
  uint256 public textProposalVotingPeriod;
  uint256 public textProposalThreshold;

  enum ProposalState { Pending, Active, Defeated, Canceled, Timelocked, AwaitingExecution, Executed, Expired }
  struct ProposalTransaction {
    string key;
    bytes value;
    address target;
  }

  struct Vote {
    address voter;
    uint256 votingPower;
    bool support;
  }

  struct ExecutableProposal {
    uint256[] txIds;
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

  struct TextProposal {
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

    uint256[] votedExecutableProposalIds;
    uint256[] votedTextProposalIds;
  }

  event ParamChange(string key, bytes value);
  event ProposalCreated(
    uint256 indexed id,

    address indexed proposer,
    string description,
    uint256 startAt,
    uint256 endAt
  );
  event ProposalExecuted(uint256 indexed proposalId, address indexed executor);
  event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool indexed support, address stBNBContract, uint256 stBNBAmount, uint256 votingPower);

  event PollCreated(
    uint256 indexed id,

    address indexed proposer,
    string description,
    uint256 startAt,
    uint256 endAt
  );
  event PollVoted(uint256 indexed proposalId, address indexed voter, bool indexed support, address stBNBContract, uint256 stBNBAmount, uint256 votingPower);

  modifier onlyCabinet() {
    uint256 indexPlus = IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).currentValidatorSetMap(msg.sender);
    uint256 numOfCabinets = IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).numOfCabinets();
    if (numOfCabinets == 0) {
      numOfCabinets = 21;
    }

    require(indexPlus > 0 && indexPlus <= numOfCabinets, "not cabinet");
    _;
  }

  function submitExecutableProposal(ProposalTransaction[] memory _txs, string memory _description, address stBNBContract) public {
    _paramInit();
    address proposer = msg.sender;
    ShareLock memory lock = lockShareMap[proposer][stBNBContract];
    require(lock.votingPower >= executableProposalThreshold, "locked voting power not enough");

    uint256 _voteAt = block.timestamp;
    uint256 totalRequests = _txs.length;
    require(totalRequests > 0, "empty param change request");
    uint256 endAt = _voteAt + votingPeriod;

    ExecutableProposal memory proposal;
    uint256[] memory txIds = new uint256[](totalRequests);

    for (uint256 i = 0; i < totalRequests; i++) {
      require(whitelist[_txs[i].target], "invalid target from proposal transactions");
      proposalTxs.push(_txs[i]);
      txIds[i] = proposalTxs.length - 1;
    }

    proposal.txIds = txIds;
    proposal.proposer = proposer;
    proposal.description = _description;
    proposal.startAt = _voteAt;
    proposal.endAt = endAt;

    executableProposals.push(proposal);

    emit ProposalCreated(executableProposals.length - 1, proposer, _description, _voteAt, endAt);
  }

  function cancelProposal(uint256 proposalId) external {
    _paramInit();

    ExecutableProposal storage proposal = executableProposals[proposalId];
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

    ExecutableProposal storage proposal = executableProposals[proposalId];
    proposal.executed = true;

    ProposalTransaction memory _tx;
    for (uint256 i = 0; i < proposal.txIds.length; i++) {
      _tx = proposalTxs[proposal.txIds[i]];
      IGovHub(GOV_HUB_ADDR).updateParam(_tx.key, _tx.value, _tx.target);
    }

    emit ProposalExecuted(proposalId, msg.sender);
  }

  function submitTextProposal(string calldata description, address stBNBContract) external {
    _paramInit();
    address proposer = msg.sender;
    ShareLock memory lock = lockShareMap[proposer][stBNBContract];
    require(lock.votingPower >= textProposalThreshold, "locked voting power not enough");

    uint256 _voteAt = block.timestamp;
    uint256 endAt = _voteAt + textProposalVotingPeriod;
    TextProposal memory poll;
    poll.proposer = proposer;
    poll.description = description;
    poll.startAt = _voteAt;
    poll.endAt = endAt;

    textProposals.push(poll);

    emit PollCreated(textProposals.length - 1, msg.sender, description, _voteAt, endAt);
  }

  function lockShare(address stBNBContract, uint256 stBNBAmount) external {
    uint256 votingPower = IStakeHub(STAKE_HUB_ADDR).getVotingPower(stBNBContract, stBNBAmount);
    require(votingPower > 0, "no votingPower");

    address voter = msg.sender;
    ShareLock storage lock = lockShareMap[voter][stBNBContract];
    require(lock.votedExecutableProposalIds.length == 0, "still voting");

    IShare(stBNBContract).lockToGovernance(voter, stBNBAmount);
    lock.amount = lock.amount + stBNBAmount;
    lock.votingPower = IStakeHub(STAKE_HUB_ADDR).getVotingPower(stBNBContract, lock.amount);
  }

  function unlockShare(address stBNBContract, uint256 stBNBAmount) external {
    address voter = msg.sender;
    ShareLock storage lock = lockShareMap[voter][stBNBContract];
    require(stBNBAmount > 0 && stBNBAmount <= lock.amount, "invalid stBNB amount");

    if (lock.votedExecutableProposalIds.length > 0) {
      ProposalState _state;
      for (uint256 i = 0; i < lock.votedExecutableProposalIds.length; i++) {
        _state = proposalState(lock.votedExecutableProposalIds[i]);
        require(_state != ProposalState.Pending && _state != ProposalState.Active, "vote not ended");
      }
      delete lock.votedExecutableProposalIds;
    }

    lock.amount = lock.amount - stBNBAmount;
    lock.votingPower = IStakeHub(STAKE_HUB_ADDR).getVotingPower(stBNBContract, lock.amount);

    IShare(stBNBContract).unlockFromGovernance(voter, stBNBAmount);
  }

  function castVote(bool isProposal, uint256 id, bool support, address stBNBContract) external {
    address voter = msg.sender;
    uint256 votingPower = lockShareMap[voter][stBNBContract].votingPower;
    require(votingPower > 0, "zero votingPower");
    Vote memory v = Vote(voter, votingPower, support);
    votes.push(v);

    if (isProposal) {
      _voteForExecutableProposal(voter, id, support, stBNBContract);
    } else {
      _voteForTextProposal(voter, id, support, stBNBContract);
    }
  }

  function updateParam(string calldata key, bytes calldata value) external onlyGov {
    require(value.length == 32, "expected value length is 32");

    if (_compareStrings(key, "votingPeriod")) {
      uint256 newVotingPeriod = _bytesToUint256(32, value);
      require(newVotingPeriod > 0 && newVotingPeriod <= 10 weeks, "invalid new votingPeriod");
      votingPeriod = newVotingPeriod;
    } else if (_compareStrings(key, "textProposalVotingPeriod")) {
      uint256 newTextProposalVotingPeriod = _bytesToUint256(32, value);
      require(newTextProposalVotingPeriod > 1 weeks && newTextProposalVotingPeriod <= 10 weeks, "invalid new textProposalVotingPeriod");
      textProposalVotingPeriod = newTextProposalVotingPeriod;
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
    } else if (_compareStrings(key, "executableProposalThreshold")) {
      uint256 newExecutableProposalThreshold = _bytesToUint256(32, value);
      require(newExecutableProposalThreshold >= 10 ether && newExecutableProposalThreshold <= 2e8 ether, "invalid new executableProposalThreshold");
      executableProposalThreshold = newExecutableProposalThreshold;
    } else if (_compareStrings(key, "textProposalThreshold")) {
      uint256 newTextProposalThreshold = _bytesToUint256(32, value);
      require(newTextProposalThreshold >= 10 ether && newTextProposalThreshold <= 2e8 ether, "invalid new textProposalThreshold");
      textProposalThreshold = newTextProposalThreshold;
    } else if (_compareStrings(key, "minExecutableSupportRate")) {
      uint256 newMinExecutableSupportRate = _bytesToUint256(32, value);
      require(newMinExecutableSupportRate >= 50 && newMinExecutableSupportRate <= 100, "invalid new minExecutableSupportRate");
      minExecutableSupportRate = newMinExecutableSupportRate;
    } else {
      require(false, "unknown param");
    }
    emit ParamChange(key, value);
  }

  function _voteForExecutableProposal(address voter, uint256 proposalId, bool support, address stBNBContract) internal {
    require(proposalState(proposalId) == ProposalState.Active, "vote not active");

    ShareLock storage lock = lockShareMap[voter][stBNBContract];
    ExecutableProposal storage proposal = executableProposals[proposalId];

    for (uint256 i = 0; i < lock.votedExecutableProposalIds.length; i++) {
      require(lock.votedExecutableProposalIds[i] != proposalId, "already voted");
    }

    lock.votedExecutableProposalIds.push(proposalId);

    proposal.voteIds.push(votes.length - 1);
    if (support) {
      proposal.forVotingPower = proposal.forVotingPower + lock.votingPower;
    } else {
      proposal.againstVotingPower = proposal.againstVotingPower + lock.votingPower;
    }

    emit ProposalVoted(proposalId, voter, support, stBNBContract, lock.amount, lock.votingPower);
  }

  function _voteForTextProposal(address voter, uint256 textId, bool support, address stBNBContract) internal {
    require(pollState(textId) == ProposalState.Active, "vote not active");

    ShareLock storage lock = lockShareMap[voter][stBNBContract];
    TextProposal storage proposal = textProposals[textId];

    for (uint256 i = 0; i < lock.votedTextProposalIds.length; i++) {
      require(lock.votedTextProposalIds[i] != textId, "already voted");
    }

    lock.votedTextProposalIds.push(textId);

    proposal.voteIds.push(votes.length - 1);
    if (support) {
      proposal.forVotingPower = proposal.forVotingPower + lock.votingPower;
    } else {
      proposal.againstVotingPower = proposal.againstVotingPower + lock.votingPower;
    }

    emit PollVoted(textId, voter, support, stBNBContract, lock.amount, lock.votingPower);
  }

  function _paramInit() internal {
    if (quorumVotingPower == 0) {
      whitelist[VALIDATOR_CONTRACT_ADDR] = true;
      whitelist[SLASH_CONTRACT_ADDR] = true;
      whitelist[SYSTEM_REWARD_ADDR] = true;
      whitelist[LIGHT_CLIENT_ADDR] = true;
      whitelist[TOKEN_HUB_ADDR] = true;
      whitelist[INCENTIVIZE_ADDR] = true;
      whitelist[RELAYERHUB_CONTRACT_ADDR] = true;
      whitelist[GOV_HUB_ADDR] = true;
      whitelist[TOKEN_MANAGER_ADDR] = true;
      whitelist[CROSS_CHAIN_CONTRACT_ADDR] = true;
      whitelist[STAKING_CONTRACT_ADDR] = true;
      whitelist[STAKE_HUB_ADDR] = true;
      whitelist[GOVERNANCE_ADDR] = true;

      votingPeriod = INIT_VOTING_PERIOD;
      textProposalVotingPeriod = INIT_POLL_VOTING_PERIOD;
      executionDelay = INIT_EXECUTION_DELAY;
      executionExpiration = INIT_EXECUTION_EXPIRATION;
      quorumVotingPower = INIT_QUORUM_VOTING_POWER;
      executableProposalThreshold = INIT_EXECUTABLE_PROPOSAL_SUBMIT_THRESHOLD;
      textProposalThreshold = INIT_TEXT_PROPOSAL_SUBMIT_THRESHOLD;
      minExecutableSupportRate = INIT_MIN_EXECUTE_SUPPORT_RATE;
    }
  }

  function proposalState(uint256 proposalId) public view returns (ProposalState) {
    require(proposalId < proposalLength(), "invalid proposal id");
    ExecutableProposal storage proposal = executableProposals[proposalId];

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
    TextProposal storage poll = textProposals[pollId];

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
    return executableProposals.length;
  }

  function pollLength() public view returns (uint256) {
    return textProposals.length;
  }
}
