pragma solidity 0.6.4;

import "./interface/IRelayerIncentivize.sol";

contract HeaderRelayerIncentivize is IRelayerIncentivize {

  uint256 constant roundSize=20;
  uint256 constant maximumWeight=10;

  mapping( uint256 => mapping(address => uint256) ) public _relayersSubmitCount;
  mapping( uint256 => address payable[] ) public _relayerAddressRecord;

  mapping( uint256 => uint256) public _collectedRewardRound;

  uint256 public _roundSequence = 0;
  uint256 public _countInRound=0;

  event LogAddReward(address relayerAddr, uint256 amount);
  event LogRewardPeriodExpire(uint256 sequence, uint256 totalPeriodReward);

  function addReward(address payable relayerAddr) external override payable returns (bool) {
    _countInRound++;
    _collectedRewardRound[_roundSequence] += msg.value;

    if (_relayersSubmitCount[_roundSequence][relayerAddr]==0){
      _relayerAddressRecord[_roundSequence].push(relayerAddr);
    }
    _relayersSubmitCount[_roundSequence][relayerAddr]++;
    emit LogAddReward(relayerAddr, msg.value);

    if (_countInRound==roundSize){
      emit LogRewardPeriodExpire(_roundSequence, _collectedRewardRound[_roundSequence]);
      claimReward(_roundSequence);
      _roundSequence++;
      _countInRound = 0;
    }
    return true;
  }

  function claimReward(uint256 sequence) internal returns (bool) {
    uint256 totalReward = _collectedRewardRound[sequence];

    address payable[] memory relayers = _relayerAddressRecord[sequence];
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateWeight(_relayersSubmitCount[sequence][relayer]);
      relayerWeight[index] = weight;
    }

    uint256 callerReward = totalReward * 5/100; //TODO need further discussion
    totalReward = totalReward - callerReward;
    uint256 remainReward = totalReward;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index]*totalReward/roundSize;
      relayers[index].transfer(reward);
      remainReward = remainReward-reward;
    }
    relayers[0].transfer(remainReward);
    msg.sender.transfer(callerReward);

    delete _collectedRewardRound[sequence];
    for (uint256 index = 0; index < relayers.length; index++){
      delete _relayersSubmitCount[sequence][relayers[index]];
    }
    delete _relayerAddressRecord[sequence];
    return true;
  }

  function calculateWeight(uint256 count) public pure returns(uint256) {
    if (count <= maximumWeight) {
      return count;
    } else if (maximumWeight < count && count <= 2*maximumWeight) {
      return maximumWeight;
    } else {
      return maximumWeight;
    }
  }
}