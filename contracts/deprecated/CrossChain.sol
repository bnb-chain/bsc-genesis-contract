pragma solidity 0.6.4;

import "../interface/0.6.x/IApplication.sol";
import "../interface/0.6.x/ICrossChain.sol";
import "../interface/0.6.x/ITokenHub.sol";
import "../interface/0.6.x/ILightClient.sol";
import "../interface/0.6.x/IRelayerIncentivize.sol";
import "../interface/0.6.x/IRelayerHub.sol";
import "../interface/0.6.x/IBSCValidatorSetV2.sol";
import "../lib/0.6.x/Memory.sol";
import "../lib/0.6.x/BytesToTypes.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../System.sol";
import "../lib/0.6.x/MerkleProof.sol";

contract CrossChain is System, ICrossChain, IParamSubscriber {
    // constant variables
    string public constant STORE_NAME = "ibc";
    uint256 public constant CROSS_CHAIN_KEY_PREFIX = 0x01003800; // last 6 bytes
    uint8 public constant SYN_PACKAGE = 0x00;
    uint8 public constant ACK_PACKAGE = 0x01;
    uint8 public constant FAIL_ACK_PACKAGE = 0x02;
    uint256 public constant INIT_BATCH_SIZE = 50;

    // governable parameters
    uint256 public batchSizeForOracle;

    //state variables
    uint256 public previousTxHeight;
    uint256 public txCounter;
    int64 public oracleSequence;
    mapping(uint8 => address) public channelHandlerContractMap;
    mapping(address => mapping(uint8 => bool)) public registeredContractChannelMap;
    mapping(uint8 => uint64) public channelSendSequenceMap;
    mapping(uint8 => uint64) public channelReceiveSequenceMap;
    mapping(uint8 => bool) public isRelayRewardFromSystemReward;

    // to prevent the utilization of ancient block header
    mapping(uint8 => uint64) public channelSyncedHeaderMap;

    // BEP-171: Security Enhancement for Cross-Chain Module
    // 0xebbda044f67428d7e9b472f9124983082bcda4f84f5148ca0a9ccbe06350f196
    bytes32 public constant SUSPEND_PROPOSAL = keccak256("SUSPEND_PROPOSAL");
    // 0xcf82004e82990eca84a75e16ba08aa620238e076e0bc7fc4c641df44bbf5b55a
    bytes32 public constant REOPEN_PROPOSAL = keccak256("REOPEN_PROPOSAL");
    // 0x605b57daa79220f76a5cdc8f5ee40e59093f21a4e1cec30b9b99c555e94c75b9
    bytes32 public constant CANCEL_TRANSFER_PROPOSAL = keccak256("CANCEL_TRANSFER_PROPOSAL");
    // 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    bytes32 public constant EMPTY_CONTENT_HASH = keccak256("");
    uint16 public constant INIT_SUSPEND_QUORUM = 1;
    uint16 public constant INIT_REOPEN_QUORUM = 2;
    uint16 public constant INIT_CANCEL_TRANSFER_QUORUM = 2;
    uint256 public constant EMERGENCY_PROPOSAL_EXPIRE_PERIOD = 1 hours;

    bool public isSuspended;
    // proposal type hash => latest emergency proposal
    mapping(bytes32 => EmergencyProposal) public emergencyProposals;
    // proposal type hash => the threshold of proposal approved
    mapping(bytes32 => uint16) public quorumMap;
    // IAVL key hash => is challenged
    mapping(bytes32 => bool) public challenged;

    // struct
    // BEP-171: Security Enhancement for Cross-Chain Module
    struct EmergencyProposal {
        uint16 quorum;
        uint128 expiredAt;
        bytes32 contentHash;
        address[] approvers;
    }

    // event
    event crossChainPackage(
        uint16 chainId,
        uint64 indexed oracleSequence,
        uint64 indexed packageSequence,
        uint8 indexed channelId,
        bytes payload
    );
    event receivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
    event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
    event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
    event paramChange(string key, bytes value);
    event enableOrDisableChannel(uint8 indexed channelId, bool isEnable);
    event addChannel(uint8 indexed channelId, address indexed contractAddr);

    // BEP-171: Security Enhancement for Cross-Chain Module
    event ProposalSubmitted(
        bytes32 indexed proposalTypeHash,
        address indexed proposer,
        uint128 quorum,
        uint128 expiredAt,
        bytes32 contentHash
    );
    event Suspended(address indexed executor);
    event Reopened(address indexed executor);
    event SuccessChallenge(address indexed challenger, uint64 packageSequence, uint8 channelId);

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

    function encodePayload(
        uint8 packageType,
        uint256 relayFee,
        bytes memory msgBytes
    ) public pure returns (bytes memory) {
        uint256 payloadLength = msgBytes.length + 33;
        bytes memory payload = new bytes(payloadLength);
        uint256 ptr;
        assembly {
            ptr := payload
        }
        ptr += 33;

        assembly {
            mstore(ptr, relayFee)
        }

        ptr -= 32;
        assembly {
            mstore(ptr, packageType)
        }

        ptr -= 1;
        assembly {
            mstore(ptr, payloadLength)
        }

        ptr += 65;
        (uint256 src,) = Memory.fromBytes(msgBytes);
        Memory.copy(src, ptr, msgBytes.length);

        return payload;
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
