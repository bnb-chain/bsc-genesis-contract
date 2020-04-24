pragma solidity 0.6.4;

import "./interface/IRelayerIncentivize.sol";
import "./System.sol";

contract RelayerIncentivize is IRelayerIncentivize, System {

  uint256 public constant roundSize=1000;
  uint256 public constant maximumWeight=400;

  mapping( uint256 => mapping(address => uint256) ) public _headerRelayersSubmitCount;
  mapping( uint256 => address payable[] ) public _headerRelayerAddressRecord;

  mapping( uint256 => mapping(address => uint256) ) public _transferRelayersSubmitCount;
  mapping( uint256 => address payable[] ) public _transferRelayerAddressRecord;

  mapping( uint256 => uint256) public _collectedRewardForHeaderRelayerPerRound;
  mapping( uint256 => uint256) public _collectedRewardForTransferRelayerPerRound;

  uint256 public _roundSequence = 0;
  uint256 public _countInRound=0;

  event LogDistributeCollectedReward(uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer);
  event LogRefundTransferRewardToSystemReward(uint256 amount);
  event LogRefundHeaderRewardToSystemReward(uint256 amount);

  
  function addReward(address payable headerRelayerAddr, address payable caller) external onlyTokenHub override payable returns (bool) {
  
    _countInRound++;

    uint256 reward = calculateRewardForHeaderRelayer(msg.value);
    _collectedRewardForHeaderRelayerPerRound[_roundSequence] += reward;
    _collectedRewardForTransferRelayerPerRound[_roundSequence] += msg.value - reward;

    if (_headerRelayersSubmitCount[_roundSequence][headerRelayerAddr]==0){
      _headerRelayerAddressRecord[_roundSequence].push(headerRelayerAddr);
    }
    _headerRelayersSubmitCount[_roundSequence][headerRelayerAddr]++;

    if (_transferRelayersSubmitCount[_roundSequence][caller]==0){
      _transferRelayerAddressRecord[_roundSequence].push(caller);
    }
    _transferRelayersSubmitCount[_roundSequence][caller]++;

    if (_countInRound==roundSize){
      emit LogDistributeCollectedReward(_roundSequence, _collectedRewardForHeaderRelayerPerRound[_roundSequence], _collectedRewardForTransferRelayerPerRound[_roundSequence]);

      distributeHeaderRelayerReward(_roundSequence, caller);
      distributeTransferRelayerReward(_roundSequence, caller);

      _roundSequence++;
      _countInRound = 0;
    }
    return true;
  }

  //TODO need further discussion
  function calculateRewardForHeaderRelayer(uint256 reward) internal pure returns (uint256) {
    return reward/5; //20%
  }

  function distributeHeaderRelayerReward(uint256 sequence, address payable caller) internal returns (bool) {
    uint256 totalReward = _collectedRewardForHeaderRelayerPerRound[sequence];

    uint256 totalWeight=0;
    address payable[] memory relayers = _headerRelayerAddressRecord[sequence];
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateHeaderRelayerWeight(_headerRelayersSubmitCount[sequence][relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight + weight;
    }

    uint256 callerReward = totalReward * 5/100; //TODO need further discussion
    totalReward = totalReward - callerReward;
    uint256 remainReward = totalReward;
    uint256 failedTransferAmount = 0;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index]*totalReward/totalWeight;
      if (!relayers[index].send(reward)) {
        failedTransferAmount += reward;
      }
      remainReward = remainReward-reward;
    }
    if (!relayers[0].send(remainReward)) {
      failedTransferAmount += remainReward;
    }
    if (!caller.send(callerReward)) {
      failedTransferAmount += callerReward;
    }
    if (failedTransferAmount>0) {
      address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
      systemPayable.transfer(failedTransferAmount);
      emit LogRefundHeaderRewardToSystemReward(failedTransferAmount);
    }

    delete _collectedRewardForHeaderRelayerPerRound[sequence];
    for (uint256 index = 0; index < relayers.length; index++){
      delete _headerRelayersSubmitCount[sequence][relayers[index]];
    }
    delete _headerRelayerAddressRecord[sequence];
    return true;
  }

  function distributeTransferRelayerReward(uint256 sequence, address payable caller) internal returns (bool) {
    uint256 totalReward = _collectedRewardForTransferRelayerPerRound[sequence];

    uint256 totalWeight=0;
    address payable[] memory relayers = _transferRelayerAddressRecord[sequence];
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateTransferRelayerWeight(_transferRelayersSubmitCount[sequence][relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight + weight;
    }

    uint256 callerReward = totalReward * 5/100; //TODO need further discussion
    totalReward = totalReward - callerReward;
    uint256 remainReward = totalReward;
    uint256 failedTransferAmount = 0;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index]*totalReward/totalWeight;
      if (!relayers[index].send(reward)) {
        failedTransferAmount += reward;
      }
      remainReward = remainReward-reward;
    }
    if (!relayers[0].send(remainReward)) {
      failedTransferAmount += remainReward;
    }
    if (!caller.send(callerReward)) {
      failedTransferAmount += callerReward;
    }
    if (failedTransferAmount>0) {
      address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
      systemPayable.transfer(failedTransferAmount);
      emit LogRefundTransferRewardToSystemReward(failedTransferAmount);
    }

    delete _collectedRewardForTransferRelayerPerRound[sequence];
    for (uint256 index = 0; index < relayers.length; index++){
      delete _transferRelayersSubmitCount[sequence][relayers[index]];
    }
    delete _transferRelayerAddressRecord[sequence];
    return true;
  }

  function calculateTransferRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= maximumWeight) {
      return count;
    } else if (maximumWeight < count && count <= 2*maximumWeight) {
      return maximumWeight;
    } else if (2*maximumWeight < count && count <= (2*maximumWeight + 3*maximumWeight/4 )) {
      return 3*maximumWeight - count;
    } else {
      return count/4;
    }
  }

  function calculateHeaderRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= maximumWeight) {
      return count;
    } else if (maximumWeight < count && count <= 2*maximumWeight) {
      return maximumWeight;
    } else {
      return maximumWeight;
    }
  }
}
