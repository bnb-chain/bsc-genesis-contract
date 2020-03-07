pragma solidity 0.5.16;

import "Memory.sol";
import "BytesToTypes.sol";
import "ITendermintLightClient.sol";
import "ISystemReward.sol";

contract TendermintLightClient is ITendermintLightClient {

    struct Validator {
        bytes32 pubkey;
        uint64  votingPower;
    }

    struct ConsensusState {
        bytes32 appHash;
        bytes32 curValidatorSetHash;
        uint64  preHeight;
        Validator[] nextValidatorSet;
    }


    mapping(uint64 => ConsensusState) public _BBCLightClientConsensusState;
    mapping(uint64 => address payable) public _submitters;
    address public _systemRewardContract;
    string public _chainID;
    uint64 public _initialHeight;
    uint64 public _latestHeight;
    bool public _alreadyInit=false;

    event InitConsensusState(uint64 initHeight, bytes32 appHash, uint256 validatorQuantity, string _chainID);
    event SyncConsensusState(uint64 height, uint64 preHeight, uint64 nextHeight, bytes32 appHash, uint256 validatorQuantity);

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

        _BBCLightClientConsensusState[height].appHash = cs.appHash;
        _BBCLightClientConsensusState[height].curValidatorSetHash = cs.curValidatorSetHash;
        _BBCLightClientConsensusState[height].preHeight = 0;
        for (uint64 index = 0; index < cs.nextValidatorSet.length; index++) {
            _BBCLightClientConsensusState[height].nextValidatorSet.push(cs.nextValidatorSet[index]);
        }
        _initialHeight = height;
        _latestHeight = height;
        _chainID = chain_id;
        _systemRewardContract=systemRewardContractAddr;

        emit InitConsensusState(_initialHeight, cs.appHash, cs.nextValidatorSet.length, chain_id);
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

        //32 + 32 + 8 + 32 + 32 + 8 + 40 * cs.nextValidatorSet.length;
        uint256 csBytesSize = 144 + 40 * cs.nextValidatorSet.length;
        bytes memory input = new bytes(csBytesSize+header.length);
        uint256 ptr = Memory.dataPtr(input);
        require(serializeConsensusState(cs, preHeight, ptr, csBytesSize));

        // write header to input
        uint256 src;
        uint256 length;
        ptr=ptr+csBytesSize;
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
        if ((length&0x0100000000000000000000000000000000000000000000000000000000000000)!=0x00) {
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
        _BBCLightClientConsensusState[height].appHash = cs.appHash;
        _BBCLightClientConsensusState[height].curValidatorSetHash = cs.curValidatorSetHash;
        _BBCLightClientConsensusState[height].preHeight = preHeight;
        for (uint64 index = 0; index < cs.nextValidatorSet.length; index++) {
            _BBCLightClientConsensusState[height].nextValidatorSet.push(cs.nextValidatorSet[index]);
        }
        if (height > _latestHeight) {
            _latestHeight = height;
        }
        _BBCLightClientConsensusState[nextHeight].preHeight = height;

        emit SyncConsensusState(height, preHeight, nextHeight, cs.appHash, cs.nextValidatorSet.length);

        return true;
    }

    function validateMerkleProof(uint64 height, string calldata storeName, bytes calldata key,
        bytes calldata value, bytes calldata proof) external view returns (bool) {
        bytes32 appHash = _BBCLightClientConsensusState[height].appHash;
        if (appHash == bytes32(0)) {
            return false;
        }

        // | storeName | key length | key | value length | value | appHash  | proof |
        // | 32 bytes  | 32 bytes   |     | 32 bytes     |       | 32 bytes |
        bytes memory input = new bytes(128+key.length+value.length+proof.length);

        uint256 ptr = Memory.dataPtr(input);

        bytes memory storeNameBytes = bytes(storeName);
        assembly {
            mstore(add(ptr, 0), mload(add(storeNameBytes, 32)))
        }

        uint256 src;
        uint256 length;

        // write key length and key to input
        ptr=ptr+32;
        (src, length) = Memory.fromBytes(key);
        assembly {
            mstore(ptr, length)
        }
        ptr=ptr+32;
        Memory.copy(src, ptr, length);

        // write value length and value to input
        ptr=ptr+length;
        (src, length) = Memory.fromBytes(value);
        assembly {
            mstore(ptr, length)
        }
        ptr=ptr+32;
        Memory.copy(src, ptr, length);

        // write appHash to input
        ptr=ptr+length;
        assembly {
            mstore(ptr, appHash)
        }

        // write proof to input
        ptr=ptr+32;
        (src,length) = Memory.fromBytes(proof);
        Memory.copy(src, ptr, length);

        length = input.length+32;

        uint256[2] memory result;
        assembly {
        // call validateMerkleProof precompile contract
        // Contract address: 0x65
            if iszero(staticcall(not(0), 0x65, input, length, result, 0x40)) {
                revert(0, 0)
            }
        }

        if (result[0] == 0x01) {
            return false;
        }

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

    // | length   | _chainID   | height   | appHash  | curValidatorSetHash | nextValidatorSet length | [{validator pubkey, voting power}] |
    // | 32 bytes | 32 bytes   | 8 bytes  | 32 bytes | 32 bytes            | 8 bytes                 | [{32 bytes, 8 bytes}]              |
    function serializeConsensusState(ConsensusState memory cs, uint64 height, uint256 outputPtr, uint256 size) internal view returns (bool) {
        outputPtr = outputPtr + size - 32;

        uint256 validatorQuantity = cs.nextValidatorSet.length;
        for (uint64 i = 1; i <= validatorQuantity; i++) {
            uint256 index = validatorQuantity-i;
            Validator memory validator = cs.nextValidatorSet[index];

            uint64 votingPower = validator.votingPower;

            assembly {
                mstore(outputPtr, votingPower)
            }
            outputPtr=outputPtr-8;

            bytes32 pubkey = validator.pubkey;
            assembly {
                mstore(outputPtr, pubkey)
            }
            outputPtr=outputPtr-32;
        }

        assembly {
            mstore(outputPtr, validatorQuantity)
        }
        outputPtr=outputPtr-8;

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

        // size doesn't contract length
        size=size-32;
        assembly {
            mstore(outputPtr, size)
        }

        return true;
    }

    // | _chainID  | height   | appHash  | curValidatorSetHash | nextValidatorSet length | [{validator pubkey, voting power}] |
    // | 32 bytes  | 8 bytes  | 32 bytes | 32 bytes            | 8 bytes                 | [{32 bytes, 8 bytes}]              |
    function decodeConsensusState(bytes memory input) internal pure returns(ConsensusState memory, uint64) {
        //skip input size
        uint256 pos = 32;

        pos=pos+8;
        uint64 height = BytesToTypes.bytesToUint64(pos, input);

        pos=pos+32;
        bytes32 appHash = BytesToTypes.bytesToBytes32(pos,input);

        pos=pos+32;
        bytes32 curValidatorSetHash = BytesToTypes.bytesToBytes32(pos,input);

        pos=pos+8;
        uint64 validatorsetLength = BytesToTypes.bytesToUint64(pos,input);

        ConsensusState memory cs;
        cs.appHash = appHash;
        cs.curValidatorSetHash = curValidatorSetHash;
        cs.nextValidatorSet = new Validator[](validatorsetLength);
        for (uint64 index = 0; index < validatorsetLength; index++) {
            Validator memory validator;

            pos = pos + 32;
            validator.pubkey = BytesToTypes.bytesToBytes32(pos,input);

            pos = pos + 8;
            validator.votingPower = BytesToTypes.bytesToUint64(pos,input);

            cs.nextValidatorSet[index] = (validator);
        }
        return (cs, height);
    }
}