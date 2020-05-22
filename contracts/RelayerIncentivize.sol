pragma solidity 0.6.4;

import "./interface/IRelayerIncentivize.sol";
import "./System.sol";
import "./lib/SafeMath.sol";

contract RelayerIncentivize is IRelayerIncentivize, System {

  using SafeMath for uint256;

  uint256 public constant ROUND_SIZE=1000;
  uint256 public constant MAXIMUM_WEIGHT=400;

  //TODO add governance later
  uint256 public constant moleculeHeaderRelayer = 1;
  uint256 public constant denominaroeHeaderRelayer = 5;
  uint256 public constant moleculeCallerCompensation = 1;
  uint256 public constant denominaroeCallerCompensation = 80;

  mapping(address => uint256) public _headerRelayersSubmitCount;
  address payable[] public _headerRelayerAddressRecord;

  mapping(address => uint256) public _transferRelayersSubmitCount;
  address payable[] public _transferRelayerAddressRecord;

  uint256 public _collectedRewardForHeaderRelayer=0;
  uint256 public _collectedRewardForTransferRelayer=0;

  uint256 public _roundSequence=0;
  uint256 public _countInRound=0;

  event LogDistributeCollectedReward(uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer);

  
  function addReward(address payable headerRelayerAddr, address payable caller) external onlyTokenHub override payable returns (bool) {
  
    _countInRound++;

    uint256 reward = calculateRewardForHeaderRelayer(msg.value);
    _collectedRewardForHeaderRelayer = _collectedRewardForHeaderRelayer.add(reward);
    _collectedRewardForTransferRelayer = _collectedRewardForTransferRelayer.add(msg.value).sub(reward);

    if (_headerRelayersSubmitCount[headerRelayerAddr]==0){
      _headerRelayerAddressRecord.push(headerRelayerAddr);
    }
    _headerRelayersSubmitCount[headerRelayerAddr]++;

    if (_transferRelayersSubmitCount[caller]==0){
      _transferRelayerAddressRecord.push(caller);
    }
    _transferRelayersSubmitCount[caller]++;

    if (_countInRound==ROUND_SIZE){
      emit LogDistributeCollectedReward(_roundSequence, _collectedRewardForHeaderRelayer, _collectedRewardForTransferRelayer);

      distributeHeaderRelayerReward(caller);
      distributeTransferRelayerReward(caller);

      address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
      systemPayable.transfer(address(this).balance);

      _roundSequence++;
      _countInRound = 0;
    }
    return true;
  }

  function calculateRewardForHeaderRelayer(uint256 reward) internal view returns (uint256) {
    return reward.mul(moleculeHeaderRelayer).div(denominaroeHeaderRelayer);
  }

  function distributeHeaderRelayerReward(address payable caller) internal returns (bool) {
    uint256 totalReward = _collectedRewardForHeaderRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = _headerRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateHeaderRelayerWeight(_headerRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight.add(weight);
    }

    uint256 callerReward = totalReward.mul(moleculeCallerCompensation).div(denominaroeCallerCompensation);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayers[index].send(reward);
      remainReward = remainReward.sub(reward);
    }
    relayers[0].send(remainReward);
    caller.send(callerReward);

    _collectedRewardForHeaderRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++){
      delete _headerRelayersSubmitCount[relayers[index]];
    }
    delete _headerRelayerAddressRecord;
  }

  function distributeTransferRelayerReward(address payable caller) internal returns (bool) {
    uint256 totalReward = _collectedRewardForTransferRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = _transferRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateTransferRelayerWeight(_transferRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight + weight;
    }

    uint256 callerReward = totalReward.mul(moleculeCallerCompensation).div(denominaroeCallerCompensation);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayers[index].send(reward);
      remainReward = remainReward.sub(reward);
    }
    relayers[0].send(remainReward);
    caller.send(callerReward);

    _collectedRewardForTransferRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++){
      delete _transferRelayersSubmitCount[relayers[index]];
    }
    delete _transferRelayerAddressRecord;
  }

  function calculateTransferRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= MAXIMUM_WEIGHT) {
      return count;
    } else if (MAXIMUM_WEIGHT < count && count <= 2*MAXIMUM_WEIGHT) {
      return MAXIMUM_WEIGHT;
    } else if (2*MAXIMUM_WEIGHT < count && count <= (2*MAXIMUM_WEIGHT + 3*MAXIMUM_WEIGHT/4 )) {
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
}
