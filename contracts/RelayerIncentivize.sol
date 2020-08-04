pragma solidity 0.6.4;

import "./interface/IRelayerIncentivize.sol";
import "./System.sol";
import "./lib/SafeMath.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/ISystemReward.sol";

contract RelayerIncentivize is IRelayerIncentivize, System, IParamSubscriber {

  using SafeMath for uint256;

  uint256 public constant ROUND_SIZE=100;
  uint256 public constant MAXIMUM_WEIGHT=40;

  uint256 public constant HEADER_RELAYER_REWARD_RATE_MOLECULE = 1;
  uint256 public constant HEADER_RELAYER_REWARD_RATE_DENOMINATOR = 5;
  uint256 public constant CALLER_COMPENSATION_MOLECULE = 1;
  uint256 public constant CALLER_COMPENSATION_DENOMINATOR = 80;

  uint256 public headerRelayerRewardRateMolecule;
  uint256 public headerRelayerRewardRateDenominator;
  uint256 public callerCompensationMolecule;
  uint256 public callerCompensationDenominator;

  mapping(address => uint256) public headerRelayersSubmitCount;
  address payable[] public headerRelayerAddressRecord;

  mapping(address => uint256) public packageRelayersSubmitCount;
  address payable[] public packageRelayerAddressRecord;

  uint256 public collectedRewardForHeaderRelayer=0;
  uint256 public collectedRewardForTransferRelayer=0;

  uint256 public roundSequence=0;
  uint256 public countInRound=0;

  mapping(address => uint256) public relayerRewardVault;

  event distributeCollectedReward(uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer);
  event paramChange(string key, bytes value);
  event rewardToRelayer(address relayer, uint256 amount);

  function init() onlyNotInit external {
    require(!alreadyInit, "already initialized");
    headerRelayerRewardRateMolecule=HEADER_RELAYER_REWARD_RATE_MOLECULE;
    headerRelayerRewardRateDenominator=HEADER_RELAYER_REWARD_RATE_DENOMINATOR;
    callerCompensationMolecule=CALLER_COMPENSATION_MOLECULE;
    callerCompensationDenominator=CALLER_COMPENSATION_DENOMINATOR;
    alreadyInit = true;
  }

  receive() external payable{}

  
  function addReward(address payable headerRelayerAddr, address payable packageRelayer, uint256 amount, bool fromSystemReward) onlyInit onlyCrossChainContract external override returns (bool) {
  
    uint256 actualAmount;
    if (fromSystemReward) {
      actualAmount = ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(address(uint160(INCENTIVIZE_ADDR)), amount);
    } else {
      actualAmount = ISystemReward(TOKEN_HUB_ADDR).claimRewards(address(uint160(INCENTIVIZE_ADDR)), amount);
    }

    countInRound++;

    uint256 reward = calculateRewardForHeaderRelayer(actualAmount);
    collectedRewardForHeaderRelayer = collectedRewardForHeaderRelayer.add(reward);
    collectedRewardForTransferRelayer = collectedRewardForTransferRelayer.add(actualAmount).sub(reward);

    if (headerRelayersSubmitCount[headerRelayerAddr]==0) {
      headerRelayerAddressRecord.push(headerRelayerAddr);
    }
    headerRelayersSubmitCount[headerRelayerAddr]++;

    if (packageRelayersSubmitCount[packageRelayer]==0) {
      packageRelayerAddressRecord.push(packageRelayer);
    }
    packageRelayersSubmitCount[packageRelayer]++;

    if (countInRound==ROUND_SIZE) {
      emit distributeCollectedReward(roundSequence, collectedRewardForHeaderRelayer, collectedRewardForTransferRelayer);

      uint256 callerHeaderReward = distributeHeaderRelayerReward();
      uint256 callerPackageReward = distributePackageRelayerReward();

      relayerRewardVault[packageRelayer] = relayerRewardVault[packageRelayer].add(callerHeaderReward).add(callerPackageReward);

      roundSequence++;
      countInRound = 0;
    }
    return true;
  }

  function claimRelayerReward(address relayerAddr) external {
     uint256 reward = relayerRewardVault[relayerAddr];
     require(reward > 0, "no relayer reward");
     relayerRewardVault[relayerAddr] = 0;
     address payable recipient = address(uint160(relayerAddr));
     if (!recipient.send(reward)) {
        address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
        systemPayable.transfer(reward);
        emit rewardToRelayer(SYSTEM_REWARD_ADDR, reward);
        return;
     }
     emit rewardToRelayer(relayerAddr, reward);
  }

  function calculateRewardForHeaderRelayer(uint256 reward) internal view returns (uint256) {
    return reward.mul(headerRelayerRewardRateMolecule).div(headerRelayerRewardRateDenominator);
  }

  function distributeHeaderRelayerReward() internal returns (uint256) {
    uint256 totalReward = collectedRewardForHeaderRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = headerRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for (uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateHeaderRelayerWeight(headerRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight.add(weight);
    }

    uint256 callerReward = totalReward.mul(callerCompensationMolecule).div(callerCompensationDenominator);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for (uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayerRewardVault[relayers[index]] = relayerRewardVault[relayers[index]].add(reward);
      remainReward = remainReward.sub(reward);
    }
    relayerRewardVault[relayers[0]] = relayerRewardVault[relayers[0]].add(remainReward);

    collectedRewardForHeaderRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++) {
      delete headerRelayersSubmitCount[relayers[index]];
    }
    delete headerRelayerAddressRecord;
    return callerReward;
  }

  function distributePackageRelayerReward() internal returns (uint256) {
    uint256 totalReward = collectedRewardForTransferRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = packageRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for (uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateTransferRelayerWeight(packageRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight + weight;
    }

    uint256 callerReward = totalReward.mul(callerCompensationMolecule).div(callerCompensationDenominator);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for (uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayerRewardVault[relayers[index]] = relayerRewardVault[relayers[index]].add(reward);
      remainReward = remainReward.sub(reward);
    }
    relayerRewardVault[relayers[0]] = relayerRewardVault[relayers[0]].add(remainReward);

    collectedRewardForTransferRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++) {
      delete packageRelayersSubmitCount[relayers[index]];
    }
    delete packageRelayerAddressRecord;
    return callerReward;
  }

  function calculateTransferRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= MAXIMUM_WEIGHT) {
      return count;
    } else if (MAXIMUM_WEIGHT < count && count <= 2*MAXIMUM_WEIGHT) {
      return MAXIMUM_WEIGHT;
    } else if (2*MAXIMUM_WEIGHT < count && count <= (2*MAXIMUM_WEIGHT + 3*MAXIMUM_WEIGHT/4)) {
      return 3*MAXIMUM_WEIGHT - count;
    } else {
      return count/4;
    }
  }

  function calculateHeaderRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= MAXIMUM_WEIGHT) {
      return count;
    } else {
      return MAXIMUM_WEIGHT;
    }
  }

  function updateParam(string calldata key, bytes calldata value) override external onlyGov{
    require(alreadyInit, "contract has not been initialized");
    if (Memory.compareStrings(key,"headerRelayerRewardRateMolecule")) {
      require(value.length == 32, "length of headerRelayerRewardRateMolecule mismatch");
      uint256 newHeaderRelayerRewardRateMolecule = BytesToTypes.bytesToUint256(32, value);
      require(newHeaderRelayerRewardRateMolecule <= headerRelayerRewardRateDenominator, "new headerRelayerRewardRateMolecule shouldn't be greater than headerRelayerRewardRateDenominator");
      headerRelayerRewardRateMolecule = newHeaderRelayerRewardRateMolecule;
    } else if (Memory.compareStrings(key,"headerRelayerRewardRateDenominator")) {
      require(value.length == 32, "length of rewardForValidatorSetChange mismatch");
      uint256 newHeaderRelayerRewardRateDenominator = BytesToTypes.bytesToUint256(32, value);
      require(newHeaderRelayerRewardRateDenominator != 0 && newHeaderRelayerRewardRateDenominator >= headerRelayerRewardRateMolecule, "the new headerRelayerRewardRateDenominator must not be zero and no less than headerRelayerRewardRateMolecule");
      headerRelayerRewardRateDenominator = newHeaderRelayerRewardRateDenominator;
    } else if (Memory.compareStrings(key,"callerCompensationMolecule")) {
      require(value.length == 32, "length of rewardForValidatorSetChange mismatch");
      uint256 newCallerCompensationMolecule = BytesToTypes.bytesToUint256(32, value);
      require(newCallerCompensationMolecule <= callerCompensationDenominator, "new callerCompensationMolecule shouldn't be greater than callerCompensationDenominator");
      callerCompensationMolecule = newCallerCompensationMolecule;
    } else if (Memory.compareStrings(key,"callerCompensationDenominator")) {
      require(value.length == 32, "length of rewardForValidatorSetChange mismatch");
      uint256 newCallerCompensationDenominator = BytesToTypes.bytesToUint256(32, value);
      require(newCallerCompensationDenominator != 0 && newCallerCompensationDenominator >= callerCompensationMolecule, "the newCallerCompensationDenominator must not be zero and no less than callerCompensationMolecule");
      callerCompensationDenominator = newCallerCompensationDenominator;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }
}
