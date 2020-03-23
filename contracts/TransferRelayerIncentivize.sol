pragma solidity 0.5.16;

import "./interface/IRelayerIncentivize.sol";

contract TransferRelayerIncentivize is IRelayerIncentivize {

    uint256 constant roundSize= 20;    // TODO change to 1024 in testnet and mainnet
    uint256 constant maximumWeight=10;  // TODO change to 400 in testnet and mainnet

    mapping( uint256 => mapping(address => uint256) ) public _relayersSubmitCount;
    mapping( uint256 => address payable[] ) public _relayerAddressRecord;

    mapping( uint256 => uint256) public _collectedRewardRound;
    mapping( uint256 => bool) public _matureRound;

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
            _matureRound[_roundSequence]=true;
            emit LogRewardPeriodExpire(_roundSequence, _collectedRewardRound[_roundSequence]);
            //TODO maybe we can directly call distributeReward
            _roundSequence++;
            _countInRound=0;
        }
        return true;
    }

    function withdrawReward(uint256 sequence) external returns (bool) {
        require(_matureRound[sequence], "the target round is premature");
        uint256 totalReward = _collectedRewardRound[sequence];

        address payable[] memory relayers = _relayerAddressRecord[sequence];
        uint256[] memory relayerWeight = new uint256[](relayers.length);
        for(uint256 index=0; index < relayers.length; index++) {
            address relayer = relayers[index];
            uint256 weight = calculateWeight(_relayersSubmitCount[sequence][relayer]);
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

        delete _collectedRewardRound[sequence];
        delete _matureRound[sequence];
        for (uint256 index=0; index < relayers.length; index++){
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
        } else if (2*maximumWeight < count && count <= (2*maximumWeight + 3*maximumWeight/4 )) {
            return 3*maximumWeight - count;
        } else {
            return count/4;
        }
    }
}