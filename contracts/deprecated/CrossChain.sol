pragma solidity 0.6.4;

import "../interface/0.6.x/ICrossChain.sol";
import "../interface/0.6.x/ILightClient.sol";
import "../interface/0.6.x/IBSCValidatorSetV2.sol";
import "../lib/0.6.x/Memory.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../System.sol";

contract CrossChain is System, ICrossChain, IParamSubscriber {
    uint256 public constant INIT_BATCH_SIZE = 50;

    // governable parameters
    uint256 public batchSizeForOracle;  // @dev deprecated

    //state variables
    uint256 public previousTxHeight;
    uint256 public txCounter;
    int64 public oracleSequence;
    mapping(uint8 => address) public channelHandlerContractMap;
    mapping(address => mapping(uint8 => bool)) public registeredContractChannelMap;
    mapping(uint8 => uint64) public channelSendSequenceMap;  // @dev deprecated
    mapping(uint8 => uint64) public channelReceiveSequenceMap;
    mapping(uint8 => bool) public isRelayRewardFromSystemReward;  // @dev deprecated

    // to prevent the utilization of ancient block header
    mapping(uint8 => uint64) public channelSyncedHeaderMap;

    bool public isSuspended;
    // proposal type hash => latest emergency proposal
    mapping(bytes32 => EmergencyProposal) public emergencyProposals;  // @dev deprecated
    // proposal type hash => the threshold of proposal approved
    mapping(bytes32 => uint16) public quorumMap;  // @dev deprecated
    // IAVL key hash => is challenged
    mapping(bytes32 => bool) public challenged;  // @dev deprecated

    // struct
    // BEP-171: Security Enhancement for Cross-Chain Module
    // @dev deprecated
    struct EmergencyProposal {
        uint16 quorum;
        uint128 expiredAt;
        bytes32 contentHash;
        address[] approvers;
    }

    // event
    // @dev deprecated
    event crossChainPackage(
        uint16 chainId,
        uint64 indexed oracleSequence,
        uint64 indexed packageSequence,
        uint8 indexed channelId,
        bytes payload
    );
    event receivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);  // @dev deprecated
    event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);  // @dev deprecated
    event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);  // @dev deprecated
    event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);  // @dev deprecated
    event paramChange(string key, bytes value);  // @dev deprecated
    event enableOrDisableChannel(uint8 indexed channelId, bool isEnable);  // @dev deprecated
    event addChannel(uint8 indexed channelId, address indexed contractAddr);  // @dev deprecated

    // BEP-171: Security Enhancement for Cross-Chain Module
    // @dev deprecated
    event ProposalSubmitted(
        bytes32 indexed proposalTypeHash,
        address indexed proposer,
        uint128 quorum,
        uint128 expiredAt,
        bytes32 contentHash
    );
    event Suspended(address indexed executor);  // @dev deprecated
    event Reopened(address indexed executor);  // @dev deprecated
    event SuccessChallenge(address indexed challenger, uint64 packageSequence, uint8 channelId);  // @dev deprecated

    modifier sequenceInOrder(uint64 _sequence, uint8 _channelID) {
        uint64 expectedSequence = channelReceiveSequenceMap[_channelID];
        require(_sequence == expectedSequence, "sequence not in order");

        channelReceiveSequenceMap[_channelID] = expectedSequence + 1;
        _;
    }

    modifier blockSynced(uint64 _height) {
        require(ILightClient(LIGHT_CLIENT_ADDR).isHeaderSynced(_height), "light client not sync the block yet");
        _;
    }

    modifier channelSupported(uint8 _channelID) {
        require(channelHandlerContractMap[_channelID] != address(0x0), "channel is not supported");
        _;
    }

    modifier onlyRegisteredContractChannel(uint8 channleId) {
        require(
            registeredContractChannelMap[msg.sender][channleId], "the contract and channel have not been registered"
        );
        _;
    }

    modifier headerInOrder(uint64 height, uint8 channelId) {
        require(height >= channelSyncedHeaderMap[channelId], "too old header");
        if (height != channelSyncedHeaderMap[channelId]) {
            channelSyncedHeaderMap[channelId] = height;
        }
        _;
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    modifier onlyCabinet() {
        uint256 indexPlus = IBSCValidatorSetV2(VALIDATOR_CONTRACT_ADDR).currentValidatorSetMap(msg.sender);
        uint256 numOfCabinets = IBSCValidatorSetV2(VALIDATOR_CONTRACT_ADDR).numOfCabinets();
        if (numOfCabinets == 0) {
            numOfCabinets = 21;
        }

        require(indexPlus > 0 && indexPlus <= numOfCabinets, "not cabinet");
        _;
    }

    modifier whenNotSuspended() {
        require(!isSuspended, "suspended");
        _;
    }

    modifier whenSuspended() {
        require(isSuspended, "not suspended");
        _;
    }

    function init() external onlyNotInit {
        batchSizeForOracle = INIT_BATCH_SIZE;

        oracleSequence = -1;
        previousTxHeight = 0;
        txCounter = 0;

        alreadyInit = true;
    }

    function handlePackage(
        bytes calldata payload,
        bytes calldata proof,
        uint64 height,
        uint64 packageSequence,
        uint8 channelId
    )
        external
        onlyInit
        onlyRelayer
        sequenceInOrder(packageSequence, channelId)
        blockSynced(height)
        channelSupported(channelId)
        headerInOrder(height, channelId)
        whenNotSuspended
    {
        revert("deprecated");
    }

    function sendSynPackage(
        uint8 channelId,
        bytes calldata msgBytes,
        uint256 relayFee
    ) external override onlyInit onlyRegisteredContractChannel(channelId) {
        revert("deprecated");
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyGov whenNotSuspended {
        revert("deprecated");
    }

    // BEP-171: Security Enhancement for Cross-Chain Module
    function challenge(
        // to avoid stack too deep error, using `uint64[4] calldata params`
        // instead of  `uint64 height0, uint64 height1, uint64 packageSequence, uint8 channelId`
        uint64[4] calldata params, // 0-height0, 1-height1, 2-packageSequence, 3-channelId,
        bytes calldata payload0,
        bytes calldata payload1,
        bytes calldata proof0,
        bytes calldata proof1
    )
        external
        onlyInit
        blockSynced(params[0])
        blockSynced(params[1])
        channelSupported(uint8(params[3]))
        whenNotSuspended
    {
        revert("deprecated");
    }

    function suspend() external onlyInit onlyCabinet whenNotSuspended {
        revert("deprecated");
    }

    function reopen() external onlyInit onlyCabinet whenSuspended {
        revert("deprecated");
    }

    function cancelTransfer(address tokenAddr, address attacker) external onlyInit onlyCabinet {
        revert("deprecated");
    }
}
