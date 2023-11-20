// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface StakeCredit {
    struct UnbondRequest {
        uint256 shares;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    error Empty();
    error OutOfBounds();

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Initialized(uint8 version);
    event ParamChange(string key, bytes value);
    event RewardReceived(uint256 rewardToAll, uint256 commission);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function claim(address payable delegator, uint256 number) external returns (uint256);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function delegate(address delegator) external payable returns (uint256 shares);
    function distributeReward(uint64 commissionRate) external payable;
    function getPooledBNB(address account) external view returns (uint256);
    function getPooledBNBByShares(uint256 shares) external view returns (uint256);
    function getSelfDelegationBNB() external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(address _validator, string memory _moniker) external payable;
    function lockedBNBs(address delegator) external view returns (uint256);
    function name() external view returns (string memory);
    function slash(uint256 slashBnbAmount) external returns (uint256);
    function symbol() external view returns (string memory);
    function totalPooledBNB() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function unbond(address delegator, uint256 shares) external returns (uint256 bnbAmount);
    function unbondRequest(address delegator, uint256 _index) external view returns (UnbondRequest memory, uint256);
    function unbondSequence(address delegator) external view returns (uint256);
    function undelegate(address delegator, uint256 shares) external returns (uint256 bnbAmount);
    function validator() external view returns (address);
}
