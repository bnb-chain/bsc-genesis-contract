pragma solidity 0.6.4;

import "../lib/0.6.x/Memory.sol";
import "../interface/0.6.x/ILightClient.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../System.sol";

contract TendermintLightClient is ILightClient, System, IParamSubscriber {
    struct ConsensusState {
        uint64 preValidatorSetChangeHeight;
        bytes32 appHash;
        bytes32 curValidatorSetHash;
        bytes nextValidatorSet;
    }

    mapping(uint64 => ConsensusState) public lightClientConsensusStates;
    mapping(uint64 => address payable) public submitters;
    uint64 public initialHeight;
    uint64 public latestHeight;  // @dev deprecated
    bytes32 public chainID;  // @dev deprecated

    bytes public constant INIT_CONSENSUS_STATE_BYTES =
        hex"42696e616e63652d436861696e2d5469677269730000000000000000000000000000000006915167cedaf7bbf7df47d932fdda630527ee648562cf3e52c5e5f46156a3a971a4ceb443c53a50d8653ef8cf1e5716da68120fb51b636dc6d111ec3277b098ecd42d49d3769d8a1f78b4c17a965f7a30d4181fabbd1f969f46d3c8e83b5ad4845421d8000000e8d4a510002ba4e81542f437b7ae1f8a35ddb233c789a8dc22734377d9b6d63af1ca403b61000000e8d4a51000df8da8c5abfdb38595391308bb71e5a1e0aabdc1d0cf38315d50d6be939b2606000000e8d4a51000b6619edca4143484800281d698b70c935e9152ad57b31d85c05f2f79f64b39f3000000e8d4a510009446d14ad86c8d2d74780b0847110001a1c2e252eedfea4753ebbbfce3a22f52000000e8d4a510000353c639f80cc8015944436dab1032245d44f912edc31ef668ff9f4a45cd0599000000e8d4a51000e81d3797e0544c3a718e1f05f0fb782212e248e784c1a851be87e77ae0db230e000000e8d4a510005e3fcda30bd19d45c4b73688da35e7da1fce7c6859b2c1f20ed5202d24144e3e000000e8d4a51000b06a59a2d75bf5d014fce7c999b5e71e7a960870f725847d4ba3235baeaa08ef000000e8d4a510000c910e2fe650e4e01406b3310b489fb60a84bc3ff5c5bee3a56d5898b6a8af32000000e8d4a5100071f2d7b8ec1c8b99a653429b0118cd201f794f409d0fea4d65b1b662f2b00063000000e8d4a51000";
    uint256 public constant INIT_REWARD_FOR_VALIDATOR_SER_CHANGE = 1e16;
    uint256 public rewardForValidatorSetChange;

    event initConsensusState(uint64 initHeight, bytes32 appHash);  // @dev deprecated
    event syncConsensusState(uint64 height, uint64 preValidatorSetChangeHeight, bytes32 appHash, bool validatorChanged);  // @dev deprecated
    event paramChange(string key, bytes value);  // @dev deprecated

    function init() external onlyNotInit {
        uint256 pointer;
        uint256 length;
        (pointer, length) = Memory.fromBytes(INIT_CONSENSUS_STATE_BYTES);

        /* solium-disable-next-line */
        assembly {
            sstore(chainID_slot, mload(pointer))
        }

        alreadyInit = true;
        rewardForValidatorSetChange = INIT_REWARD_FOR_VALIDATOR_SER_CHANGE;
    }

    function syncTendermintHeader(bytes calldata header, uint64 height) external onlyRelayer returns (bool) {
        revert("deprecated");
    }

    function isHeaderSynced(uint64 height) external view override returns (bool) {
        return submitters[height] != address(0x0) || height == initialHeight;
    }

    function getAppHash(uint64 height) external view override returns (bytes32) {
        return lightClientConsensusStates[height].appHash;
    }

    function getSubmitter(uint64 height) external view override returns (address payable) {
        return submitters[height];
    }

    function getChainID() external view returns (string memory) {
        bytes memory chainIDBytes = new bytes(32);
        assembly {
            mstore(add(chainIDBytes, 32), sload(chainID_slot))
        }

        uint8 chainIDLength = 0;
        for (uint8 j = 0; j < 32; ++j) {
            if (chainIDBytes[j] != 0) {
                ++chainIDLength;
            } else {
                break;
            }
        }

        bytes memory chainIDStr = new bytes(chainIDLength);
        for (uint8 j = 0; j < chainIDLength; ++j) {
            chainIDStr[j] = chainIDBytes[j];
        }

        return string(chainIDStr);
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        revert("deprecated");
    }
}
