pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "./System.sol";
import "./lib/BytesLib.sol";
import "./lib/BytesToTypes.sol";
import "./lib/Memory.sol";
import "./interface/ILightClient.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/ITokenHub.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/IApplication.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPDecode.sol";
import "./lib/CmnPkg.sol";

interface ICrossChain {
  function channelHandlerContractMap(uint8 channelId) external view returns (address);
}

interface IStakeHub {
  function maxElectedValidators() external view returns (uint256);
  function distributeReward(address validator) external payable;
  function getEligibleValidators() external view returns (BSCValidatorSet.Validator[] memory, bytes[] memory);
  function getOperatorAddressByConsensusAddress(address consensusAddress) external view returns (address);
}

contract BSCValidatorSet is IBSCValidatorSet, System, IParamSubscriber, IApplication {

  using SafeMath for uint256;

  using RLPDecode for *;

  // will not transfer value less than 0.1 BNB for validators
  uint256 constant public DUSTY_INCOMING = 1e17;

  uint8 public constant JAIL_MESSAGE_TYPE = 1;
  uint8 public constant VALIDATORS_UPDATE_MESSAGE_TYPE = 0;

  // the precision of cross chain value transfer.
  uint256 public constant PRECISION = 1e10;
  uint256 public constant EXPIRE_TIME_SECOND_GAP = 1000;
  uint256 public constant MAX_NUM_OF_VALIDATORS = 41;

  bytes public constant INIT_VALIDATORSET_BYTES = hex"f87680f873f871949fb29aac15b9a4b7f17c3385939b007540f4d791949fb29aac15b9a4b7f17c3385939b007540f4d791949fb29aac15b9a4b7f17c3385939b007540f4d79164b085e6972fc98cd3c81d64d40e325acfed44365b97a7567a27939c14dbc7512ddcf54cb1284eb637cfa308ae4e00cb5588";

  uint32 public constant ERROR_UNKNOWN_PACKAGE_TYPE = 101;
  uint32 public constant ERROR_FAIL_CHECK_VALIDATORS = 102;
  uint32 public constant ERROR_LEN_OF_VAL_MISMATCH = 103;
  uint32 public constant ERROR_RELAYFEE_TOO_LARGE = 104;

  uint256 public constant INIT_NUM_OF_CABINETS = 21;
  uint256 public constant EPOCH = 200;

  /*********************** state of the contract **************************/
  Validator[] public currentValidatorSet;
  uint256 public expireTimeSecondGap;
  uint256 public totalInComing;

  // key is the `consensusAddress` of `Validator`,
  // value is the index of the element in `currentValidatorSet`.
  mapping(address =>uint256) public currentValidatorSetMap;
  uint256 public numOfJailed;

  uint256 public constant BURN_RATIO_SCALE = 10000;
  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
  uint256 public constant INIT_BURN_RATIO = 0;
  uint256 public burnRatio;
  bool public burnRatioInitialized;

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
  uint256 public constant INIT_FINALITY_REWARD_RATIO = 50;
  uint256 public constant MAX_SYSTEM_REWARD_BALANCE = 100 ether;

  uint256 public finalityRewardRatio;
  uint256 public previousHeight;
  uint256 public previousBalanceOfSystemReward;
  bytes[] public previousVoteAddrFullSet;
  bytes[] public currentVoteAddrFullSet;

  struct Validator {
    address consensusAddress;
    address payable feeAddress;
    address BBCFeeAddress;
    uint64  votingPower;

    // only in state
    bool jailed;
    uint256 incoming;
  }

  struct ValidatorExtra {
    // BEP-127 Temporary Maintenance
    uint256 enterMaintenanceHeight;     // the height from where the validator enters Maintenance
    bool isMaintaining;

    // BEP-126 Fast Finality
    bytes voteAddress;

    // reserve for future use
    uint256[19] slots;
  }

  /*********************** cross chain package **************************/
  struct IbcValidatorSetPackage {
    uint8  packageType;
    Validator[] validatorSet;
    bytes[] voteAddrs;
  }

  /*********************** modifiers **************************/
  modifier noEmptyDeposit() {
    require(msg.value > 0, "deposit value is zero");
    _;
  }

  modifier initValidatorExtraSet() {
    if (validatorExtraSet.length == 0) {
      ValidatorExtra memory validatorExtra;
      // init validatorExtraSet
      uint256 validatorsNum = currentValidatorSet.length;
      for (uint i; i<validatorsNum; ++i) {
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

  /*********************** events **************************/
  event validatorSetUpdated();
  event validatorJailed(address indexed validator);
  event validatorEmptyJailed(address indexed validator);
  event batchTransfer(uint256 amount);
  event batchTransferFailed(uint256 indexed amount, string reason);
  event batchTransferLowerFailed(uint256 indexed amount, bytes reason);
  event systemTransfer(uint256 amount);
  event directTransfer(address payable indexed validator, uint256 amount);
  event directTransferFail(address payable indexed validator, uint256 amount);
  event deprecatedDeposit(address indexed validator, uint256 amount);
  event validatorDeposit(address indexed validator, uint256 amount);
  event validatorMisdemeanor(address indexed validator, uint256 amount);
  event validatorFelony(address indexed validator, uint256 amount);
  event failReasonWithStr(string message);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);
  event paramChange(string key, bytes value);
  event feeBurned(uint256 amount);
  event validatorEnterMaintenance(address indexed validator);
  event validatorExitMaintenance(address indexed validator);
  event finalityRewardDeposit(address indexed validator, uint256 amount);
  event deprecatedFinalityRewardDeposit(address indexed validator, uint256 amount);

  /*********************** init **************************/
  function init() external onlyNotInit{
    (IbcValidatorSetPackage memory validatorSetPkg, bool valid)= decodeValidatorSetSynPackage(INIT_VALIDATORSET_BYTES);
    require(valid, "failed to parse init validatorSet");
    for (uint i; i<validatorSetPkg.validatorSet.length; ++i) {
      currentValidatorSet.push(validatorSetPkg.validatorSet[i]);
      currentValidatorSetMap[validatorSetPkg.validatorSet[i].consensusAddress] = i+1;
    }
    expireTimeSecondGap = EXPIRE_TIME_SECOND_GAP;
    alreadyInit = true;
  }

  receive() external payable {}

  /*********************** Cross Chain App Implement **************************/
  function handleSynPackage(uint8, bytes calldata msgBytes) onlyInit onlyCrossChainContract initValidatorExtraSet external override returns(bytes memory responsePayload) {
    (IbcValidatorSetPackage memory validatorSetPackage, bool ok) = decodeValidatorSetSynPackage(msgBytes);
    if (!ok) {
      return CmnPkg.encodeCommonAckPackage(ERROR_FAIL_DECODE);
    }
    uint32 resCode;
    if (validatorSetPackage.packageType == VALIDATORS_UPDATE_MESSAGE_TYPE) {
      resCode = updateValidatorSet(validatorSetPackage.validatorSet, validatorSetPackage.voteAddrs);
    } else if (validatorSetPackage.packageType == JAIL_MESSAGE_TYPE) {
      if (validatorSetPackage.validatorSet.length != 1) {
        emit failReasonWithStr("length of jail validators must be one");
        resCode = ERROR_LEN_OF_VAL_MISMATCH;
      } else {
        resCode = jailValidator(validatorSetPackage.validatorSet[0]);
      }
    } else {
      resCode = ERROR_UNKNOWN_PACKAGE_TYPE;
    }
    if (resCode == CODE_OK) {
      return new bytes(0);
    } else {
      return CmnPkg.encodeCommonAckPackage(resCode);
    }
  }

  function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract override {
    // should not happen
    emit unexpectedPackage(channelId, msgBytes);
  }

  function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract override {
    // should not happen
    emit unexpectedPackage(channelId, msgBytes);
  }

  /*********************** External Functions **************************/
  function updateValidatorSetV2() external onlyInit onlyCoinbase onlyZeroGasPrice {
    if (ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).channelHandlerContractMap(STAKING_CHANNELID) != address(0)) {
      return;
    }

    // step 0: force all maintaining validators to exit `Temporary Maintenance`
    // - 1. validators exit maintenance
    // - 2. clear all maintainInfo
    // - 3. get unjailed validators from validatorSet
    (Validator[] memory validatorSet, bytes[] memory voteAddrs) = IStakeHub(STAKE_HUB_ADDR).getEligibleValidators();
    (Validator[] memory validatorSetTemp, bytes[] memory voteAddrsTemp) = _forceMaintainingValidatorsExit(validatorSet, voteAddrs);

    // step 1: distribute incoming
    for (uint i; i < currentValidatorSet.length; ++i) {
      if (currentValidatorSet[i].incoming > 0) {
        IStakeHub(STAKE_HUB_ADDR).distributeReward{value : currentValidatorSet[i].incoming}(currentValidatorSet[i].consensusAddress);
      }
    }

    // step 2: do dusk transfer
    if (address(this).balance>0) {
      emit systemTransfer(address(this).balance);
      address(uint160(SYSTEM_REWARD_ADDR)).transfer(address(this).balance);
    }

    // step 3: do update validator set state
    totalInComing = 0;
    numOfJailed = 0;
    if (validatorSetTemp.length > 0) {
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
  function deposit(address valAddr) external payable onlyCoinbase onlyInit noEmptyDeposit{
    uint256 value = msg.value;
    uint256 index = currentValidatorSetMap[valAddr];

    uint256 curBurnRatio = INIT_BURN_RATIO;
    if (burnRatioInitialized) {
      curBurnRatio = burnRatio;
    }

    if (value > 0 && curBurnRatio > 0) {
      uint256 toBurn = value.mul(curBurnRatio).div(BURN_RATIO_SCALE);
      if (toBurn > 0) {
        address(uint160(BURN_ADDRESS)).transfer(toBurn);
        emit feeBurned(toBurn);

        value = value.sub(toBurn);
      }
    }

    if (index>0) {
      Validator storage validator = currentValidatorSet[index-1];
      if (validator.jailed) {
        emit deprecatedDeposit(valAddr,value);
      } else {
        totalInComing = totalInComing.add(value);
        validator.incoming = validator.incoming.add(value);
        emit validatorDeposit(valAddr,value);
      }
    } else {
      // get incoming from deprecated validator;
      emit deprecatedDeposit(valAddr,value);
    }
  }

  function jailValidator(Validator memory v) internal returns (uint32) {
    uint256 index = currentValidatorSetMap[v.consensusAddress];
    if (index==0 || currentValidatorSet[index-1].jailed) {
      emit validatorEmptyJailed(v.consensusAddress);
      return CODE_OK;
    }
    uint n = currentValidatorSet.length;
    bool shouldKeep = (numOfJailed >= n-1);
    // will not jail if it is the last valid validator
    if (shouldKeep) {
      emit validatorEmptyJailed(v.consensusAddress);
      return CODE_OK;
    }
    ++numOfJailed;
    currentValidatorSet[index-1].jailed = true;
    emit validatorJailed(v.consensusAddress);
    return CODE_OK;
  }

  function updateValidatorSet(Validator[] memory validatorSet, bytes[] memory voteAddrs) internal returns (uint32) {
    {
      // do verify.
      if (validatorSet.length > MAX_NUM_OF_VALIDATORS) {
        emit failReasonWithStr("the number of validators exceed the limit");
        return ERROR_FAIL_CHECK_VALIDATORS;
      }
      for (uint i; i<validatorSet.length; ++i) {
        for (uint j; j<i; ++j) {
          if (validatorSet[i].consensusAddress == validatorSet[j].consensusAddress) {
            emit failReasonWithStr("duplicate consensus address of validatorSet");
            return ERROR_FAIL_CHECK_VALIDATORS;
          }
        }
      }
    }

    // step 0: force all maintaining validators to exit `Temporary Maintenance`
    // - 1. validators exit maintenance
    // - 2. clear all maintainInfo
    // - 3. get unjailed validators from validatorSet
    Validator[] memory validatorSetTemp;
    bytes[] memory voteAddrsTemp;
    {
      // get migrated validators
      (Validator[] memory bscValidatorSet, bytes[] memory bscVoteAddrs) = IStakeHub(STAKE_HUB_ADDR).getEligibleValidators();
      (Validator[] memory mergedValidators, bytes[] memory mergedVoteAddrs) = _mergeValidatorSet(validatorSet, voteAddrs, bscValidatorSet, bscVoteAddrs);

      (validatorSetTemp, voteAddrsTemp) = _forceMaintainingValidatorsExit(mergedValidators, mergedVoteAddrs);
    }

    {
      //step 1: do calculate distribution, do not make it as an internal function for saving gas.
      uint crossSize;
      uint directSize;
      uint validatorsNum = currentValidatorSet.length;
      for (uint i; i<validatorsNum; ++i) {
        if (currentValidatorSet[i].incoming >= DUSTY_INCOMING) {
          ++crossSize;
        } else if (currentValidatorSet[i].incoming > 0) {
          ++directSize;
        }
      }

      //cross transfer
      address[] memory crossAddrs = new address[](crossSize);
      uint256[] memory crossAmounts = new uint256[](crossSize);
      uint256[] memory crossIndexes = new uint256[](crossSize);
      address[] memory crossRefundAddrs = new address[](crossSize);
      uint256 crossTotal;
      // direct transfer
      address payable[] memory directAddrs = new address payable[](directSize);
      uint256[] memory directAmounts = new uint256[](directSize);
      crossSize = 0;
      directSize = 0;
      uint256 relayFee = ITokenHub(TOKEN_HUB_ADDR).getMiniRelayFee();
      if (relayFee > DUSTY_INCOMING) {
        emit failReasonWithStr("fee is larger than DUSTY_INCOMING");
        return ERROR_RELAYFEE_TOO_LARGE;
      }
      for (uint i; i < validatorsNum; ++i) {
        if (IStakeHub(STAKE_HUB_ADDR).getOperatorAddressByConsensusAddress(currentValidatorSet[i].consensusAddress) != address(0)) {
          directAddrs[directSize] = payable(currentValidatorSet[i].consensusAddress);
          directAmounts[directSize] = currentValidatorSet[i].incoming;
          ++directSize;
        } else if (currentValidatorSet[i].incoming >= DUSTY_INCOMING) {
          crossAddrs[crossSize] = currentValidatorSet[i].BBCFeeAddress;
          uint256 value = currentValidatorSet[i].incoming - currentValidatorSet[i].incoming % PRECISION;
          crossAmounts[crossSize] = value.sub(relayFee);
          crossRefundAddrs[crossSize] = currentValidatorSet[i].feeAddress;
          crossIndexes[crossSize] = i;
          crossTotal = crossTotal.add(value);
          ++crossSize;
        } else if (currentValidatorSet[i].incoming > 0) {
          directAddrs[directSize] = currentValidatorSet[i].feeAddress;
          directAmounts[directSize] = currentValidatorSet[i].incoming;
          ++directSize;
        }
      }

      //step 2: do cross chain transfer
      bool failCross = false;
      if (crossTotal > 0) {
        try ITokenHub(TOKEN_HUB_ADDR).batchTransferOutBNB{value : crossTotal}(crossAddrs, crossAmounts, crossRefundAddrs, uint64(block.timestamp + expireTimeSecondGap)) returns (bool success) {
          if (success) {
            emit batchTransfer(crossTotal);
          } else {
            emit batchTransferFailed(crossTotal, "batch transfer return false");
          }
        }catch Error(string memory reason) {
          failCross = true;
          emit batchTransferFailed(crossTotal, reason);
        }catch (bytes memory lowLevelData) {
          failCross = true;
          emit batchTransferLowerFailed(crossTotal, lowLevelData);
        }
      }

      if (failCross) {
        for (uint i; i<crossIndexes.length; ++i) {
          uint idx = crossIndexes[i];
          bool success = currentValidatorSet[idx].feeAddress.send(currentValidatorSet[idx].incoming);
          if (success) {
            emit directTransfer(currentValidatorSet[idx].feeAddress, currentValidatorSet[idx].incoming);
          } else {
            emit directTransferFail(currentValidatorSet[idx].feeAddress, currentValidatorSet[idx].incoming);
          }
        }
      }

      // step 3: direct transfer
      if (directAddrs.length > 0) {
        for (uint i; i < directAddrs.length; ++i) {
          if (IStakeHub(STAKE_HUB_ADDR).getOperatorAddressByConsensusAddress(directAddrs[i]) != address(0)) {
            IStakeHub(STAKE_HUB_ADDR).distributeReward{value : directAmounts[i]}(directAddrs[i]);
          } else {
            bool success = directAddrs[i].send(directAmounts[i]);
            if (success) {
              emit directTransfer(directAddrs[i], directAmounts[i]);
            } else {
              emit directTransferFail(directAddrs[i], directAmounts[i]);
            }
          }
        }
      }
    }

    // step 4: do dusk transfer
    if (address(this).balance>0) {
      emit systemTransfer(address(this).balance);
      address(uint160(SYSTEM_REWARD_ADDR)).transfer(address(this).balance);
    }

    // step 5: do update validator set state
    totalInComing = 0;
    numOfJailed = 0;
    if (validatorSetTemp.length > 0) {
      doUpdateState(validatorSetTemp, voteAddrsTemp);
    }

    // step 6: clean slash contract
    ISlashIndicator(SLASH_CONTRACT_ADDR).clean();
    emit validatorSetUpdated();
    return CODE_OK;
  }

  /**
   * @dev With each epoch, there will be a partial rotation between cabinets and candidates. Rotation is determined by this function
   *
   */
  function shuffle(address[] memory validators, bytes[] memory voteAddrs, uint256 epochNumber, uint startIdx, uint offset, uint limit, uint modNumber) internal pure {
    for (uint i; i<limit; ++i) {
      uint random = uint(keccak256(abi.encodePacked(epochNumber, startIdx+i))) % modNumber;
      if ( (startIdx+i) != (offset+random) ) {
        address tmpAddr = validators[startIdx+i];
        bytes memory tmpBLS = voteAddrs[startIdx+i];
        validators[startIdx+i] = validators[offset+random];
        validators[offset+random] = tmpAddr;
        voteAddrs[startIdx+i] = voteAddrs[offset+random];
        voteAddrs[offset+random] = tmpBLS;
      }
    }
  }

  function getLivingValidators() external view override returns (address[] memory, bytes[] memory) {
    uint n = currentValidatorSet.length;
    uint living;
    for (uint i; i<n; ++i) {
      if (!currentValidatorSet[i].jailed) {
        living ++;
      }
    }
    address[] memory consensusAddrs = new address[](living);
    bytes[] memory voteAddrs = new bytes[](living);
    living = 0;
    if (validatorExtraSet.length == n) {
      for (uint i; i<n; ++i) {
        if (!currentValidatorSet[i].jailed) {
          consensusAddrs[living] = currentValidatorSet[i].consensusAddress;
          voteAddrs[living] = validatorExtraSet[i].voteAddress;
          living ++;
        }
      }
    } else {
      for (uint i; i<n; ++i) {
        if (!currentValidatorSet[i].jailed) {
          consensusAddrs[living] = currentValidatorSet[i].consensusAddress;
          living ++;
        }
      }
    }
    return (consensusAddrs, voteAddrs);
  }

  /**
   * @dev Get mining validators that are block producers in the current epoch, including most of the cabinets and a few of the candidates
   */
  function getMiningValidators() external view override returns(address[] memory, bytes[] memory) {
    uint256 _maxNumOfWorkingCandidates = maxNumOfWorkingCandidates;
    uint256 _numOfCabinets = numOfCabinets;
    if (_numOfCabinets == 0 ){
      _numOfCabinets = INIT_NUM_OF_CABINETS;
    }

    address[] memory validators = getValidators();
    bytes[] memory voteAddrs = getVoteAddresses(validators);
    if (validators.length <= _numOfCabinets) {
      return (validators, voteAddrs);
    }

    if ((validators.length - _numOfCabinets) < _maxNumOfWorkingCandidates){
      _maxNumOfWorkingCandidates = validators.length - _numOfCabinets;
    }
    if (_maxNumOfWorkingCandidates > 0) {
      uint256 epochNumber = block.number / EPOCH;
      shuffle(validators, voteAddrs, epochNumber, _numOfCabinets-_maxNumOfWorkingCandidates, 0, _maxNumOfWorkingCandidates, _numOfCabinets);
      shuffle(validators, voteAddrs, epochNumber, _numOfCabinets-_maxNumOfWorkingCandidates, _numOfCabinets-_maxNumOfWorkingCandidates,
        _maxNumOfWorkingCandidates, validators.length - _numOfCabinets+_maxNumOfWorkingCandidates);
    }
    address[] memory miningValidators = new address[](_numOfCabinets);
    bytes[] memory miningVoteAddrs = new bytes[](_numOfCabinets);
    for (uint i; i<_numOfCabinets; ++i) {
      miningValidators[i] = validators[i];
      miningVoteAddrs[i] = voteAddrs[i];
    }
    return (miningValidators, miningVoteAddrs);
  }

  /**
   * @dev Get all validators, including all of the cabinets and all of the candidates
   *
   */
  function getValidators() public view returns(address[] memory) {
    uint n = currentValidatorSet.length;
    uint valid = 0;
    for (uint i; i<n; ++i) {
      if (isWorkingValidator(i)) {
        ++valid;
      }
    }
    address[] memory consensusAddrs = new address[](valid);
    valid = 0;
    for (uint i; i<n; ++i) {
      if (isWorkingValidator(i)) {
        consensusAddrs[valid] = currentValidatorSet[i].consensusAddress;
        ++valid;
      }
    }
    return consensusAddrs;
  }

  function isWorkingValidator(uint index) public view returns (bool) {
    if (index >= currentValidatorSet.length) {
      return false;
    }

    // validatorExtraSet[index] should not be used before it has been init.
    if (index >= validatorExtraSet.length) {
      return !currentValidatorSet[index].jailed;
    }

    return !currentValidatorSet[index].jailed && !validatorExtraSet[index].isMaintaining;
  }

  function getIncoming(address validator)external view returns(uint256) {
    uint256 index = currentValidatorSetMap[validator];
    if (index<=0) {
      return 0;
    }
    return currentValidatorSet[index-1].incoming;
  }

  function isCurrentValidator(address validator) external view override returns (bool) {
    uint256 index = currentValidatorSetMap[validator];
    if (index <= 0) {
      return false;
    }

    // the actual index
    index = index - 1;
    return isWorkingValidator(index);
  }

  function distributeFinalityReward(address[] calldata valAddrs, uint256[] calldata weights) external onlyCoinbase oncePerBlock onlyInit {
    // first time to call this function
    if (finalityRewardRatio == 0) {
      finalityRewardRatio = INIT_FINALITY_REWARD_RATIO;
      previousBalanceOfSystemReward = address(SYSTEM_REWARD_ADDR).balance;
      return;
    }

    uint256 totalValue;
    uint256 balanceOfSystemReward = address(SYSTEM_REWARD_ADDR).balance;
    if (balanceOfSystemReward > MAX_SYSTEM_REWARD_BALANCE) {
      totalValue = balanceOfSystemReward.div(100);
    } else if (balanceOfSystemReward > previousBalanceOfSystemReward) {
      // when a slash happens, theres will no rewards in some epoches,
      // it's tolerated because slash happens rarely
      totalValue = (balanceOfSystemReward.sub(previousBalanceOfSystemReward)).mul(finalityRewardRatio).div(100);
    } else {
      return;
    }

    totalValue = ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(payable(address(this)), totalValue);
    previousBalanceOfSystemReward = address(SYSTEM_REWARD_ADDR).balance;
    if (totalValue == 0) {
      return;
    }

    uint256 totalWeight;
    for (uint256 i; i<weights.length; ++i) {
      totalWeight += weights[i];
    }
    if (totalWeight == 0) {
      return;
    }

    uint256 value;
    address valAddr;
    uint256 index;

    for (uint256 i; i<valAddrs.length; ++i) {
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

  function getWorkingValidatorCount() public view returns(uint256 workingValidatorCount) {
    workingValidatorCount = getValidators().length;
    uint256 _numOfCabinets = numOfCabinets > 0 ? numOfCabinets : INIT_NUM_OF_CABINETS;
    if (workingValidatorCount > _numOfCabinets) {
      workingValidatorCount = _numOfCabinets;
    }
    if (workingValidatorCount == 0) {
      workingValidatorCount = 1;
    }
  }

  /*********************** For slash **************************/
  function misdemeanor(address validator) external onlySlash initValidatorExtraSet override {
    uint256 validatorIndex = _misdemeanor(validator);
    if (canEnterMaintenance(validatorIndex)) {
      _enterMaintenance(validator, validatorIndex);
    }
  }

  function felony(address validator)external onlySlash initValidatorExtraSet override{
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

  /*********************** For Temporary Maintenance **************************/
  function getCurrentValidatorIndex(address _validator) public view returns (uint256) {
    uint256 index = currentValidatorSetMap[_validator];
    require(index > 0, "only current validators");

    // the actual index
    return index - 1;
  }

  function canEnterMaintenance(uint256 index) public view returns (bool) {
    if (index >= currentValidatorSet.length) {
      return false;
    }

    if (
      currentValidatorSet[index].consensusAddress == address(0)     // - 0. check if empty validator
      || (maxNumOfMaintaining == 0 || maintainSlashScale == 0)      // - 1. check if not start
      || numOfMaintaining >= maxNumOfMaintaining                    // - 2. check if reached upper limit
      || !isWorkingValidator(index)                                 // - 3. check if not working(not jailed and not maintaining)
      || validatorExtraSet[index].enterMaintenanceHeight > 0        // - 5. check if has Maintained during current 24-hour period
                                                                    // current validators are selected every 24 hours(from 00:00:00 UTC to 23:59:59 UTC)
      || getValidators().length <= 1                                // - 6. check num of remaining working validators
    ) {
      return false;
    }

    return true;
  }

  /**
   * @dev Enter maintenance for current validators. refer to https://github.com/bnb-chain/BEPs/blob/master/BEP127.md
   *
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
   *
   */
  function exitMaintenance() external {
    uint256 index = getCurrentValidatorIndex(msg.sender);

    // jailed validators are allowed to exit maintenance
    require(validatorExtraSet[index].isMaintaining, "not in maintenance");
    uint256 workingValidatorCount = getWorkingValidatorCount();
    _exitMaintenance(msg.sender, index, workingValidatorCount);
  }

  /*********************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) override external onlyInit onlyGov{
    if (Memory.compareStrings(key, "expireTimeSecondGap")) {
      require(value.length == 32, "length of expireTimeSecondGap mismatch");
      uint256 newExpireTimeSecondGap = BytesToTypes.bytesToUint256(32, value);
      require(newExpireTimeSecondGap >=100 && newExpireTimeSecondGap <= 1e5, "the expireTimeSecondGap is out of range");
      expireTimeSecondGap = newExpireTimeSecondGap;
    } else if (Memory.compareStrings(key, "burnRatio")) {
      require(value.length == 32, "length of burnRatio mismatch");
      uint256 newBurnRatio = BytesToTypes.bytesToUint256(32, value);
      require(newBurnRatio <= BURN_RATIO_SCALE, "the burnRatio must be no greater than 10000");
      burnRatio = newBurnRatio;
      burnRatioInitialized = true;
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
      require(newMaintainSlashScale > 0 && newMaintainSlashScale < 10, "the maintainSlashScale must be greater than 0 and less than 10");
      maintainSlashScale = newMaintainSlashScale;
    } else if (Memory.compareStrings(key, "maxNumOfWorkingCandidates")) {
      require(value.length == 32, "length of maxNumOfWorkingCandidates mismatch");
      uint256 newMaxNumOfWorkingCandidates = BytesToTypes.bytesToUint256(32, value);
      require(newMaxNumOfWorkingCandidates <= maxNumOfCandidates, "the maxNumOfWorkingCandidates must be not greater than maxNumOfCandidates");
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
      require(newNumOfCabinets <= MAX_NUM_OF_VALIDATORS, "the numOfCabinets must be less than MAX_NUM_OF_VALIDATORS");
      numOfCabinets = newNumOfCabinets;
    } else if (Memory.compareStrings(key, "finalityRewardRatio")) {
      require(value.length == 32, "length of finalityRewardRatio mismatch");
      uint256 newFinalityRewardRatio = BytesToTypes.bytesToUint256(32, value);
      require(newFinalityRewardRatio >= 1 && newFinalityRewardRatio <= 100, "the finalityRewardRatio is out of range");
      finalityRewardRatio = newFinalityRewardRatio;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  /*********************** Internal Functions **************************/
  function doUpdateState(Validator[] memory newValidatorSet, bytes[] memory newVoteAddrs) private {
    uint n = currentValidatorSet.length;
    uint m = newValidatorSet.length;

    // delete stale validators
    for (uint i; i<n; ++i) {
      bool stale = true;
      Validator memory oldValidator = currentValidatorSet[i];
      for (uint j; j<m; ++j) {
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
    if (n>m) {
      for (uint i=m; i<n; ++i) {
        currentValidatorSet.pop();
        validatorExtraSet.pop();
      }
    }

    uint k = n < m ? n:m;
    for (uint i; i<k; ++i) {
      // if the validator is not the same, update the validator set directly
      if (!isSameValidator(newValidatorSet[i], currentValidatorSet[i])) {
        currentValidatorSetMap[newValidatorSet[i].consensusAddress] = i+1;
        currentValidatorSet[i] = newValidatorSet[i];
        validatorExtraSet[i].voteAddress = newVoteAddrs[i];
        validatorExtraSet[i].isMaintaining = false;
        validatorExtraSet[i].enterMaintenanceHeight = 0;
      } else {
        // if the validator is the same, update the vote address if it is different
        if (!BytesLib.equal(newVoteAddrs[i], validatorExtraSet[i].voteAddress)) {
          validatorExtraSet[i].voteAddress = newVoteAddrs[i];
        }
        currentValidatorSet[i].incoming = 0;
      }
    }

    if (m>n) {
      ValidatorExtra memory _validatorExtra;
      for (uint i=n; i < m; ++i) {
        _validatorExtra.voteAddress = newVoteAddrs[i];
        currentValidatorSet.push(newValidatorSet[i]);
        validatorExtraSet.push(_validatorExtra);
        currentValidatorSetMap[newValidatorSet[i].consensusAddress] = i+1;
      }
    }

    // update vote addr full set
    setPreviousVoteAddrFullSet();
    setCurrentVoteAddrFullSet();

    // make sure all new validators are cleared maintainInfo
    // should not happen, still protect
    numOfMaintaining = 0;
    n = currentValidatorSet.length;
    for (uint i; i<n; ++i) {
      validatorExtraSet[i].isMaintaining = false;
      validatorExtraSet[i].enterMaintenanceHeight = 0;
    }
  }

  /**
   * @dev Check if two validators are the same
   *
   * Vote address is not considered
   */
  function isSameValidator(Validator memory v1, Validator memory v2) private pure returns(bool) {
    return v1.consensusAddress == v2.consensusAddress && v1.feeAddress == v2.feeAddress && v1.BBCFeeAddress == v2.BBCFeeAddress && v1.votingPower == v2.votingPower;
  }

  function getVoteAddresses(address[] memory validators) internal view returns(bytes[] memory) {
    uint n = currentValidatorSet.length;
    uint length = validators.length;
    bytes[] memory voteAddrs = new bytes[](length);

    // check if validatorExtraSet has been initialized
    if (validatorExtraSet.length != n) {
      return voteAddrs;
    }

    for (uint i; i<length; ++i) {
      voteAddrs[i] = validatorExtraSet[currentValidatorSetMap[validators[i]]-1].voteAddress;
    }
    return voteAddrs;
  }

  function setPreviousVoteAddrFullSet() private {
    uint n = previousVoteAddrFullSet.length;
    uint m = currentVoteAddrFullSet.length;

    if (n>m) {
      for (uint i=m; i<n; ++i) {
        previousVoteAddrFullSet.pop();
      }
    }

    uint k = n < m ? n:m;
    for (uint i; i<k; ++i) {
      if (!BytesLib.equal(previousVoteAddrFullSet[i], currentVoteAddrFullSet[i])) {
        previousVoteAddrFullSet[i] = currentVoteAddrFullSet[i];
      }
    }

    if (m>n) {
      for (uint i=n; i < m; ++i) {
        previousVoteAddrFullSet.push(currentVoteAddrFullSet[i]);
      }
    }
  }

  function setCurrentVoteAddrFullSet() private {
    uint n = currentVoteAddrFullSet.length;
    uint m = validatorExtraSet.length;

    if (n>m) {
      for (uint i=m; i<n; ++i) {
        currentVoteAddrFullSet.pop();
      }
    }

    uint k = n < m ? n:m;
    for (uint i; i<k; ++i) {
      if (!BytesLib.equal(currentVoteAddrFullSet[i], validatorExtraSet[i].voteAddress)) {
        currentVoteAddrFullSet[i] = validatorExtraSet[i].voteAddress;
      }
    }

    if (m>n) {
      for (uint i=n; i < m; ++i) {
        currentVoteAddrFullSet.push(validatorExtraSet[i].voteAddress);
      }
    }
  }

  function isMonitoredForMaliciousVote(bytes calldata voteAddr) external override view returns (bool) {
    uint m = currentVoteAddrFullSet.length;
    for (uint i; i<m; ++i) {
      if (BytesLib.equal(voteAddr, currentVoteAddrFullSet[i])) {
        return true;
      }
    }

    uint n = previousVoteAddrFullSet.length;
    for (uint i; i<n; ++i) {
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
    uint256 averageDistribute = income / rest;
    if (averageDistribute != 0) {
      for (uint i; i<index; ++i) {
        currentValidatorSet[i].incoming = currentValidatorSet[i].incoming + averageDistribute;
      }
      uint n = currentValidatorSet.length;
      for (uint i=index+1; i<n; ++i) {
        currentValidatorSet[i].incoming = currentValidatorSet[i].incoming + averageDistribute;
      }
    }
    // averageDistribute*rest may less than income, but it is ok, the dust income will go to system reward eventually.

    return index;
  }

  function _felony(address validator, uint256 index) private returns (bool){
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
    for (uint i=index; i<(currentValidatorSet.length-1); ++i) {
      currentValidatorSet[i] = currentValidatorSet[i+1];
      validatorExtraSet[i] = validatorExtraSet[i+1];
      currentValidatorSetMap[currentValidatorSet[i].consensusAddress] = i+1;
    }
    currentValidatorSet.pop();
    validatorExtraSet.pop();

    // averageDistribute*rest may less than income, but it is ok, the dust income will go to system reward eventually.
    uint256 averageDistribute = income / rest;
    if (averageDistribute != 0) {
      uint n = currentValidatorSet.length;
      for (uint i; i<n; ++i) {
        currentValidatorSet[i].incoming = currentValidatorSet[i].incoming + averageDistribute;
      }
    }
    return true;
  }

  function _forceMaintainingValidatorsExit(Validator[] memory _validatorSet, bytes[] memory _voteAddrs) private returns (Validator[] memory unjailedValidatorSet, bytes[] memory unjailedVoteAddrs){
    uint256 numOfFelony = 0;
    address validator;
    bool isFelony;

    // 1. validators exit maintenance
    uint256 i;
    // caution: it must calculate workingValidatorCount before _exitMaintenance loop
    // because the workingValidatorCount will be changed in _exitMaintenance
    uint256 workingValidatorCount = getWorkingValidatorCount();
    // caution: it must loop from the endIndex to startIndex in currentValidatorSet
    // because the validators order in currentValidatorSet may be changed by _felony(validator)
    for (uint index = currentValidatorSet.length; index > 0; --index) {
      i = index - 1;  // the actual index
      if (!validatorExtraSet[i].isMaintaining) {
        continue;
      }

      // only maintaining validators
      validator = currentValidatorSet[i].consensusAddress;

      // exit maintenance
      isFelony = _exitMaintenance(validator, i, workingValidatorCount);
      if (!isFelony || numOfFelony >= _validatorSet.length - 1) {
        continue;
      }

      // record the jailed validator in validatorSet
      for (uint k; k<_validatorSet.length; ++k) {
        if (_validatorSet[k].consensusAddress == validator) {
          _validatorSet[k].jailed = true;
          ++numOfFelony;
          break;
        }
      }
    }

    // 2. get unjailed validators from validatorSet
    unjailedValidatorSet = new Validator[](_validatorSet.length - numOfFelony);
    unjailedVoteAddrs = new bytes[](_validatorSet.length - numOfFelony);
    i = 0;
    for (uint index; index<_validatorSet.length; ++index) {
      if (!_validatorSet[index].jailed) {
        unjailedValidatorSet[i] = _validatorSet[index];
        unjailedVoteAddrs[i] = _voteAddrs[index];
        ++i;
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

  function _exitMaintenance(address validator, uint index, uint256 workingValidatorCount) private returns (bool isFelony){
    if (maintainSlashScale == 0 || workingValidatorCount == 0 || numOfMaintaining == 0) {
      // should not happen, still protect
      return false;
    }

    // step 0: modify numOfMaintaining
    --numOfMaintaining;

    // step 1: calculate slashCount
    uint256 slashCount =
      block.number
        .sub(validatorExtraSet[index].enterMaintenanceHeight)
        .div(workingValidatorCount)
        .div(maintainSlashScale);

    // step 2: clear maintaining info of the validator
    validatorExtraSet[index].isMaintaining = false;

    // step3: slash the validator
    (uint256 misdemeanorThreshold, uint256 felonyThreshold) = ISlashIndicator(SLASH_CONTRACT_ADDR).getSlashThresholds();
    isFelony = false;
    if (slashCount >= felonyThreshold) {
      _felony(validator, index);
      if (IStakeHub(STAKE_HUB_ADDR).getOperatorAddressByConsensusAddress(validator) != address(0)) {
        ISlashIndicator(SLASH_CONTRACT_ADDR).downtimeSlash(validator, slashCount);
      } else {
        ISlashIndicator(SLASH_CONTRACT_ADDR).sendFelonyPackage(validator);
      }
      isFelony = true;
    } else if (slashCount >= misdemeanorThreshold) {
      _misdemeanor(validator);
    }

    emit validatorExitMaintenance(validator);
  }

  function _mergeValidatorSet(Validator[] memory validatorSet1, bytes[] memory voteAddrSet1, Validator[] memory validatorSet2, bytes[] memory voteAddrSet2) internal view returns (Validator[] memory, bytes[] memory) {
    uint256 _length = IStakeHub(STAKE_HUB_ADDR).maxElectedValidators();
    if (validatorSet1.length + validatorSet2.length < _length) {
      _length = validatorSet1.length + validatorSet2.length;
    }
    Validator[] memory mergedValidatorSet = new Validator[](_length);
    bytes[] memory mergedVoteAddrSet = new bytes[](_length);

    uint256 i;
    uint256 j;
    uint256 k;
    while ((i < validatorSet1.length || j < validatorSet2.length) && k < _length) {
      if (i == validatorSet1.length) {
        mergedValidatorSet[k] = validatorSet2[j];
        mergedVoteAddrSet[k] = voteAddrSet2[j];
        ++j;
        ++k;
        continue;
      }

      if (j == validatorSet2.length) {
        mergedValidatorSet[k] = validatorSet1[i];
        mergedVoteAddrSet[k] = voteAddrSet1[i];
        ++i;
        ++k;
        continue;
      }

      if (validatorSet1[i].votingPower > validatorSet2[j].votingPower) {
        mergedValidatorSet[k] = validatorSet1[i];
        mergedVoteAddrSet[k] = voteAddrSet1[i];
        ++i;
      } else if (validatorSet1[i].votingPower < validatorSet2[j].votingPower) {
        mergedValidatorSet[k] = validatorSet2[j];
        mergedVoteAddrSet[k] = voteAddrSet2[j];
        ++j;
      } else {
        if (validatorSet1[i].consensusAddress < validatorSet2[j].consensusAddress) {
          mergedValidatorSet[k] = validatorSet1[i];
          mergedVoteAddrSet[k] = voteAddrSet1[i];
          ++i;
        } else {
          mergedValidatorSet[k] = validatorSet2[j];
          mergedVoteAddrSet[k] = voteAddrSet2[j];
          ++j;
        }
      }
      ++k;
    }

    return (mergedValidatorSet, mergedVoteAddrSet);
  }

  //rlp encode & decode function
  function decodeValidatorSetSynPackage(bytes memory msgBytes) internal pure returns(IbcValidatorSetPackage memory, bool) {
    IbcValidatorSetPackage memory validatorSetPkg;

    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    bool success = false;
    uint256 idx=0;
    while (iter.hasNext()) {
      if (idx == 0) {
        validatorSetPkg.packageType = uint8(iter.next().toUint());
      } else if (idx == 1) {
        RLPDecode.RLPItem[] memory items = iter.next().toList();
        validatorSetPkg.validatorSet = new Validator[](items.length);
        validatorSetPkg.voteAddrs = new bytes[](items.length);
        for (uint j; j<items.length; ++j) {
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

  function decodeValidator(RLPDecode.RLPItem memory itemValidator) internal pure returns (Validator memory, bytes memory, bool) {
    Validator memory validator;
    bytes memory voteAddr;
    RLPDecode.Iterator memory iter = itemValidator.iterator();
    bool success = false;
    uint256 idx=0;
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
