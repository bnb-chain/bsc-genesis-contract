// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface StakeCredit {
    struct UnbondRequest {
        uint256 shares;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    error ApproveNotAllowed();
    error Empty();
    error InsufficientBalance();
    error InvalidValue(string key, bytes value);
    error NoClaimableUnbondRequest();
    error NoUnbondRequest();
    error OnlyCoinbase();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error OutOfBounds();
    error RequestExisted();
    error TransferFailed();
    error TransferNotAllowed();
    error UnknownParam(string key, bytes value);
    error WrongInitContext();
    error ZeroAmount();
    error ZeroShares();
    error ZeroTotalPooledBNB();
    error ZeroTotalShares();

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Initialized(uint8 version);
    event ParamChange(string key, bytes value);
    event RewardReceived(uint256 rewardToAll, uint256 commission);
    event Transfer(address indexed from, address indexed to, uint256 value);

    receive() external payable;

    function BC_FUSION_CHANNELID() external view returns (uint8);
    function STAKING_CHANNELID() external view returns (uint8);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function claim(address payable delegator, uint256 number) external returns (uint256);
    function claimableUnbondRequest(address delegator) external view returns (uint256);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function delegate(address delegator) external payable returns (uint256 shares);
    function distributeReward(uint64 commissionRate) external payable;
    function getPooledBNB(address account) external view returns (uint256);
    function getPooledBNBByShares(uint256 shares) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(address _validator, string memory _moniker) external payable;
    function lockedBNBs(address delegator, uint256 number) external view returns (uint256);
    function name() external view returns (string memory);
    function pendingUnbondRequest(address delegator) external view returns (uint256);
    function rewardRecord(uint256) external view returns (uint256);
    function slash(uint256 slashBnbAmount) external returns (uint256);
    function symbol() external view returns (string memory);
    function totalPooledBNB() external view returns (uint256);
    function totalPooledBNBRecord(uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function unbond(address delegator, uint256 shares) external returns (uint256 bnbAmount);
    function unbondRequest(address delegator, uint256 _index) external view returns (UnbondRequest memory);
    function unbondSequence(address delegator) external view returns (uint256);
    function undelegate(address delegator, uint256 shares) external returns (uint256 bnbAmount);
    function validator() external view returns (address);
}
