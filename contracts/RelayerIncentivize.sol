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

  uint256 public constant ROUND_SIZE=1000;
  uint256 public constant MAXIMUM_WEIGHT=400;

  uint256 public constant MOLECULE_HEADER_RELAYER = 1;
  uint256 public constant DENOMINATOR_HEADER_RELAYER = 5;
  uint256 public constant MOLECULE_CALLER_COMPENSATION = 1;
  uint256 public constant DENOMINATOR_CALLER_COMPENSATION = 80;

  uint256 public moleculeHeaderRelayer;
  uint256 public denominatorHeaderRelayer;
  uint256 public moleculeCallerCompensation;
  uint256 public denominatorCallerCompensation;

  mapping(address => uint256) public headerRelayersSubmitCount;
  address payable[] public headerRelayerAddressRecord;

  mapping(address => uint256) public transferRelayersSubmitCount;
  address payable[] public transferRelayerAddressRecord;

  uint256 public collectedRewardForHeaderRelayer=0;
  uint256 public collectedRewardForTransferRelayer=0;

  uint256 public roundSequence=0;
  uint256 public countInRound=0;

  event paramChange(string key, bytes value);

  function init() onlyNotInit public {
    require(!alreadyInit, "already initialized");
    moleculeHeaderRelayer=MOLECULE_HEADER_RELAYER;
    denominatorHeaderRelayer=DENOMINATOR_HEADER_RELAYER;
    moleculeCallerCompensation=MOLECULE_CALLER_COMPENSATION;
    denominatorCallerCompensation=DENOMINATOR_CALLER_COMPENSATION;
    alreadyInit = true;
  }

  event LogDistributeCollectedReward(uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer);

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

    if (transferRelayersSubmitCount[packageRelayer]==0) {
      transferRelayerAddressRecord.push(packageRelayer);
    }
    transferRelayersSubmitCount[packageRelayer]++;

    if (countInRound==ROUND_SIZE) {
      emit LogDistributeCollectedReward(roundSequence, collectedRewardForHeaderRelayer, collectedRewardForTransferRelayer);

      distributeHeaderRelayerReward(packageRelayer);
      distributeTransferRelayerReward(packageRelayer);

      address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
      systemPayable.transfer(address(this).balance);

      roundSequence++;
      countInRound = 0;
    }
    return true;
  }

  function calculateRewardForHeaderRelayer(uint256 reward) internal view returns (uint256) {
    return reward.mul(moleculeHeaderRelayer).div(denominatorHeaderRelayer);
  }

  function distributeHeaderRelayerReward(address payable packageRelayer) internal {
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

    uint256 callerReward = totalReward.mul(moleculeCallerCompensation).div(denominatorCallerCompensation);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for (uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayers[index].send(reward);
      remainReward = remainReward.sub(reward);
    }
    relayers[0].send(remainReward);
    packageRelayer.send(callerReward);

    collectedRewardForHeaderRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++) {
      delete headerRelayersSubmitCount[relayers[index]];
    }
    delete headerRelayerAddressRecord;
  }

  function distributeTransferRelayerReward(address payable packageRelayer) internal {
    uint256 totalReward = collectedRewardForTransferRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = transferRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for (uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateTransferRelayerWeight(transferRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight + weight;
    }

    uint256 callerReward = totalReward.mul(moleculeCallerCompensation).div(denominatorCallerCompensation);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for (uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayers[index].send(reward);
      remainReward = remainReward.sub(reward);
    }
    relayers[0].send(remainReward);
    packageRelayer.send(callerReward);

    collectedRewardForTransferRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++) {
      delete transferRelayersSubmitCount[relayers[index]];
    }
    delete transferRelayerAddressRecord;
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
    if (Memory.compareStrings(key,"moleculeHeaderRelayer")) {
      require(value.length == 32, "length of moleculeHeaderRelayer mismatch");
      uint256 newMoleculeHeaderRelayer = BytesToTypes.bytesToUint256(32, value);
      moleculeHeaderRelayer = newMoleculeHeaderRelayer;
    } else if (Memory.compareStrings(key,"denominatorHeaderRelayer")) {
      require(value.length == 32, "length of rewardForValidatorSetChange mismatch");
      uint256 newDenominatorHeaderRelayer = BytesToTypes.bytesToUint256(32, value);
      require(newDenominatorHeaderRelayer != 0, "the newDenominatorHeaderRelayer must not be zero");
      denominatorHeaderRelayer = newDenominatorHeaderRelayer;
    } else if (Memory.compareStrings(key,"moleculeCallerCompensation")) {
      require(value.length == 32, "length of rewardForValidatorSetChange mismatch");
      uint256 newMoleculeCallerCompensation = BytesToTypes.bytesToUint256(32, value);
      moleculeCallerCompensation = newMoleculeCallerCompensation;
    } else if (Memory.compareStrings(key,"denominatorCallerCompensation")) {
      require(value.length == 32, "length of rewardForValidatorSetChange mismatch");
      uint256 newDenominatorCallerCompensation = BytesToTypes.bytesToUint256(32, value);
      require(newDenominatorCallerCompensation != 0, "the newDenominatorCallerCompensation must not be zero");
      denominatorCallerCompensation = newDenominatorCallerCompensation;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }
}
