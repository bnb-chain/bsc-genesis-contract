pragma solidity 0.6.4;

interface IStakeHub {
    function downtimeSlash(address validator) external;
    function maliciousVoteSlash(bytes calldata voteAddress) external;
    function doubleSignSlash(address validator) external;
    function voteToOperator(bytes calldata voteAddress) external view returns (address);
    function consensusToOperator(address validator) external view returns (address);
    function maxElectedValidators() external view returns (uint256);
    function distributeReward(address validator) external payable;
}
