pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "./System.sol";
import "./lib/0.6.x/BytesLib.sol";
import "./lib/0.6.x/BytesToTypes.sol";
import "./lib/0.6.x/Memory.sol";
import "./interface/0.6.x/ISlashIndicator.sol";
import "./interface/0.6.x/IParamSubscriber.sol";
import "./interface/0.6.x/IBSCValidatorSet.sol";
import "./interface/0.6.x/IApplication.sol";
import "./interface/0.6.x/IStakeHub.sol";
import "./lib/0.6.x/SafeMath.sol";
import "./lib/0.6.x/RLPDecode.sol";

contract BSCValidatorSet is IBSCValidatorSet, System, IParamSubscriber, IApplication {
    using SafeMath for uint256;

    using RLPDecode for *;

    bytes public constant INIT_VALIDATORSET_BYTES =
        hex"f905ec80f905e8f846942a7cdd959bfe8d9487b2a43b33565295a698f7e294b6a7edd747c0554875d3fc531d19ba1497992c5e941ff80f3f7f110ffd8920a3ac38fdef318fe94a3f86048c27395000f846946488aa4d1955ee33403f8ccb1d4de5fb97c7ade294220f003d8bdfaadf52aa1e55ae4cc485e6794875941a87e90e440a39c99aa9cb5cea0ad6a3f0b2407b86048c27395000f846949ef9f4360c606c7ab4db26b016007d3ad0ab86a0946103af86a874b705854033438383c82575f25bc29418e2db06cbff3e3c5f856410a1838649e760175786048c27395000f84694ee01c3b1283aa067c58eab4709f85e99d46de5fe94ee4b9bfb1871c64e2bcabb1dc382dc8b7c4218a29415904ab26ab0e99d70b51c220ccdcccabee6e29786048c27395000f84694685b1ded8013785d6623cc18d214320b6bb6475994a20ef4e5e4e7e36258dbf51f4d905114cb1b34bc9413e39085dc88704f4394d35209a02b1a9520320c86048c27395000f8469478f3adfc719c99674c072166708589033e2d9afe9448a30d5eaa7b64492a160f139e2da2800ec3834e94055838358c29edf4dcc1ba1985ad58aedbb6be2b86048c27395000f84694c2be4ec20253b8642161bc3f444f53679c1f3d479466f50c616d737e60d7ca6311ff0d9c434197898a94d1d678a2506eeaa365056fe565df8bc8659f28b086048c27395000f846942f7be8361c80a4c1e7e9aaf001d0877f1cfde218945f93992ac37f3e61db2ef8a587a436a161fd210b94ecbc4fb1a97861344dad0867ca3cba2b860411f086048c27395000f84694ce2fd7544e0b2cc94692d4a704debef7bcb613289444abc67b4b2fba283c582387f54c9cba7c34bafa948acc2ab395ded08bb75ce85bf0f95ad2abc51ad586048c27395000f84694b8f7166496996a7da21cf1f1b04d9b3e26a3d077946770572763289aac606e4f327c2f6cc1aa3b3e3b94882d745ed97d4422ca8da1c22ec49d880c4c097286048c27395000f846942d4c407bbe49438ed859fe965b140dcf1aab71a9943ad0939e120f33518fbba04631afe7a3ed6327b194b2bbb170ca4e499a2b0f3cc85ebfa6e8c4dfcbea86048c27395000f846946bbad7cf34b5fa511d8e963dbba288b1960e75d694853b0f6c324d1f4e76c8266942337ac1b0af1a229442498946a51ca5924552ead6fc2af08b94fcba648601d1a94a2000f846944430b3230294d12c6ab2aac5c2cd68e80b16b581947b107f4976a252a6939b771202c28e64e03f52d694795811a7f214084116949fc4f53cedbf189eeab28601d1a94a2000f84694ea0a6e3c511bbd10f4519ece37dc24887e11b55d946811ca77acfb221a49393c193f3a22db829fcc8e9464feb7c04830dd9ace164fc5c52b3f5a29e5018a8601d1a94a2000f846947ae2f5b9e386cd1b50a4550696d957cb4900f03a94e83bcc5077e6b873995c24bac871b5ad856047e19464e48d4057a90b233e026c1041e6012ada897fe88601d1a94a2000f8469482012708dafc9e1b880fd083b32182b869be8e09948e5adc73a2d233a1b496ed3115464dd6c7b887509428b383d324bc9a37f4e276190796ba5a8947f5ed8601d1a94a2000f8469422b81f8e175ffde54d797fe11eb03f9e3bf75f1d94a1c3ef7ca38d8ba80cce3bfc53ebd2903ed21658942767f7447f7b9b70313d4147b795414aecea54718601d1a94a2000f8469468bf0b8b6fb4e317a0f9d6f03eaf8ce6675bc60d94675cfe570b7902623f47e7f59c9664b5f5065dcf94d84f0d2e50bcf00f2fc476e1c57f5ca2d57f625b8601d1a94a2000f846948c4d90829ce8f72d0163c1d5cf348a862d5506309485c42a7b34309bee2ed6a235f86d16f059deec5894cc2cedc53f0fa6d376336efb67e43d167169f3b78601d1a94a2000f8469435e7a025f4da968de7e4d7e4004197917f4070f194b1182abaeeb3b4d8eba7e6a4162eac7ace23d57394c4fd0d870da52e73de2dd8ded19fe3d26f43a1138601d1a94a2000f84694d6caa02bbebaebb5d7e581e4b66559e635f805ff94c07335cf083c1c46a487f0325769d88e163b653694efaff03b42e41f953a925fc43720e45fb61a19938601d1a94a2000";

    uint256 public constant INIT_NUM_OF_CABINETS = 21;

    /*----------------- state of the contract -----------------*/
    Validator[] public currentValidatorSet;
    uint256 public expireTimeSecondGap;  // @dev deprecated
    uint256 public totalInComing;

    // key is the `consensusAddress` of `Validator`,
    // value is the index of the element in `currentValidatorSet`.
    mapping(address => uint256) public currentValidatorSetMap;
    uint256 public numOfJailed; // @dev deprecated

    uint256 public constant BLOCK_FEES_RATIO_SCALE = 10000;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant INIT_BURN_RATIO = 1000;
    uint256 public burnRatio;
    bool public burnRatioInitialized; // @dev deprecated

    // BEP-127 Temporary Maintenance
    uint256 public constant INIT_MAX_NUM_OF_MAINTAINING = 3;
    uint256 public constant INIT_MAINTAIN_SLASH_SCALE = 2;

    uint256 public maxNumOfMaintaining;
    uint256 public numOfMaintaining;
    uint256 public maintainSlashScale;

    // Corresponds strictly to currentValidatorSet
    // validatorExtraSet[index] = the `ValidatorExtra` info of currentValidatorSet[index]
    ValidatorExtra[] public validatorExtraSet;
    // BEP-131 candidate validator
    uint256 public numOfCabinets;
    uint256 public maxNumOfCandidates;
    uint256 public maxNumOfWorkingCandidates;

    // BEP-126 Fast Finality
    uint256 public constant INIT_SYSTEM_REWARD_RATIO = 625; // 625/10000 is 1/16
    uint256 public constant MAX_SYSTEM_REWARD_BALANCE = 100 ether;

    uint256 public systemRewardBaseRatio;
    uint256 public previousHeight;
    uint256 public previousBalanceOfSystemReward; // @dev deprecated
    bytes[] public previousVoteAddrFullSet;
    bytes[] public currentVoteAddrFullSet;
    bool public isSystemRewardIncluded;

    // BEP-294 BC-fusion
    Validator[] private _tmpMigratedValidatorSet; // @dev deprecated
    bytes[] private _tmpMigratedVoteAddrs; // @dev deprecated

    // BEP-341 Validators can produce consecutive blocks
    uint256 public turnLength; // Consecutive number of blocks a validator receives priority for block production
    uint256 public systemRewardAntiMEVRatio;

    struct Validator {
        address consensusAddress;
        address payable feeAddress;
        address BBCFeeAddress;
        uint64 votingPower;
        // only in state
        bool jailed;
        uint256 incoming;
    }

    struct ValidatorExtra {
        // BEP-127 Temporary Maintenance
        uint256 enterMaintenanceHeight; // the height from where the validator enters Maintenance
        bool isMaintaining;
        // BEP-126 Fast Finality
        bytes voteAddress;
        // reserve for future use
        uint256[19] slots;
    }

    struct ValidatorSetPackage {
        uint8 packageType;
        Validator[] validatorSet;
        bytes[] voteAddrs;
    }

    /*----------------- modifiers -----------------*/
    modifier noEmptyDeposit() {
        require(msg.value > 0, "deposit value is zero");
        _;
    }

    modifier initValidatorExtraSet() {
        if (validatorExtraSet.length == 0) {
            ValidatorExtra memory validatorExtra;
            // init validatorExtraSet
            uint256 validatorsNum = currentValidatorSet.length;
            for (uint256 i; i < validatorsNum; ++i) {
                validatorExtraSet.push(validatorExtra);
            }
        }

        _;
    }

    modifier oncePerBlock() {
        require(block.number > previousHeight, "can not do this twice in one block");
        _;
        previousHeight = block.number;
    }

    /*----------------- events -----------------*/
    event validatorSetUpdated();
    event systemTransfer(uint256 amount);
    event deprecatedDeposit(address indexed validator, uint256 amount);
    event validatorDeposit(address indexed validator, uint256 amount);
    event validatorMisdemeanor(address indexed validator, uint256 amount);
    event validatorFelony(address indexed validator, uint256 amount);
    event paramChange(string key, bytes value);
    event feeBurned(uint256 amount);
    event validatorEnterMaintenance(address indexed validator);
    event validatorExitMaintenance(address indexed validator);
    event finalityRewardDeposit(address indexed validator, uint256 amount);
    event deprecatedFinalityRewardDeposit(address indexed validator, uint256 amount);

    event validatorJailed(address indexed validator);  // @dev deprecated
    event validatorEmptyJailed(address indexed validator);  // @dev deprecated
    event batchTransfer(uint256 amount);  // @dev deprecated
    event batchTransferFailed(uint256 indexed amount, string reason);  // @dev deprecated
    event batchTransferLowerFailed(uint256 indexed amount, bytes reason);  // @dev deprecated
    event directTransfer(address payable indexed validator, uint256 amount);  // @dev deprecated
    event directTransferFail(address payable indexed validator, uint256 amount);  // @dev deprecated
    event failReasonWithStr(string message);  // @dev deprecated
    event unexpectedPackage(uint8 channelId, bytes msgBytes);  // @dev deprecated
    event tmpValidatorSetUpdated(uint256 validatorsNum);  // @dev deprecated

    /*----------------- init -----------------*/
    function init() external onlyNotInit {
        (ValidatorSetPackage memory validatorSetPkg, bool valid) =
            decodeValidatorSet(INIT_VALIDATORSET_BYTES);
        require(valid, "failed to parse init validatorSet");
        for (uint256 i; i < validatorSetPkg.validatorSet.length; ++i) {
            currentValidatorSet.push(validatorSetPkg.validatorSet[i]);
            currentValidatorSetMap[validatorSetPkg.validatorSet[i].consensusAddress] = i + 1;
        }
        alreadyInit = true;
    }

    receive() external payable { }

    /*----------------- Cross Chain App Implement -----------------*/
    function handleSynPackage(
        uint8,
        bytes calldata msgBytes
    ) external override onlyInit onlyCrossChainContract initValidatorExtraSet returns (bytes memory responsePayload) {
        revert("deprecated");
    }

    function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external override onlyCrossChainContract {
        revert("deprecated");
    }

    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external override onlyCrossChainContract {
        revert("deprecated");
    }

    /*----------------- External Functions -----------------*/
    /**
     * @dev Update validator set method after fusion fork.
     */
    function updateValidatorSetV2(
        address[] memory _consensusAddrs,
        uint64[] memory _votingPowers,
        bytes[] memory _voteAddrs
    ) public onlyCoinbase onlyZeroGasPrice {
        uint256 _length = _consensusAddrs.length;
        Validator[] memory _validatorSet = new Validator[](_length);
        for (uint256 i; i < _length; ++i) {
            _validatorSet[i] = Validator({
                consensusAddress: _consensusAddrs[i],
                feeAddress: payable(address(0)),
                BBCFeeAddress: address(0),
                votingPower: _votingPowers[i],
                jailed: false,
                incoming: 0
            });
        }

        // step 0: force all maintaining validators to exit `Temporary Maintenance`
        // - 1. validators exit maintenance
        // - 2. clear all maintainInfo
        // - 3. get unjailed validators from validatorSet
        (Validator[] memory validatorSetTemp, bytes[] memory voteAddrsTemp) =
            _forceMaintainingValidatorsExit(_validatorSet, _voteAddrs);

        // step 1: distribute incoming
        for (uint256 i; i < currentValidatorSet.length; ++i) {
            uint256 incoming = currentValidatorSet[i].incoming;
            if (incoming != 0) {
                currentValidatorSet[i].incoming = 0;
                IStakeHub(STAKE_HUB_ADDR).distributeReward{ value: incoming }(currentValidatorSet[i].consensusAddress);
            }
        }

        // step 2: do dusk transfer
        if (address(this).balance > 0) {
            emit systemTransfer(address(this).balance);
            address(uint160(SYSTEM_REWARD_ADDR)).transfer(address(this).balance);
        }

        // step 3: do update validator set state
        totalInComing = 0;
        if (validatorSetTemp.length != 0) {
            doUpdateState(validatorSetTemp, voteAddrsTemp);
        }

        // step 3: clean slash contract
        ISlashIndicator(SLASH_CONTRACT_ADDR).clean();
        emit validatorSetUpdated();
    }

    /**
     * @dev Collect all fee of transactions from the current block and deposit it to the contract
     *
     * @param valAddr The validator address who produced the current block
     */
    function deposit(address valAddr) external payable onlyCoinbase onlyInit noEmptyDeposit onlyZeroGasPrice {
        uint256 value = msg.value;
        uint256 index = currentValidatorSetMap[valAddr];

        if (isSystemRewardIncluded == false) {
            systemRewardBaseRatio = INIT_SYSTEM_REWARD_RATIO;
            burnRatio = INIT_BURN_RATIO;
            isSystemRewardIncluded = true;
        }

        uint256 systemRewardRatio = systemRewardBaseRatio;
        if (turnLength > 1 && systemRewardAntiMEVRatio > 0) {
            systemRewardRatio += systemRewardAntiMEVRatio * (block.number % turnLength) / (turnLength - 1);
        }

        if (value > 0 && systemRewardRatio > 0) {
            uint256 toSystemReward = msg.value.mul(systemRewardRatio).div(BLOCK_FEES_RATIO_SCALE);
            if (toSystemReward > 0) {
                address(uint160(SYSTEM_REWARD_ADDR)).transfer(toSystemReward);
                emit systemTransfer(toSystemReward);

                value = value.sub(toSystemReward);
            }
        }

        if (value > 0 && burnRatio > 0) {
            uint256 toBurn = msg.value.mul(burnRatio).div(BLOCK_FEES_RATIO_SCALE);
            if (toBurn > 0) {
                address(uint160(BURN_ADDRESS)).transfer(toBurn);
                emit feeBurned(toBurn);

                value = value.sub(toBurn);
            }
        }

        if (index > 0) {
            Validator storage validator = currentValidatorSet[index - 1];
            if (validator.jailed) {
                emit deprecatedDeposit(valAddr, value);
            } else {
                totalInComing = totalInComing.add(value);
                validator.incoming = validator.incoming.add(value);
                emit validatorDeposit(valAddr, value);
            }
        } else {
            // get incoming from deprecated validator;
            emit deprecatedDeposit(valAddr, value);
        }
    }

    function distributeFinalityReward(
        address[] calldata valAddrs,
        uint256[] calldata weights
    ) external onlyCoinbase oncePerBlock onlyZeroGasPrice onlyInit {
        uint256 totalValue;
        uint256 balanceOfSystemReward = address(SYSTEM_REWARD_ADDR).balance;
        if (balanceOfSystemReward > MAX_SYSTEM_REWARD_BALANCE) {
            // when a slash happens, theres will no rewards in some finalityReward intervals,
            // it's tolerated because slash happens rarely
            totalValue = balanceOfSystemReward.sub(MAX_SYSTEM_REWARD_BALANCE);
        } else {
            return;
        }

        totalValue = ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(payable(address(this)), totalValue);
        if (totalValue == 0) {
            return;
        }

        uint256 totalWeight;
        for (uint256 i; i < weights.length; ++i) {
            totalWeight += weights[i];
        }
        if (totalWeight == 0) {
            return;
        }

        uint256 value;
        address valAddr;
        uint256 index;

        for (uint256 i; i < valAddrs.length; ++i) {
            value = (totalValue * weights[i]) / totalWeight;
            valAddr = valAddrs[i];
            index = currentValidatorSetMap[valAddr];
            if (index > 0) {
                Validator storage validator = currentValidatorSet[index - 1];
                if (validator.jailed) {
                    emit deprecatedFinalityRewardDeposit(valAddr, value);
                } else {
                    totalInComing = totalInComing.add(value);
                    validator.incoming = validator.incoming.add(value);
                    emit finalityRewardDeposit(valAddr, value);
                }
            } else {
                // get incoming from deprecated validator;
                emit deprecatedFinalityRewardDeposit(valAddr, value);
            }
        }
    }

    /*----------------- View Functions -----------------*/
    /**
     * @notice Return the vote address and consensus address of the validators in `currentValidatorSet` that are not jailed
     */
    function getLivingValidators() external view override returns (address[] memory, bytes[] memory) {
        uint256 n = currentValidatorSet.length;
        uint256 living;
        for (uint256 i; i < n; ++i) {
            if (!currentValidatorSet[i].jailed) {
                living++;
            }
        }
        address[] memory consensusAddrs = new address[](living);
        bytes[] memory voteAddrs = new bytes[](living);
        living = 0;
        if (validatorExtraSet.length == n) {
            for (uint256 i; i < n; ++i) {
                if (!currentValidatorSet[i].jailed) {
                    consensusAddrs[living] = currentValidatorSet[i].consensusAddress;
                    voteAddrs[living] = validatorExtraSet[i].voteAddress;
                    living++;
                }
            }
        } else {
            for (uint256 i; i < n; ++i) {
                if (!currentValidatorSet[i].jailed) {
                    consensusAddrs[living] = currentValidatorSet[i].consensusAddress;
                    living++;
                }
            }
        }
        return (consensusAddrs, voteAddrs);
    }

    /**
     * @notice Return the vote address and consensus address of mining validators
     *
     * Mining validators are block producers in the current epoch
     * including most of the cabinets and a few of the candidates
     */
    function getMiningValidators() external view override returns (address[] memory, bytes[] memory) {
        uint256 _maxNumOfWorkingCandidates = maxNumOfWorkingCandidates;
        uint256 _numOfCabinets = numOfCabinets > 0 ? numOfCabinets : INIT_NUM_OF_CABINETS;
        uint256 _shuffleInterval = 200;

        address[] memory validators = getValidators();
        bytes[] memory voteAddrs = getVoteAddresses(validators);
        if (validators.length <= _numOfCabinets) {
            return (validators, voteAddrs);
        }

        if ((validators.length - _numOfCabinets) < _maxNumOfWorkingCandidates) {
            _maxNumOfWorkingCandidates = validators.length - _numOfCabinets;
        }
        if (_maxNumOfWorkingCandidates > 0) {
            uint256 shuffleNumber = block.number / _shuffleInterval;
            shuffle(
                validators,
                voteAddrs,
                shuffleNumber,
                _numOfCabinets - _maxNumOfWorkingCandidates,
                0,
                _maxNumOfWorkingCandidates,
                _numOfCabinets
            );
            shuffle(
                validators,
                voteAddrs,
                shuffleNumber,
                _numOfCabinets - _maxNumOfWorkingCandidates,
                _numOfCabinets - _maxNumOfWorkingCandidates,
                _maxNumOfWorkingCandidates,
                validators.length - _numOfCabinets + _maxNumOfWorkingCandidates
            );
        }
        address[] memory miningValidators = new address[](_numOfCabinets);
        bytes[] memory miningVoteAddrs = new bytes[](_numOfCabinets);
        for (uint256 i; i < _numOfCabinets; ++i) {
            miningValidators[i] = validators[i];
            miningVoteAddrs[i] = voteAddrs[i];
        }
        return (miningValidators, miningVoteAddrs);
    }

    /**
     * @notice Return the consensus address of the validators in `currentValidatorSet` that are not jailed and not maintaining
     */
    function getValidators() public view returns (address[] memory) {
        uint256 n = currentValidatorSet.length;
        uint256 valid = 0;
        for (uint256 i; i < n; ++i) {
            if (isWorkingValidator(i)) {
                ++valid;
            }
        }
        address[] memory consensusAddrs = new address[](valid);
        valid = 0;
        for (uint256 i; i < n; ++i) {
            if (isWorkingValidator(i)) {
                consensusAddrs[valid] = currentValidatorSet[i].consensusAddress;
                ++valid;
            }
        }
        return consensusAddrs;
    }

    /**
     * @notice Return the current incoming of the validator
     */
    function getIncoming(address validator) external view returns (uint256) {
        uint256 index = currentValidatorSetMap[validator];
        if (index <= 0) {
            return 0;
        }
        return currentValidatorSet[index - 1].incoming;
    }

    /**
     * @notice Return whether the validator is a working validator(not jailed or maintaining) by index
     *
     * @param index The index of the validator in `currentValidatorSet`(from 0 to `currentValidatorSet.length-1`)
     */
    function isWorkingValidator(uint256 index) public view returns (bool) {
        if (index >= currentValidatorSet.length) {
            return false;
        }

        // validatorExtraSet[index] should not be used before it has been init.
        if (index >= validatorExtraSet.length) {
            return !currentValidatorSet[index].jailed;
        }

        return !currentValidatorSet[index].jailed && !validatorExtraSet[index].isMaintaining;
    }

    /**
     * @notice Return whether the validator is a working validator(not jailed or maintaining) by consensus address
     * Will return false if the validator is not in `currentValidatorSet`
     */
    function isCurrentValidator(address validator) external view override returns (bool) {
        uint256 index = currentValidatorSetMap[validator];
        if (index <= 0) {
            return false;
        }

        // the actual index
        index = index - 1;
        return isWorkingValidator(index);
    }

    /**
     * @notice Return the index of the validator in `currentValidatorSet`(from 0 to `currentValidatorSet.length-1`)
     */
    function getCurrentValidatorIndex(address validator) public view returns (uint256) {
        uint256 index = currentValidatorSetMap[validator];
        require(index > 0, "only current validators");

        // the actual index
        return index - 1;
    }

    /**
     * @notice Return the number of mining validators.
     * The function name is misleading, it should be `getMiningValidatorCount`. But it's kept for compatibility.
     */
    function getWorkingValidatorCount() public view returns (uint256 workingValidatorCount) {
        workingValidatorCount = getValidators().length;
        uint256 _numOfCabinets = numOfCabinets > 0 ? numOfCabinets : INIT_NUM_OF_CABINETS;
        if (workingValidatorCount > _numOfCabinets) {
            workingValidatorCount = _numOfCabinets;
        }
        if (workingValidatorCount == 0) {
            workingValidatorCount = 1;
        }
    }

    /*----------------- For slash -----------------*/
    function misdemeanor(address validator) external override onlySlash initValidatorExtraSet {
        uint256 validatorIndex = _misdemeanor(validator);
        if (canEnterMaintenance(validatorIndex)) {
            _enterMaintenance(validator, validatorIndex);
        }
    }

    function felony(address validator) external override initValidatorExtraSet {
        require(msg.sender == SLASH_CONTRACT_ADDR || msg.sender == STAKE_HUB_ADDR, "only slash or stakeHub contract");

        uint256 index = currentValidatorSetMap[validator];
        if (index <= 0) {
            return;
        }
        // the actual index
        index = index - 1;

        bool isMaintaining = validatorExtraSet[index].isMaintaining;
        if (_felony(validator, index) && isMaintaining) {
            --numOfMaintaining;
        }
    }

    function removeTmpMigratedValidator(address validator) external onlyStakeHub {
        revert("deprecated");
    }

    /*----------------- For Temporary Maintenance -----------------*/
    /**
     * @notice Return whether the validator at index could enter maintenance
     */
    function canEnterMaintenance(uint256 index) public view returns (bool) {
        if (index >= currentValidatorSet.length) {
            return false;
        }

        if (
            currentValidatorSet[index].consensusAddress == address(0) // - 0. check if empty validator
                || (maxNumOfMaintaining == 0 || maintainSlashScale == 0) // - 1. check if not start
                || numOfMaintaining >= maxNumOfMaintaining // - 2. check if reached upper limit
                || !isWorkingValidator(index) // - 3. check if not working(not jailed and not maintaining)
                || validatorExtraSet[index].enterMaintenanceHeight > 0 // - 5. check if has Maintained during current 24-hour period
                    // current validators are selected every 24 hours(from 00:00:00 UTC to 23:59:59 UTC)
                || getValidators().length <= 1 // - 6. check num of remaining working validators
        ) {
            return false;
        }

        return true;
    }

    /**
     * @dev Enter maintenance for current validators. refer to https://github.com/bnb-chain/BEPs/blob/master/BEP127.md
     */
    function enterMaintenance() external initValidatorExtraSet {
        // check maintain config
        if (maxNumOfMaintaining == 0) {
            maxNumOfMaintaining = INIT_MAX_NUM_OF_MAINTAINING;
        }
        if (maintainSlashScale == 0) {
            maintainSlashScale = INIT_MAINTAIN_SLASH_SCALE;
        }

        uint256 index = getCurrentValidatorIndex(msg.sender);
        require(canEnterMaintenance(index), "can not enter Temporary Maintenance");
        _enterMaintenance(msg.sender, index);
    }

    /**
     * @dev Exit maintenance for current validators. refer to https://github.com/bnb-chain/BEPs/blob/master/BEP127.md
     */
    function exitMaintenance() external {
        uint256 index = getCurrentValidatorIndex(msg.sender);

        // jailed validators are allowed to exit maintenance
        require(validatorExtraSet[index].isMaintaining, "not in maintenance");
        uint256 miningValidatorCount = getWorkingValidatorCount();
        _exitMaintenance(msg.sender, index, miningValidatorCount, true);
    }

    /*----------------- Param update -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyInit onlyGov {
        if (Memory.compareStrings(key, "burnRatio")) {
            require(value.length == 32, "length of burnRatio mismatch");
            uint256 newBurnRatio = BytesToTypes.bytesToUint256(32, value);
            require(
                newBurnRatio.add(systemRewardBaseRatio).add(systemRewardAntiMEVRatio) <= BLOCK_FEES_RATIO_SCALE,
                "the burnRatio plus systemRewardBaseRatio and systemRewardAntiMEVRatio must be no greater than 10000"
            );
            burnRatio = newBurnRatio;
        } else if (Memory.compareStrings(key, "maxNumOfMaintaining")) {
            require(value.length == 32, "length of maxNumOfMaintaining mismatch");
            uint256 newMaxNumOfMaintaining = BytesToTypes.bytesToUint256(32, value);
            uint256 _numOfCabinets = numOfCabinets;
            if (_numOfCabinets == 0) {
                _numOfCabinets = INIT_NUM_OF_CABINETS;
            }
            require(newMaxNumOfMaintaining < _numOfCabinets, "the maxNumOfMaintaining must be less than numOfCabinets");
            maxNumOfMaintaining = newMaxNumOfMaintaining;
        } else if (Memory.compareStrings(key, "maintainSlashScale")) {
            require(value.length == 32, "length of maintainSlashScale mismatch");
            uint256 newMaintainSlashScale = BytesToTypes.bytesToUint256(32, value);
            require(
                newMaintainSlashScale > 0 && newMaintainSlashScale < 10,
                "the maintainSlashScale must be greater than 0 and less than 10"
            );
            maintainSlashScale = newMaintainSlashScale;
        } else if (Memory.compareStrings(key, "maxNumOfWorkingCandidates")) {
            require(value.length == 32, "length of maxNumOfWorkingCandidates mismatch");
            uint256 newMaxNumOfWorkingCandidates = BytesToTypes.bytesToUint256(32, value);
            require(
                newMaxNumOfWorkingCandidates <= maxNumOfCandidates,
                "the maxNumOfWorkingCandidates must be not greater than maxNumOfCandidates"
            );
            maxNumOfWorkingCandidates = newMaxNumOfWorkingCandidates;
        } else if (Memory.compareStrings(key, "maxNumOfCandidates")) {
            require(value.length == 32, "length of maxNumOfCandidates mismatch");
            uint256 newMaxNumOfCandidates = BytesToTypes.bytesToUint256(32, value);
            maxNumOfCandidates = newMaxNumOfCandidates;
            if (maxNumOfWorkingCandidates > maxNumOfCandidates) {
                maxNumOfWorkingCandidates = maxNumOfCandidates;
            }
        } else if (Memory.compareStrings(key, "numOfCabinets")) {
            require(value.length == 32, "length of numOfCabinets mismatch");
            uint256 newNumOfCabinets = BytesToTypes.bytesToUint256(32, value);
            require(newNumOfCabinets > 0, "the numOfCabinets must be greater than 0");

            uint256 maxElectedValidators = IStakeHub(STAKE_HUB_ADDR).maxElectedValidators();
            require(
                newNumOfCabinets <= maxElectedValidators, "the numOfCabinets must be less than maxElectedValidators"
            );

            numOfCabinets = newNumOfCabinets;
        } else if (Memory.compareStrings(key, "systemRewardBaseRatio")) {
            require(value.length == 32, "length of systemRewardBaseRatio mismatch");
            uint256 newSystemRewardBaseRatio = BytesToTypes.bytesToUint256(32, value);
            require(
                newSystemRewardBaseRatio.add(burnRatio).add(systemRewardAntiMEVRatio) <= BLOCK_FEES_RATIO_SCALE,
                "the systemRewardBaseRatio plus burnRatio and systemRewardAntiMEVRatio must be no greater than 10000"
            );
            systemRewardBaseRatio = newSystemRewardBaseRatio;
        } else if (Memory.compareStrings(key, "systemRewardAntiMEVRatio")) {
            require(value.length == 32, "length of systemRewardAntiMEVRatio mismatch");
            uint256 newSystemRewardAntiMEVRatio = BytesToTypes.bytesToUint256(32, value);
            require(
                newSystemRewardAntiMEVRatio.add(burnRatio).add(systemRewardBaseRatio) <= BLOCK_FEES_RATIO_SCALE,
                "the systemRewardAntiMEVRatio plus burnRatio and systemRewardBaseRatio must be no greater than 10000"
            );
            systemRewardAntiMEVRatio = newSystemRewardAntiMEVRatio;
        } else if (Memory.compareStrings(key, "turnLength")) {
            require(value.length == 32, "length of turnLength mismatch");
            uint256 newTurnLength = BytesToTypes.bytesToUint256(32, value);
            require(
                newTurnLength >= 3 && newTurnLength <= 64 || newTurnLength == 1,
                "the turnLength should be in [3,64] or equal to 1"
            );
            turnLength = newTurnLength;
        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }

    /*----------------- Internal Functions -----------------*/
    function doUpdateState(Validator[] memory newValidatorSet, bytes[] memory newVoteAddrs) private {
        uint256 n = currentValidatorSet.length;
        uint256 m = newValidatorSet.length;

        // delete stale validators
        for (uint256 i; i < n; ++i) {
            bool stale = true;
            Validator memory oldValidator = currentValidatorSet[i];
            for (uint256 j; j < m; ++j) {
                if (oldValidator.consensusAddress == newValidatorSet[j].consensusAddress) {
                    stale = false;
                    break;
                }
            }
            if (stale) {
                delete currentValidatorSetMap[oldValidator.consensusAddress];
            }
        }

        // if old validator set is larger than new validator set, pop the extra validators
        if (n > m) {
            for (uint256 i = m; i < n; ++i) {
                currentValidatorSet.pop();
                validatorExtraSet.pop();
            }
        }

        uint256 k = n < m ? n : m;
        for (uint256 i; i < k; ++i) {
            // if the validator is not the same, update the validator set directly
            if (!isSameValidator(newValidatorSet[i], currentValidatorSet[i])) {
                currentValidatorSetMap[newValidatorSet[i].consensusAddress] = i + 1;
                currentValidatorSet[i] = newValidatorSet[i];
                validatorExtraSet[i].voteAddress = newVoteAddrs[i];
                validatorExtraSet[i].isMaintaining = false;
                validatorExtraSet[i].enterMaintenanceHeight = 0;
            } else {
                currentValidatorSet[i].votingPower = newValidatorSet[i].votingPower;
                // update the vote address if it is different
                if (!BytesLib.equal(newVoteAddrs[i], validatorExtraSet[i].voteAddress)) {
                    validatorExtraSet[i].voteAddress = newVoteAddrs[i];
                }
            }
        }

        if (m > n) {
            ValidatorExtra memory _validatorExtra;
            for (uint256 i = n; i < m; ++i) {
                _validatorExtra.voteAddress = newVoteAddrs[i];
                currentValidatorSet.push(newValidatorSet[i]);
                validatorExtraSet.push(_validatorExtra);
                currentValidatorSetMap[newValidatorSet[i].consensusAddress] = i + 1;
            }
        }

        // update vote addr full set
        setPreviousVoteAddrFullSet();
        setCurrentVoteAddrFullSet();

        // make sure all new validators are cleared maintainInfo
        // should not happen, still protect
        numOfMaintaining = 0;
        n = currentValidatorSet.length;
        for (uint256 i; i < n; ++i) {
            validatorExtraSet[i].isMaintaining = false;
            validatorExtraSet[i].enterMaintenanceHeight = 0;
        }
    }

    /**
     * @dev With each shuffle interval blocks, there will be a partial rotation between cabinets and candidates. Rotation is determined by this function
     */
    function shuffle(
        address[] memory validators,
        bytes[] memory voteAddrs,
        uint256 shuffleNumber,
        uint256 startIdx,
        uint256 offset,
        uint256 limit,
        uint256 modNumber
    ) internal pure {
        for (uint256 i; i < limit; ++i) {
            uint256 random = uint256(keccak256(abi.encodePacked(shuffleNumber, startIdx + i))) % modNumber;
            if ((startIdx + i) != (offset + random)) {
                address tmpAddr = validators[startIdx + i];
                bytes memory tmpBLS = voteAddrs[startIdx + i];
                validators[startIdx + i] = validators[offset + random];
                validators[offset + random] = tmpAddr;
                voteAddrs[startIdx + i] = voteAddrs[offset + random];
                voteAddrs[offset + random] = tmpBLS;
            }
        }
    }

    /**
     * @dev Check if two validators are the same
     *
     * Vote address is not considered
     */
    function isSameValidator(Validator memory v1, Validator memory v2) private pure returns (bool) {
        return v1.consensusAddress == v2.consensusAddress && v1.feeAddress == v2.feeAddress
            && v1.BBCFeeAddress == v2.BBCFeeAddress;
    }

    function getVoteAddresses(address[] memory validators) internal view returns (bytes[] memory) {
        uint256 n = currentValidatorSet.length;
        uint256 length = validators.length;
        bytes[] memory voteAddrs = new bytes[](length);

        // check if validatorExtraSet has been initialized
        if (validatorExtraSet.length != n) {
            return voteAddrs;
        }

        for (uint256 i; i < length; ++i) {
            voteAddrs[i] = validatorExtraSet[currentValidatorSetMap[validators[i]] - 1].voteAddress;
        }
        return voteAddrs;
    }

    function getTurnLength() external view returns (uint256) {
        if (turnLength == 0) {
            return 1;
        }
        return turnLength;
    }

    function setPreviousVoteAddrFullSet() private {
        uint256 n = previousVoteAddrFullSet.length;
        uint256 m = currentVoteAddrFullSet.length;

        if (n > m) {
            for (uint256 i = m; i < n; ++i) {
                previousVoteAddrFullSet.pop();
            }
        }

        uint256 k = n < m ? n : m;
        for (uint256 i; i < k; ++i) {
            if (!BytesLib.equal(previousVoteAddrFullSet[i], currentVoteAddrFullSet[i])) {
                previousVoteAddrFullSet[i] = currentVoteAddrFullSet[i];
            }
        }

        if (m > n) {
            for (uint256 i = n; i < m; ++i) {
                previousVoteAddrFullSet.push(currentVoteAddrFullSet[i]);
            }
        }
    }

    function setCurrentVoteAddrFullSet() private {
        uint256 n = currentVoteAddrFullSet.length;
        uint256 m = validatorExtraSet.length;

        if (n > m) {
            for (uint256 i = m; i < n; ++i) {
                currentVoteAddrFullSet.pop();
            }
        }

        uint256 k = n < m ? n : m;
        for (uint256 i; i < k; ++i) {
            if (!BytesLib.equal(currentVoteAddrFullSet[i], validatorExtraSet[i].voteAddress)) {
                currentVoteAddrFullSet[i] = validatorExtraSet[i].voteAddress;
            }
        }

        if (m > n) {
            for (uint256 i = n; i < m; ++i) {
                currentVoteAddrFullSet.push(validatorExtraSet[i].voteAddress);
            }
        }
    }

    function isMonitoredForMaliciousVote(bytes calldata voteAddr) external view override returns (bool) {
        uint256 m = currentVoteAddrFullSet.length;
        for (uint256 i; i < m; ++i) {
            if (BytesLib.equal(voteAddr, currentVoteAddrFullSet[i])) {
                return true;
            }
        }

        uint256 n = previousVoteAddrFullSet.length;
        for (uint256 i; i < n; ++i) {
            if (BytesLib.equal(voteAddr, previousVoteAddrFullSet[i])) {
                return true;
            }
        }

        return false;
    }

    function _misdemeanor(address validator) private returns (uint256) {
        uint256 index = currentValidatorSetMap[validator];
        if (index <= 0) {
            return ~uint256(0);
        }
        // the actually index
        index = index - 1;

        uint256 income = currentValidatorSet[index].incoming;
        currentValidatorSet[index].incoming = 0;
        uint256 rest = currentValidatorSet.length - 1;
        emit validatorMisdemeanor(validator, income);
        if (rest == 0) {
            // should not happen, but still protect
            return index;
        }

        // averageDistribute*rest may less than income, but it is ok, the dust income will go to system reward eventually.
        uint256 averageDistribute = income / rest;
        if (averageDistribute != 0) {
            for (uint256 i; i < index; ++i) {
                currentValidatorSet[i].incoming = currentValidatorSet[i].incoming.add(averageDistribute);
            }
            uint256 n = currentValidatorSet.length;
            for (uint256 i = index + 1; i < n; ++i) {
                currentValidatorSet[i].incoming = currentValidatorSet[i].incoming.add(averageDistribute);
            }
        }

        return index;
    }

    function _felony(address validator, uint256 index) private returns (bool) {
        uint256 income = currentValidatorSet[index].incoming;
        uint256 rest = currentValidatorSet.length - 1;
        if (getValidators().length <= 1) {
            // will not remove the validator if it is the only one validator.
            currentValidatorSet[index].incoming = 0;
            return false;
        }
        emit validatorFelony(validator, income);

        // remove the validator from currentValidatorSet
        delete currentValidatorSetMap[validator];
        // remove felony validator
        for (uint256 i = index; i < (currentValidatorSet.length - 1); ++i) {
            currentValidatorSet[i] = currentValidatorSet[i + 1];
            validatorExtraSet[i] = validatorExtraSet[i + 1];
            currentValidatorSetMap[currentValidatorSet[i].consensusAddress] = i + 1;
        }
        currentValidatorSet.pop();
        validatorExtraSet.pop();

        // averageDistribute*rest may less than income, but it is ok, the dust income will go to system reward eventually.
        uint256 averageDistribute = income / rest;
        if (averageDistribute != 0) {
            uint256 n = currentValidatorSet.length;
            for (uint256 i; i < n; ++i) {
                currentValidatorSet[i].incoming = currentValidatorSet[i].incoming.add(averageDistribute);
            }
        }
        return true;
    }

    function _forceMaintainingValidatorsExit(
        Validator[] memory _validatorSet,
        bytes[] memory _voteAddrs
    ) private returns (Validator[] memory unjailedValidatorSet, bytes[] memory unjailedVoteAddrs) {
        uint256 numOfFelony = 0;
        address validator;
        bool isFelony;

        // 1. validators exit maintenance
        uint256 i;
        // caution: it must calculate miningValidatorCount before _exitMaintenance loop
        // because the miningValidatorCount will be changed in _exitMaintenance
        uint256 miningValidatorCount = getWorkingValidatorCount();
        // caution: it must loop from the endIndex to startIndex in currentValidatorSet
        // because the validators order in currentValidatorSet may be changed by _felony(validator)
        for (uint256 index = currentValidatorSet.length; index > 0; --index) {
            i = index - 1; // the actual index
            if (!validatorExtraSet[i].isMaintaining) {
                continue;
            }

            // only maintaining validators
            validator = currentValidatorSet[i].consensusAddress;

            // exit maintenance
            isFelony = _exitMaintenance(validator, i, miningValidatorCount, false);
            if (!isFelony) {
                continue;
            }

            // get the latest consensus address
            address latestConsensusAddress;
            address operatorAddress = IStakeHub(STAKE_HUB_ADDR).consensusToOperator(validator);
            if (operatorAddress != address(0)) {
                latestConsensusAddress = IStakeHub(STAKE_HUB_ADDR).getValidatorConsensusAddress(operatorAddress);
            }

            // record the jailed validator in validatorSet
            for (uint256 j; j < _validatorSet.length; ++j) {
                if (
                    _validatorSet[j].consensusAddress == validator
                        || _validatorSet[j].consensusAddress == latestConsensusAddress
                ) {
                    _validatorSet[j].jailed = true;
                    break;
                }
            }
        }

        // count the number of felony validators
        for (uint256 k; k < _validatorSet.length; ++k) {
            if (_validatorSet[k].jailed || _validatorSet[k].consensusAddress == address(0)) {
                ++numOfFelony;
            }
        }

        // 2. get unjailed validators from validatorSet
        if (numOfFelony >= _validatorSet.length) {
            // make sure there is at least one validator
            unjailedValidatorSet = new Validator[](1);
            unjailedVoteAddrs = new bytes[](1);
            unjailedValidatorSet[0] = _validatorSet[0];
            unjailedVoteAddrs[0] = _voteAddrs[0];
            unjailedValidatorSet[0].jailed = false;
        } else {
            unjailedValidatorSet = new Validator[](_validatorSet.length - numOfFelony);
            unjailedVoteAddrs = new bytes[](_validatorSet.length - numOfFelony);
            i = 0;
            for (uint256 index; index < _validatorSet.length; ++index) {
                if (!_validatorSet[index].jailed && _validatorSet[index].consensusAddress != address(0)) {
                    unjailedValidatorSet[i] = _validatorSet[index];
                    unjailedVoteAddrs[i] = _voteAddrs[index];
                    ++i;
                }
            }
        }

        return (unjailedValidatorSet, unjailedVoteAddrs);
    }

    function _enterMaintenance(address validator, uint256 index) private {
        ++numOfMaintaining;
        validatorExtraSet[index].isMaintaining = true;
        validatorExtraSet[index].enterMaintenanceHeight = block.number;
        emit validatorEnterMaintenance(validator);
    }

    function _exitMaintenance(
        address validator,
        uint256 index,
        uint256 miningValidatorCount,
        bool shouldRevert
    ) private returns (bool isFelony) {
        if (maintainSlashScale == 0 || miningValidatorCount == 0 || numOfMaintaining == 0) {
            // should not happen, still protect
            return false;
        }

        // step 0: modify numOfMaintaining
        --numOfMaintaining;

        // step 1: calculate slashCount
        uint256 slashCount = block.number.sub(validatorExtraSet[index].enterMaintenanceHeight).div(miningValidatorCount)
            .div(maintainSlashScale);

        // step 2: clear isMaintaining info
        validatorExtraSet[index].isMaintaining = false;

        // step 3: slash the validator
        (uint256 misdemeanorThreshold, uint256 felonyThreshold) =
            ISlashIndicator(SLASH_CONTRACT_ADDR).getSlashThresholds();
        isFelony = false;
        if (slashCount >= felonyThreshold) {
            _felony(validator, index);
            ISlashIndicator(SLASH_CONTRACT_ADDR).downtimeSlash(validator, slashCount, shouldRevert);
            isFelony = true;
        } else if (slashCount >= misdemeanorThreshold) {
            _misdemeanor(validator);
        }

        emit validatorExitMaintenance(validator);
    }

    function decodeValidatorSet(bytes memory msgBytes)
        internal
        pure
        returns (ValidatorSetPackage memory, bool)
    {
        ValidatorSetPackage memory validatorSetPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                validatorSetPkg.packageType = uint8(iter.next().toUint());
            } else if (idx == 1) {
                RLPDecode.RLPItem[] memory items = iter.next().toList();
                validatorSetPkg.validatorSet = new Validator[](items.length);
                validatorSetPkg.voteAddrs = new bytes[](items.length);
                for (uint256 j; j < items.length; ++j) {
                    (Validator memory val, bytes memory voteAddr, bool ok) = decodeValidator(items[j]);
                    if (!ok) {
                        return (validatorSetPkg, false);
                    }
                    validatorSetPkg.validatorSet[j] = val;
                    validatorSetPkg.voteAddrs[j] = voteAddr;
                }
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        return (validatorSetPkg, success);
    }

    function decodeValidator(RLPDecode.RLPItem memory itemValidator)
        internal
        pure
        returns (Validator memory, bytes memory, bool)
    {
        Validator memory validator;
        bytes memory voteAddr;
        RLPDecode.Iterator memory iter = itemValidator.iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                validator.consensusAddress = iter.next().toAddress();
            } else if (idx == 1) {
                validator.feeAddress = address(uint160(iter.next().toAddress()));
            } else if (idx == 2) {
                validator.BBCFeeAddress = iter.next().toAddress();
            } else if (idx == 3) {
                validator.votingPower = uint64(iter.next().toUint());
                success = true;
            } else if (idx == 4) {
                voteAddr = iter.next().toBytes();
            } else {
                break;
            }
            ++idx;
        }
        return (validator, voteAddr, success);
    }
}
