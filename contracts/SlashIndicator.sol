pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "./System.sol";
import "./lib/BytesToTypes.sol";
import "./lib/TypesToBytes.sol";
import "./lib/BytesLib.sol";
import "./lib/Memory.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IApplication.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/ICrossChain.sol";
import "./interface/ISystemReward.sol";
import "./interface/IStakeHub.sol";
import "./lib/CmnPkg.sol";
import "./lib/RLPEncode.sol";

contract SlashIndicator is ISlashIndicator, System, IParamSubscriber, IApplication {
    using RLPEncode for *;

    uint256 public constant MISDEMEANOR_THRESHOLD = 50;
    uint256 public constant FELONY_THRESHOLD = 150;
    uint256 public constant DECREASE_RATE = 4;

    // State of the contract
    address[] public validators;
    mapping(address => Indicator) public indicators;
    uint256 public previousHeight;

    // The BSC validators assign proper values for `misdemeanorThreshold` and `felonyThreshold` through governance.
    // The proper values depends on BSC network's tolerance for continuous missing blocks.
    uint256 public misdemeanorThreshold;
    uint256 public felonyThreshold;

    // BEP-126 Fast Finality
    // @notice change name from `INIT_FINALITY_SLASH_REWARD_RATIO` to `INIT_FELONY_SLASH_REWARD_RATIO` after BC-fusion
    uint256 public constant INIT_FELONY_SLASH_REWARD_RATIO = 20;

    // @notice change name from `finalitySlashRewardRatio` to `felonySlashRewardRatio` after BC-fusion
    uint256 public felonySlashRewardRatio;
    bool public enableMaliciousVoteSlash;

    uint256 public constant INIT_FELONY_SLASH_SCOPE = 28800; // 1 days(block number)

    uint256 public felonySlashScope;

    event validatorSlashed(address indexed validator);
    event maliciousVoteSlashed(bytes32 indexed voteAddrSlice);
    event indicatorCleaned();
    event paramChange(string key, bytes value);

    event knownResponse(uint32 code);
    event unKnownResponse(uint32 code);
    event crashResponse();

    event failedFelony(address indexed validator, uint256 slashCount, bytes failReason);

    struct Indicator {
        uint256 height;
        uint256 count;
        bool exist;
    }

    // Proof that a validator misbehaved in fast finality
    struct VoteData {
        uint256 srcNum;
        bytes32 srcHash;
        uint256 tarNum;
        bytes32 tarHash;
        bytes sig;
    }

    struct FinalityEvidence {
        VoteData voteA;
        VoteData voteB;
        bytes voteAddr;
    }

    modifier oncePerBlock() {
        require(block.number > previousHeight, "can not slash twice in one block");
        _;
        previousHeight = block.number;
    }

    function init() external onlyNotInit {
        misdemeanorThreshold = MISDEMEANOR_THRESHOLD;
        felonyThreshold = FELONY_THRESHOLD;
        alreadyInit = true;
    }

    /*----------------- Implement cross chain app -----------------*/
    function handleSynPackage(
        uint8,
        bytes calldata
    ) external override onlyCrossChainContract onlyInit returns (bytes memory) {
        require(false, "receive unexpected syn package");
    }

    function handleAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract onlyInit {
        (CmnPkg.CommonAckPackage memory response, bool ok) = CmnPkg.decodeCommonAckPackage(msgBytes);
        if (ok) {
            emit knownResponse(response.code);
        } else {
            emit unKnownResponse(response.code);
        }
        return;
    }

    function handleFailAckPackage(uint8, bytes calldata) external override onlyCrossChainContract onlyInit {
        emit crashResponse();
        return;
    }

    /*----------------- External func -----------------*/
    /**
     * @dev Slash the validator who should have produced the current block
     *
     * @param validator The validator who should have produced the current block
     */
    function slash(address validator) external onlyCoinbase onlyInit oncePerBlock onlyZeroGasPrice {
        if (!IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).isCurrentValidator(validator)) {
            return;
        }
        Indicator memory indicator = indicators[validator];
        if (indicator.exist) {
            ++indicator.count;
        } else {
            indicator.exist = true;
            indicator.count = 1;
            validators.push(validator);
        }
        indicator.height = block.number;
        if (indicator.count % felonyThreshold == 0) {
            indicator.count = 0;
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(validator);
            if (IStakeHub(STAKE_HUB_ADDR).consensusToOperator(validator) != address(0)) {
                _downtimeSlash(validator, indicator.count, false);
            } else {
                // send slash msg to bc if validator is not migrated
                try ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(
                    SLASH_CHANNELID, encodeSlashPackage(validator), 0
                ) { } catch (bytes memory reason) {
                    emit failedFelony(validator, indicator.count, reason);
                }
            }
        } else if (indicator.count % misdemeanorThreshold == 0) {
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).misdemeanor(validator);
        }
        indicators[validator] = indicator;
        emit validatorSlashed(validator);
    }

    // To prevent validator misbehaving and leaving, do not clean slash record to zero, but decrease by felonyThreshold/DECREASE_RATE .
    // Clean is an effective implement to reorganize "validators" and "indicators".
    function clean() external override(ISlashIndicator) onlyValidatorContract onlyInit {
        if (validators.length == 0) {
            return;
        }
        uint256 i;
        uint256 j = validators.length - 1;
        for (; i <= j;) {
            bool findLeft = false;
            bool findRight = false;
            for (; i < j; ++i) {
                Indicator memory leftIndicator = indicators[validators[i]];
                if (leftIndicator.count > felonyThreshold / DECREASE_RATE) {
                    leftIndicator.count = leftIndicator.count - felonyThreshold / DECREASE_RATE;
                    indicators[validators[i]] = leftIndicator;
                } else {
                    findLeft = true;
                    break;
                }
            }
            for (; i <= j; --j) {
                Indicator memory rightIndicator = indicators[validators[j]];
                if (rightIndicator.count > felonyThreshold / DECREASE_RATE) {
                    rightIndicator.count = rightIndicator.count - felonyThreshold / DECREASE_RATE;
                    indicators[validators[j]] = rightIndicator;
                    findRight = true;
                    break;
                } else {
                    delete indicators[validators[j]];
                    validators.pop();
                }
                // avoid underflow
                if (j == 0) {
                    break;
                }
            }
            // swap element in array
            if (findLeft && findRight) {
                delete indicators[validators[i]];
                validators[i] = validators[j];
                validators.pop();
            }
            // avoid underflow
            if (j == 0) {
                break;
            }
            // move to next
            ++i;
            --j;
        }
        emit indicatorCleaned();
    }

    function downtimeSlash(
        address validator,
        uint256 count,
        bool shouldRevert
    ) external override onlyValidatorContract {
        _downtimeSlash(validator, count, shouldRevert);
    }

    function _downtimeSlash(address validator, uint256 count, bool shouldRevert) internal {
        if (shouldRevert) {
            IStakeHub(STAKE_HUB_ADDR).downtimeSlash(validator);
        } else {
            try IStakeHub(STAKE_HUB_ADDR).downtimeSlash(validator) { }
            catch Error(string memory reason) {
                emit failedFelony(validator, count, bytes(reason));
            } catch (bytes memory lowLevelData) {
                emit failedFelony(validator, count, lowLevelData);
            }
        }
    }

    function submitFinalityViolationEvidence(FinalityEvidence memory _evidence) public onlyInit {
        require(enableMaliciousVoteSlash, "malicious vote slash not enabled");
        if (felonySlashRewardRatio == 0) {
            felonySlashRewardRatio = INIT_FELONY_SLASH_REWARD_RATIO;
        }
        if (felonySlashScope == 0) {
            felonySlashScope = INIT_FELONY_SLASH_SCOPE;
        }

        // Basic check
        require(
            _evidence.voteA.tarNum + felonySlashScope > block.number
                && _evidence.voteB.tarNum + felonySlashScope > block.number,
            "target block too old"
        );
        require(
            !(_evidence.voteA.srcHash == _evidence.voteB.srcHash && _evidence.voteA.tarHash == _evidence.voteB.tarHash),
            "two identical votes"
        );
        require(
            _evidence.voteA.srcNum < _evidence.voteA.tarNum && _evidence.voteB.srcNum < _evidence.voteB.tarNum,
            "srcNum bigger than tarNum"
        );

        // Vote rules check
        require(
            (_evidence.voteA.srcNum < _evidence.voteB.srcNum && _evidence.voteB.tarNum < _evidence.voteA.tarNum)
                || (_evidence.voteB.srcNum < _evidence.voteA.srcNum && _evidence.voteA.tarNum < _evidence.voteB.tarNum)
                || _evidence.voteA.tarNum == _evidence.voteB.tarNum,
            "no violation of vote rules"
        );

        // check voteAddr to protect validators from being slashed for old voteAddr
        require(
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).isMonitoredForMaliciousVote(_evidence.voteAddr),
            "voteAddr is not found"
        );

        // BLS verification
        require(
            _verifyBLSSignature(_evidence.voteA, _evidence.voteAddr)
                && _verifyBLSSignature(_evidence.voteB, _evidence.voteAddr),
            "verify signature failed"
        );

        // reward sender and felony validator if validator found
        // TODO: after BC-fusion, we don't need to check if validator is living
        (address[] memory vals, bytes[] memory voteAddrs) =
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).getLivingValidators();
        for (uint256 i; i < voteAddrs.length; ++i) {
            if (BytesLib.equal(voteAddrs[i], _evidence.voteAddr)) {
                uint256 amount = (address(SYSTEM_REWARD_ADDR).balance * felonySlashRewardRatio) / 100;
                ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, amount);
                IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(vals[i]);
                break;
            }
        }

        if (IStakeHub(STAKE_HUB_ADDR).voteToOperator(_evidence.voteAddr) != address(0)) {
            IStakeHub(STAKE_HUB_ADDR).maliciousVoteSlash(_evidence.voteAddr);
        } else {
            // send slash msg to bc if the validator not migrated
            ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(
                SLASH_CHANNELID, encodeVoteSlashPackage(_evidence.voteAddr), 0
            );

            bytes32 voteAddrSlice = BytesLib.toBytes32(_evidence.voteAddr, 0);
            emit maliciousVoteSlashed(voteAddrSlice);
        }
    }

    function submitDoubleSignEvidence(bytes memory header1, bytes memory header2) public onlyInit {
        if (felonySlashRewardRatio == 0) {
            felonySlashRewardRatio = INIT_FELONY_SLASH_REWARD_RATIO;
        }
        if (felonySlashScope == 0) {
            felonySlashScope = INIT_FELONY_SLASH_SCOPE;
        }

        require(header1.length != 0 && header2.length != 0, "empty header");

        bytes[] memory elements = new bytes[](3);
        elements[0] = bscChainID.encodeUint();
        elements[1] = header1.encodeBytes();
        elements[2] = header2.encodeBytes();

        // call precompile contract to verify evidence
        bytes memory input = elements.encodeList();
        bytes memory output = new bytes(52);
        assembly {
            let len := mload(input)
            if iszero(staticcall(not(0), 0x68, add(input, 0x20), len, add(output, 0x20), 0x34)) { revert(0, 0) }
        }

        address signer;
        uint256 evidenceHeight;
        assembly {
            signer := mload(add(output, 0x14))
            evidenceHeight := mload(add(output, 0x34))
        }
        require(IStakeHub(STAKE_HUB_ADDR).consensusToOperator(signer) != address(0), "validator not migrated");
        require(evidenceHeight + felonySlashScope >= block.number, "evidence too old");

        // reward sender and felony validator
        IStakeHub(STAKE_HUB_ADDR).doubleSignSlash(signer);
        IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(signer);

        uint256 amount = (address(SYSTEM_REWARD_ADDR).balance * felonySlashRewardRatio) / 100;
        ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(msg.sender, amount);
    }

    /**
     * @dev Send a felony cross-chain package to jail a validator
     *
     * @param validator Who will be jailed
     */
    function sendFelonyPackage(address validator) external override(ISlashIndicator) onlyValidatorContract onlyInit {
        try ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(SLASH_CHANNELID, encodeSlashPackage(validator), 0) { }
        catch (bytes memory reason) {
            emit failedFelony(validator, 0, reason);
        }
    }

    function _verifyBLSSignature(VoteData memory vote, bytes memory voteAddr) internal view returns (bool) {
        bytes[] memory elements = new bytes[](4);
        bytes memory _bytes = new bytes(32);
        elements[0] = vote.srcNum.encodeUint();
        TypesToBytes.bytes32ToBytes(32, vote.srcHash, _bytes);
        elements[1] = _bytes.encodeBytes();
        elements[2] = vote.tarNum.encodeUint();
        TypesToBytes.bytes32ToBytes(32, vote.tarHash, _bytes);
        elements[3] = _bytes.encodeBytes();

        TypesToBytes.bytes32ToBytes(32, keccak256(elements.encodeList()), _bytes);

        // assemble input data
        bytes memory input = new bytes(176);
        _bytesConcat(input, _bytes, 0, 32);
        _bytesConcat(input, vote.sig, 32, 96);
        _bytesConcat(input, voteAddr, 128, 48);

        // call the precompiled contract to verify the BLS signature
        // the precompiled contract's address is 0x66
        bytes memory output = new bytes(1);
        assembly {
            let len := mload(input)
            if iszero(staticcall(not(0), 0x66, add(input, 0x20), len, add(output, 0x20), 0x01)) { revert(0, 0) }
        }
        if (BytesLib.toUint8(output, 0) != uint8(1)) {
            return false;
        }
        return true;
    }

    function _bytesConcat(bytes memory data, bytes memory _bytes, uint256 index, uint256 len) internal pure {
        for (uint256 i; i < len; ++i) {
            data[index++] = _bytes[i];
        }
    }

    /*----------------- Param update -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        if (Memory.compareStrings(key, "misdemeanorThreshold")) {
            require(value.length == 32, "length of misdemeanorThreshold mismatch");
            uint256 newMisdemeanorThreshold = BytesToTypes.bytesToUint256(32, value);
            require(
                newMisdemeanorThreshold >= 1 && newMisdemeanorThreshold < felonyThreshold,
                "the misdemeanorThreshold out of range"
            );
            misdemeanorThreshold = newMisdemeanorThreshold;
        } else if (Memory.compareStrings(key, "felonyThreshold")) {
            require(value.length == 32, "length of felonyThreshold mismatch");
            uint256 newFelonyThreshold = BytesToTypes.bytesToUint256(32, value);
            require(
                newFelonyThreshold <= 1000 && newFelonyThreshold > misdemeanorThreshold,
                "the felonyThreshold out of range"
            );
            felonyThreshold = newFelonyThreshold;
        } else if (Memory.compareStrings(key, "felonySlashRewardRatio")) {
            require(value.length == 32, "length of felonySlashRewardRatio mismatch");
            uint256 newFelonySlashRewardRatio = BytesToTypes.bytesToUint256(32, value);
            require(
                newFelonySlashRewardRatio >= 10 && newFelonySlashRewardRatio < 100,
                "the felony slash reward ratio out of range"
            );
            felonySlashRewardRatio = newFelonySlashRewardRatio;
        } else if (Memory.compareStrings(key, "enableMaliciousVoteSlash")) {
            require(value.length == 32, "length of enableMaliciousVoteSlash mismatch");
            enableMaliciousVoteSlash = BytesToTypes.bytesToBool(32, value);
        } else if (Memory.compareStrings(key, "felonySlashScope")) {
            require(value.length == 32, "length of felonySlashScope mismatch");
            uint256 newMaliciousVoteSlashScope = BytesToTypes.bytesToUint256(32, value);
            require(
                newMaliciousVoteSlashScope >= 28800 * 1 && newMaliciousVoteSlashScope < 28800 * 30,
                "the malicious vote slash scope out of range"
            );
            felonySlashScope = newMaliciousVoteSlashScope;
        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    /*----------------- query api -----------------*/
    function getSlashIndicator(address validator) external view returns (uint256, uint256) {
        Indicator memory indicator = indicators[validator];
        return (indicator.height, indicator.count);
    }

    function encodeSlashPackage(address valAddr) internal view returns (bytes memory) {
        bytes[] memory elements = new bytes[](4);
        elements[0] = valAddr.encodeAddress();
        elements[1] = uint256(block.number).encodeUint();
        elements[2] = uint256(bscChainID).encodeUint();
        elements[3] = uint256(block.timestamp).encodeUint();
        return elements.encodeList();
    }

    function encodeVoteSlashPackage(bytes memory voteAddr) internal view returns (bytes memory) {
        bytes[] memory elements = new bytes[](4);
        elements[0] = voteAddr.encodeBytes();
        elements[1] = uint256(block.number).encodeUint();
        elements[2] = uint256(bscChainID).encodeUint();
        elements[3] = uint256(block.timestamp).encodeUint();
        return elements.encodeList();
    }

    function getSlashThresholds() external view override(ISlashIndicator) returns (uint256, uint256) {
        return (misdemeanorThreshold, felonyThreshold);
    }
}
