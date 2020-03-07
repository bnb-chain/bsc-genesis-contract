pragma solidity 0.5.16;

import "Memory.sol";
import "BytesToTypes.sol";
import "ITendermintLightClient.sol";
import "ISystemReward.sol";

contract TendermintLightClient is ITendermintLightClient {

    struct ConsensusState {
        uint64  preHeight;
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
    bool public _alreadyInit=false;

    event InitConsensusState(uint64 initHeight, bytes32 appHash, uint256 validatorQuantity, string _chainID);
    event SyncConsensusState(uint64 height, uint64 preHeight, uint64 nextHeight, bytes32 appHash, bool validatorChanged);

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
        ConsensusState memory cs;
        uint64 height;

        (cs, height) = decodeConsensusState(initConsensusStateBytes);
        cs.preHeight = 0;
        _BBCLightClientConsensusState[height] = cs;

        _initialHeight = height;
        _latestHeight = height;
        _chainID = chain_id;
        _systemRewardContract=systemRewardContractAddr;

        emit InitConsensusState(_initialHeight, cs.appHash, cs.nextValidatorSet.length/40, chain_id);
    }

    function syncTendermintHeader(bytes memory header, uint64 height) public returns (bool) {
        uint64 preHeight = _latestHeight;
        uint64 nextHeight = 0xffffffffffffffff;
        ConsensusState memory cs = _BBCLightClientConsensusState[preHeight];
        for(; preHeight > 0;) {
            if (preHeight == height) {
                // target header is already existing.
                return true;
            }
            if (preHeight < height) {
                // find nearest previous height
                break;
            }
            cs = _BBCLightClientConsensusState[preHeight];
            nextHeight = preHeight;
            preHeight = cs.preHeight;
        }

        //32 + 32 + 8 + 32 + 32 + cs.nextValidatorSet.length;
        uint256 length = 136 + cs.nextValidatorSet.length;
        bytes memory input = new bytes(length+header.length);
        uint256 ptr = Memory.dataPtr(input);
        require(serializeConsensusState(cs, preHeight, ptr, length));

        // write header to input
        uint256 src;
        ptr=ptr+length;
        (src, length) = Memory.fromBytes(header);
        Memory.copy(src, ptr, length);

        length = input.length+32;
        bytes32[32] memory result;
        assembly {
        // call validateTendermintHeader precompile contract
        // Contract address: 0x64
            if iszero(staticcall(not(0), 0x64, input, length, result, 1024)) {
                revert(0, 0)
            }
        }

        assembly {
            length := mload(add(result, 0))
        }
        //Judge if there are validator set change
        bool validatorChanged=false;
        if ((length&0x0100000000000000000000000000000000000000000000000000000000000000)!=0x00) {
            validatorChanged=true;
            ISystemReward(_systemRewardContract).claimRewards(msg.sender, 100000);//TODO decide reward
        }
        length = length&0x000000000000000000000000000000000000000000000000ffffffffffffffff;

        // TODO need optimization
        bytes memory serialized = new bytes(length+32);
        for(uint256 pos = 0 ; pos < length+32; pos+=32) {
            assembly {
                mstore(add(serialized, pos), mload(add(result, pos)))
            }
        }

        uint64 decodedHeight;
        (cs, decodedHeight) = decodeConsensusState(serialized);
        if (decodedHeight != height) {
            revert("header height doesn't equal to specified height");
        }

        _submitters[height] = msg.sender;
        cs.preHeight = preHeight;
        _BBCLightClientConsensusState[height] = cs;
        if (height > _latestHeight) {
            _latestHeight = height;
        }
        _BBCLightClientConsensusState[nextHeight].preHeight = height;

        emit SyncConsensusState(height, preHeight, nextHeight, cs.appHash, validatorChanged);

        return true;
    }

    function isHeaderSynced(uint64 height) external view returns (bool) {
        bytes32 appHash = _BBCLightClientConsensusState[height].appHash;
        if (appHash == bytes32(0)) {
            return false;
        }
        return true;
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

    // | length   | _chainID  | height   | appHash  | curValidatorSetHash | [{validator pubkey, voting power}] |
    // | 32 bytes | 32 bytes  | 8 bytes  | 32 bytes | 32 bytes            | [{32 bytes, 8 bytes}]              |
    function decodeConsensusState(bytes memory input) internal pure returns(ConsensusState memory, uint64) {
        //skip input size
        uint256 pos = 32;
        uint256 validatorSetLength = (input.length-104)/40;

        pos=pos+8;
        uint64 height;
        assembly {
            height := mload(add(input, pos))
        }

        pos=pos+32;
        bytes32 appHash;
        assembly {
            appHash := mload(add(input, pos))
        }

        pos=pos+32;
        bytes32 curValidatorSetHash;
        assembly {
            curValidatorSetHash := mload(add(input, pos))
        }

        ConsensusState memory cs;
        cs.appHash = appHash;
        cs.curValidatorSetHash = curValidatorSetHash;
        cs.nextValidatorSet = new bytes(40*validatorSetLength);

        uint256 dest;
        (dest,) = Memory.fromBytes(cs.nextValidatorSet);

        uint256 src;
        uint256 length;
        (src, length) = Memory.fromBytes(input);
        Memory.copy(src+104, dest, length);

        return (cs, height);
    }
}