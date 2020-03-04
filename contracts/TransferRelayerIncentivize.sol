pragma solidity 0.5.16;

import "IRelayerIncentivize.sol";

contract TransferRelayerIncentivizeContract is IRelayerIncentivize {
    mapping( uint256 => mapping(address => uint256) ) public relayerSubmitCount;
    mapping( uint256 => address payable[] ) public relayerAddressRecord;

    mapping( uint256 => uint256) public collectedRewardRound;
    mapping( uint256 => bool) public roundExpired;

    uint256 public rewardDistributionSequence = 0;
    uint256 public rewardRoundCount=0;
    uint256 roundSize=32; // 1024
    uint256 maximumWeight=8; // 400

    event LogAddReward(address relayerAddr, uint256 amount);
    event LogRewardPeriodExpire(uint256 sequence, uint256 totalPeriodReward);

    function addReward(address payable relayerAddr) external payable returns (bool) {

        rewardRoundCount++;
        collectedRewardRound[rewardDistributionSequence]+=msg.value;

        if (relayerSubmitCount[rewardDistributionSequence][relayerAddr]==0){
            relayerAddressRecord[rewardDistributionSequence].push(relayerAddr);
        }
        relayerSubmitCount[rewardDistributionSequence][relayerAddr]++;
        emit LogAddReward(relayerAddr, msg.value);

        if (rewardRoundCount==roundSize){
            roundExpired[rewardDistributionSequence]=true;
            emit LogRewardPeriodExpire(rewardDistributionSequence, collectedRewardRound[rewardDistributionSequence]);

            rewardDistributionSequence++;
            rewardRoundCount=0;
        }
        return true;
    }

    function distributeReward(uint256 rewardSequence) external returns (bool) {
        require(roundExpired[rewardSequence]);
        uint256 totalReward = collectedRewardRound[rewardSequence];

        uint256 sum=0;
        uint256[] memory relayerWeight;
        address payable[] memory relayers = relayerAddressRecord[rewardSequence];
        for(uint256 index=0; index < relayers.length; index++) {
            address relayer = relayers[index];
            uint256 weight = calculateWeight(relayerSubmitCount[rewardSequence][relayer]);
            relayerWeight[index]=weight;
            sum+=weight;
        }

        uint256 callerReward = totalReward * 5/100;
        totalReward = totalReward - callerReward;
        uint256 remainReward;
        for(uint256 index=1; index < relayers.length; index++) {
            uint256 reward = relayerWeight[index]*totalReward/sum;
            relayers[0].transfer(reward);
            remainReward=totalReward-reward;
        }
        relayers[0].transfer(remainReward);
        msg.sender.transfer(callerReward);

        delete collectedRewardRound[rewardSequence];
        delete roundExpired[rewardSequence];
        for (uint256 index=0; index < relayers.length; index++){
            delete relayerSubmitCount[rewardSequence][relayers[index]];
        }
        delete relayerAddressRecord[rewardSequence];
        return true;
    }

    function calculateWeight(uint256 count) public view returns(uint256) {
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
}