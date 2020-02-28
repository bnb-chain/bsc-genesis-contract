pragma solidity 0.5.16;

import "Memory.sol";
import "Bytes.sol";
import "BytesToTypes.sol";
import "ITendermintLightClient.sol";
import "ISystemReward.sol";

contract TendermintLightClient is ITendermintLightClient {

    struct Validator {
        bytes32 pubkey;
        uint64   votingPower;
    }

    struct ConsensusState {
        bytes32 appHash;
        bytes32 curValidatorSetHash;
        uint64 preHeight;
        Validator[] nextValidatorSet;
    }

    address systemRewardContract;
    string public chainID;
    mapping(uint64 => ConsensusState) public BBCLightClientConsensusState;
    mapping(uint64 => address payable) private submitters;
    uint64 public initialHeight;
    uint64 public latestHeight;

    event InitConsensusState(uint64 initHeight, bytes32 appHash, uint256 validatorQuantiy, string chainID);
    event SyncConsensusState(uint64 height, uint64 preHeight, uint64 nextHeight, bytes32 appHash, uint256 validatorQuantiy);

    constructor() public {

    }

    function initConsensusState(bytes memory initConsensusStateBytes, string memory chain_id, address systemRewardContractAddr) public {
        ConsensusState memory cs;
        uint64 height;

        (cs, height) = decodeConsensusState(initConsensusStateBytes);

        BBCLightClientConsensusState[height].appHash = cs.appHash;
        BBCLightClientConsensusState[height].preHeight = 0;
        for (uint64 index = 0; index < cs.nextValidatorSet.length; index++) {
            BBCLightClientConsensusState[height].nextValidatorSet.push(cs.nextValidatorSet[index]);
        }
        initialHeight = height;
        latestHeight = height;
        chainID = chain_id;
        systemRewardContract=systemRewardContractAddr;

        emit InitConsensusState(initialHeight, cs.appHash, cs.nextValidatorSet.length, chain_id);
    }

    function syncTendermintHeader(bytes memory header, uint64 height) public returns (bool) {
        uint64 preHeight = latestHeight;
        uint64 nextHeight = 0xffffffffffffffff;
        ConsensusState memory cs;
        for(; preHeight > 0;) {
            if (preHeight == height) {
                // target header is already existing.
                return true;
            }
            if (preHeight < height) {
                // find nearest previous height
                break;
            }
            cs = BBCLightClientConsensusState[preHeight];
            nextHeight = preHeight;
            preHeight = cs.preHeight;
        }

        bytes memory csBytes = serializeConsensusState(preHeight);
        uint256 length = csBytes.length;

        bytes memory csBytesLenBytes = new bytes(32);
        assembly {
            mstore(add(csBytesLenBytes, 32), length)
        }

        bytes memory input = Bytes.concat(csBytesLenBytes, csBytes);
        input = Bytes.concat(input, header);
        length = input.length+32;

        bytes32[32] memory result;
        assembly {
        // call validateTendermintHeader precompile contract
        // ccontract address: 0x0a
            if iszero(staticcall(not(0), 0x0a, input, length, result, 1024)) {
                revert(0, 0)
            }
        }

        assembly {
            length := mload(add(result, 0))
        }
        if ((length&0x0100000000000000000000000000000000000000000000000000000000000000)!=0x00) {
            ISystemReward(systemRewardContract).claimRewards(msg.sender, 100000);//TODO decide reward
        }
        length = length&0x000000000000000000000000000000000000000000000000ffffffffffffffff;

        bytes memory serialized = new bytes(length+32);
        for(uint256 pos = 0 ; pos < length+32; pos+=32) {
            uint256 temp;
            assembly {
                temp := mload(add(result, pos))
                mstore(add(serialized,pos), temp)
            }
        }

        uint64 decodedHeight;
        (cs, decodedHeight) = decodeConsensusState(serialized);
        if (decodedHeight != height) {
            revert("header height doesn't equal to specified height");
        }

        submitters[height] = msg.sender;
        BBCLightClientConsensusState[height].appHash = cs.appHash;
        BBCLightClientConsensusState[height].preHeight = preHeight;
        for (uint64 index = 0; index < cs.nextValidatorSet.length; index++) {
            BBCLightClientConsensusState[height].nextValidatorSet.push(cs.nextValidatorSet[index]);
        }
        if (height > latestHeight) {
            latestHeight = height;
        }
        BBCLightClientConsensusState[nextHeight].preHeight = height;

        emit SyncConsensusState(height, preHeight, nextHeight, cs.appHash, cs.nextValidatorSet.length);

        return true;
    }

    function validateMerkleProof(uint64 height, string calldata storeName, bytes calldata key,
        bytes calldata value, bytes calldata proof) external view returns (bool) {
        bytes32 appHash = BBCLightClientConsensusState[height].appHash;
        if (appHash == bytes32(0)) {
            return false;
        }

        // | storeName | key length | key | value length | value | appHash  | proof |
        // | 32 bytes  | 32 bytes   |     | 32 bytes     |       | 32 bytes |
        bytes memory serialized = new bytes(64);
        bytes memory tempBytes = bytes(storeName);
        uint256 length = key.length;
        uint256 ptr = Memory.dataPtr(serialized);
        assembly {
            mstore(add(ptr, 0), mload(add(tempBytes, 32)))
            mstore(add(ptr, 32), length)
        }

        serialized = Bytes.concat(serialized, key);

        tempBytes = new bytes(32);
        length =value.length;
        ptr = Memory.dataPtr(tempBytes);
        assembly {
            mstore(add(ptr, 0), length)
        }

        serialized = Bytes.concat(serialized, tempBytes);
        serialized = Bytes.concat(serialized, value);

        tempBytes =  new bytes(32);
        ptr = Memory.dataPtr(tempBytes);
        assembly {
            mstore(add(ptr, 0), appHash)
        }
        serialized = Bytes.concat(serialized, tempBytes);

        serialized = Bytes.concat(serialized, proof);
        uint256 serializedLen = serialized.length+32;

        uint256[2] memory result;
        assembly {
        // call validateMerkleProof precompile contract
        // ccontract address: 0x0b
            if iszero(staticcall(not(0), 0x0b, serialized, serializedLen, result, 0x40)) {
                revert(0, 0)
            }
        }

        require(result[0] == 0x01);

        return true;
    }

    function isHeaderSynced(uint64 height) external view returns (bool) {
        bytes32 appHash = BBCLightClientConsensusState[height].appHash;
        if (appHash == bytes32(0)) {
            return false;
        }
        return true;
    }

    function getSubmitter(uint64 height) external view returns (address payable) {
        return submitters[height];
    }

    // | chainID   | height   | appHash  | curValidatorSetHash | nextValidatorSet length | [{validator pubkey, voting power}] |
    // | 32 bytes  | 8 bytes  | 32 bytes | 32 bytes            | 8 bytes                 | [{32 bytes, 8 bytes}]              |
    function serializeConsensusState(uint64 height) internal view returns (bytes memory) {
        ConsensusState memory cs = BBCLightClientConsensusState[height];
        uint256 size = 32 + 8 + 32 + 32+ 8 + 40*cs.nextValidatorSet.length;
        bytes memory serialized = new bytes(size);

        uint256 pos = size-32;
        uint256 ptr = Memory.dataPtr(serialized);

        uint256 validatorQuantiy = cs.nextValidatorSet.length;
        for (uint64 i = 1; i <= validatorQuantiy; i++) {
            uint256 index = validatorQuantiy-i;
            Validator memory validator = cs.nextValidatorSet[index];

            uint64 votingPower = validator.votingPower;

            assembly {
                mstore(add(ptr, pos), votingPower)
            }
            pos=pos-8;

            bytes32 pubkey = validator.pubkey;
            assembly {
                mstore(add(ptr, pos), pubkey)
            }
            pos=pos-32;
        }

        assembly {
            mstore(add(ptr, pos), validatorQuantiy)
        }
        pos=pos-8;

        bytes32 hash = cs.curValidatorSetHash;
        assembly {
            mstore(add(ptr, pos), hash)
        }
        pos=pos-32;

        hash = cs.appHash;
        assembly {
            mstore(add(ptr, pos), hash)
        }
        pos=pos-32;

        assembly {
            mstore(add(ptr, pos), height)
        }
        pos=pos-8;

        bytes memory chainIDBytes = bytes(chainID);
        assembly {
            mstore(add(ptr, pos), mload(add(chainIDBytes, 32)))
        }

        return serialized;
    }

    // | chainID   | height   | appHash  | curValidatorSetHash | nextValidatorSet length | [{validator pubkey, voting power}] |
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