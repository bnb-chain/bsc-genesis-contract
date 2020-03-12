pragma solidity 0.5.16;

import "Memory.sol";
import "ITendermintLightClient.sol";
import "ISystemReward.sol";

contract TendermintLightClient is ITendermintLightClient {

    struct ConsensusState {
        uint64  preValidatorSetChangeHeight;
        bytes32 appHash;
        bytes32 curValidatorSetHash;
        bytes   nextValidatorSet;
    }

    mapping(uint64 => ConsensusState) public _BBCLightClientConsensusState;
    mapping(uint64 => address payable) public _submitters;
    address public _systemRewardContract;
    string public _chainID;
    uint64 public _initialHeight;
    uint64 public _latestHeight;
    bool public _alreadyInit;

    event InitConsensusState(uint64 initHeight, bytes32 appHash, string _chainID);
    event SyncConsensusState(uint64 height, uint64 preValidatorSetChangeHeight, bytes32 appHash, bool validatorChanged);

    constructor() public {

    }

    modifier onlyNotInit() {
        require(!_alreadyInit, "the contract already init");
        _;
    }

    modifier onlyAlreadyInit() {
        require(_alreadyInit, "the contract not init yet");
        _;
    }

    //TODO add authority check
    function initConsensusState(bytes memory initConsensusStateBytes, string memory chain_id, address systemRewardContractAddr) public {
        uint256 pointer;
        uint256 length;
        (pointer, length) = Memory.fromBytes(initConsensusStateBytes);

        ConsensusState memory cs;
        uint64 height;
        (cs, height) = decodeConsensusState(pointer, length, false);
        cs.preValidatorSetChangeHeight = 0;
        _BBCLightClientConsensusState[height] = cs;

        _initialHeight = height;
        _latestHeight = height;
        _chainID = chain_id;
        _systemRewardContract=systemRewardContractAddr;

        emit InitConsensusState(_initialHeight, cs.appHash, chain_id);
    }

    function syncTendermintHeader(bytes calldata header, uint64 height) external returns (bool) {
        require(_submitters[height] == address(0x0), "can't sync duplicated header");
        require(height > _initialHeight, "can't sync header before _initialHeight");

        uint64 preValidatorSetChangeHeight = _latestHeight;
        ConsensusState memory cs = _BBCLightClientConsensusState[preValidatorSetChangeHeight];
        for(; preValidatorSetChangeHeight >= _initialHeight;) {
            if (preValidatorSetChangeHeight < height) {
                // find nearest previous height
                break;
            }
            preValidatorSetChangeHeight = cs.preValidatorSetChangeHeight;
            cs = _BBCLightClientConsensusState[preValidatorSetChangeHeight];
        }
        if (cs.nextValidatorSet.length == 0) {
            preValidatorSetChangeHeight = cs.preValidatorSetChangeHeight;
            cs.nextValidatorSet = _BBCLightClientConsensusState[preValidatorSetChangeHeight].nextValidatorSet;
            require(cs.nextValidatorSet.length != 0, "failed to load validator set data");
        }

        //32 + 32 + 8 + 32 + 32 + cs.nextValidatorSet.length;
        uint256 length = 136 + cs.nextValidatorSet.length;
        bytes memory input = new bytes(length+header.length);
        uint256 ptr = Memory.dataPtr(input);
        require(serializeConsensusState(cs, preValidatorSetChangeHeight, ptr, length));

        // write header to input
        uint256 src;
        ptr=ptr+length;
        (src, length) = Memory.fromBytes(header);
        Memory.copy(src, ptr, length);

        length = input.length+32;
        // Maximum validator quantity is 99
        bytes32[128] memory result;
        assembly {
        // call validateTendermintHeader precompile contract
        // Contract address: 0x64
            if iszero(staticcall(not(0), 0x64, input, length, result, 4096)) {
                revert(0, 0)
            }
        }

        //Judge if the validator set is changed
        assembly {
            length := mload(add(result, 0))
        }
        bool validatorChanged=false;
        if ((length&0x0100000000000000000000000000000000000000000000000000000000000000)!=0x00) {
            validatorChanged=true;
            ISystemReward(_systemRewardContract).claimRewards(msg.sender, 100000);//TODO further discussion about reward amount
        }
        length = length&0x000000000000000000000000000000000000000000000000ffffffffffffffff;

        assembly {
            ptr := add(result, 32)
        }

        uint64 actualHeaderHeight;
        (cs, actualHeaderHeight) = decodeConsensusState(ptr, length, !validatorChanged);
        require(actualHeaderHeight == height, "header height doesn't equal to the specified height");

        _submitters[height] = msg.sender;
        cs.preValidatorSetChangeHeight = preValidatorSetChangeHeight;
        _BBCLightClientConsensusState[height] = cs;
        if (height > _latestHeight) {
            _latestHeight = height;
        }

        emit SyncConsensusState(height, preValidatorSetChangeHeight, cs.appHash, validatorChanged);

        return true;
    }

    function isHeaderSynced(uint64 height) external view returns (bool) {
        return _submitters[height] != address(0x0);
    }

    function getAppHash(uint64 height) external view returns (bytes32) {
        return _BBCLightClientConsensusState[height].appHash;
    }

    function getSubmitter(uint64 height) external view returns (address payable) {
        return _submitters[height];
    }

    // | length   | _chainID   | height   | appHash  | curValidatorSetHash | [{validator pubkey, voting power}] |
    // | 32 bytes | 32 bytes   | 8 bytes  | 32 bytes | 32 bytes            | [{32 bytes, 8 bytes}]              |
    function serializeConsensusState(ConsensusState memory cs, uint64 height, uint256 outputPtr, uint256 size) internal view returns (bool) {
        uint256 validatorQuantity = cs.nextValidatorSet.length/40;

        outputPtr = outputPtr + size - 40 * validatorQuantity;

        uint256 src;
        uint256 length;
        (src, length) = Memory.fromBytes(cs.nextValidatorSet);
        Memory.copy(src, outputPtr, length);
        outputPtr=outputPtr-32;

        bytes32 hash = cs.curValidatorSetHash;
        assembly {
            mstore(outputPtr, hash)
        }
        outputPtr=outputPtr-32;

        hash = cs.appHash;
        assembly {
            mstore(outputPtr, hash)
        }
        outputPtr=outputPtr-32;

        assembly {
            mstore(outputPtr, height)
        }
        outputPtr=outputPtr-8;

        bytes memory chainIDBytes = bytes(_chainID);
        assembly {
            mstore(outputPtr, mload(add(chainIDBytes, 32)))
        }
        outputPtr=outputPtr-32;

        // size doesn't contain length
        size=size-32;
        assembly {
            mstore(outputPtr, size)
        }

        return true;
    }

    // | _chainID  | height   | appHash  | curValidatorSetHash | [{validator pubkey, voting power}] |
    // | 32 bytes  | 8 bytes  | 32 bytes | 32 bytes            | [{32 bytes, 8 bytes}]              |
    function decodeConsensusState(uint256 ptr, uint256 size, bool leaveOutValidatorSet) internal pure returns(ConsensusState memory, uint64) {
        // 104 = 32 +32 +8 + 32 +32
        uint256 validatorSetLength = (size-104)/40;

        ptr=ptr+8;
        uint64 height;
        assembly {
            height := mload(ptr)
        }

        ptr=ptr+32;
        bytes32 appHash;
        assembly {
            appHash := mload(ptr)
        }

        ptr=ptr+32;
        bytes32 curValidatorSetHash;
        assembly {
            curValidatorSetHash := mload(ptr)
        }

        ConsensusState memory cs;
        cs.appHash = appHash;
        cs.curValidatorSetHash = curValidatorSetHash;

        if (!leaveOutValidatorSet) {
            uint256 dest;
            uint256 length;
            cs.nextValidatorSet = new bytes(40*validatorSetLength);
            (dest,length) = Memory.fromBytes(cs.nextValidatorSet);

            Memory.copy(ptr+32, dest, length);
        }

        return (cs, height);
    }
}