pragma solidity 0.5.16;

import "./interface/IRelayerIncentivize.sol";

contract HeaderRelayerIncentivize is IRelayerIncentivize {

    uint256 constant roundSize= 1024;
    uint256 constant maximumWeight=400;

    mapping( uint256 => mapping(address => uint256) ) public _relayersSubmitCount;
    mapping( uint256 => address payable[] ) public _relayerAddressRecord;

    mapping( uint256 => uint256) public _collectedRewardRound;
    mapping( uint256 => bool) public _expiredRound;

    uint256 public _roundSequence = 0;
    uint256 public _countInRound=0;

    event LogAddReward(address relayerAddr, uint256 amount);
    event LogRewardPeriodExpire(uint256 sequence, uint256 totalPeriodReward);

    function addReward(address payable relayerAddr) external payable returns (bool) {

        _countInRound++;
        _collectedRewardRound[_roundSequence]+=msg.value;

        if (_relayersSubmitCount[_roundSequence][relayerAddr]==0){
            _relayerAddressRecord[_roundSequence].push(relayerAddr);
        }
        _relayersSubmitCount[_roundSequence][relayerAddr]++;
        emit LogAddReward(relayerAddr, msg.value);

        if (_countInRound==roundSize){
            _expiredRound[_roundSequence]=true;
            emit LogRewardPeriodExpire(_roundSequence, _collectedRewardRound[_roundSequence]);
            //TODO maybe we can directly call distributeReward
            _roundSequence++;
            _countInRound=0;
        }
        return true;
    }

    function distributeReward(uint256 rewardSequence) external returns (bool) {
        require(_expiredRound[rewardSequence]);
        uint256 totalReward = _collectedRewardRound[rewardSequence];

        address payable[] memory relayers = _relayerAddressRecord[rewardSequence];
        uint256[] memory relayerWeight = new uint256[](relayers.length);
        for(uint256 index=0; index < relayers.length; index++) {
            address relayer = relayers[index];
            uint256 weight = calculateWeight(_relayersSubmitCount[rewardSequence][relayer]);
            relayerWeight[index]=weight;
        }

        uint256 callerReward = totalReward * 5/100; //TODO need further discussion
        totalReward = totalReward - callerReward;
        uint256 remainReward=totalReward;
        for(uint256 index=1; index < relayers.length; index++) {
            uint256 reward = relayerWeight[index]*totalReward/roundSize;
            relayers[index].transfer(reward);
            remainReward=remainReward-reward;
        }
        relayers[0].transfer(remainReward);
        msg.sender.transfer(callerReward);

        delete _collectedRewardRound[rewardSequence];
        delete _expiredRound[rewardSequence];
        for (uint256 index=0; index < relayers.length; index++){
            delete _relayersSubmitCount[rewardSequence][relayers[index]];
        }
        delete _relayerAddressRecord[rewardSequence];
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