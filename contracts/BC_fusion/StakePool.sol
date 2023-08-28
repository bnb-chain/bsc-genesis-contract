// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./StBNB.sol";
import "./SystemConfig.sol";

interface IStakeHub {
    function isPaused() external view returns (bool);
    function getUnbondTime() external view returns (uint256);
}

contract StakePool is SystemConfig, StBNB {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    /*----------------- storage -----------------*/
    address public validator;

    uint256 private _totalReceivedReward; // just for statistics
    uint256 private _totalPooledBNB; // total reward plus total BNB staked in the pool

    // hash of the unbond request => unbond request
    mapping(bytes32 => UnbondRequest) private _unbondRequests;
    // user => unbond request queue(hash of the request)
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) private _unbondRequestsQueue;
    // user => locked shares
    mapping(address => uint256) private _lockedShares;

    struct UnbondRequest {
        uint256 amount;
        uint256 unlockTime;
    }

    /*----------------- events -----------------*/
    event Delegated(address indexed sender, uint256 amount);
    event RewardReceived(uint256 amount);
    event UnbondRequested(address indexed sender, uint256 amount, uint256 unlockTime);
    event UnbondClaimed(address indexed sender, uint256 amount);

    /*----------------- modifiers -----------------*/
    modifier onlyStakeHub() {
        address sender = _msgSender();
        require(sender == STAKE_HUB, "NOT_STAKE_HUB");
        _;
    }

    modifier onlyValidatorSet() {
        address sender = _msgSender();
        require(sender == VALIDATOR_SET, "NOT_VALIDATOR_SET");
        _;
    }

    modifier whenNotPaused() {
        require(!IStakeHub(STAKE_HUB).isPaused(), "CONTRACT_IS_STOPPED");
        _;
    }

    /*----------------- external functions -----------------*/
    function initialize(address _validator, uint256 _selfDelegateAmt) public payable initializer {
        validator = _validator;

        _bootstrapInitialHolder(_selfDelegateAmt);
    }

    function delegate(
        address _delegator,
        uint256 _bnbAmount
    ) external payable onlyStakeHub whenNotPaused returns (uint256) {
        return _stake(_delegator, _bnbAmount);
    }

    function undelegate(address _delegator, uint256 _sharesAmount) external onlyStakeHub whenNotPaused {
        require(_sharesAmount != 0, "ZERO_UNDELEGATE");
        require(_sharesAmount <= _sharesOf(_delegator), "INSUFFICIENT_BALANCE");

        // lock the tokens
        _transfer(_delegator, address(this), _sharesAmount);
        _lockedShares[_delegator] += _sharesAmount;

        // add to the queue
        UnbondRequest memory request =
            UnbondRequest({amount: _sharesAmount, unlockTime: block.timestamp + IStakeHub(STAKE_HUB).getUnbondTime()});
        bytes32 hash = keccak256(abi.encodePacked(_delegator, _sharesAmount, block.timestamp));
        _unbondRequests[hash] = request;
        _unbondRequestsQueue[_delegator].pushBack(hash);

        emit UnbondRequested(_delegator, _sharesAmount, request.unlockTime);
    }

    function claim(address _delegator) external onlyStakeHub whenNotPaused returns (uint256) {
        require(_unbondRequestsQueue[_delegator].length() != 0, "NO_UNBOND_REQUEST");

        bytes32 hash = _unbondRequestsQueue[_delegator].front();
        UnbondRequest memory request = _unbondRequests[hash];
        require(block.timestamp >= request.unlockTime, "NOT_UNLOCKED");

        // remove from the queue
        _unbondRequestsQueue[_delegator].popFront();
        delete _unbondRequests[hash];

        // unlock and burn the shares
        _lockedShares[_delegator] -= request.amount;
        _burn(address(this), request.amount);
        emit UnbondClaimed(_delegator, request.amount);

        uint256 bnbAmount = getPooledBNBByShares(request.amount);
        _totalPooledBNB -= bnbAmount;
        return bnbAmount;
    }

    function distributeReward(uint256 _amount) external onlyValidatorSet {
        _totalReceivedReward += _amount;
        _totalPooledBNB += _amount;
        emit RewardReceived(_amount);
    }

    function felony(uint256 _amount) external onlyValidatorSet {
        uint256 sharesAmount = getSharesByPooledBNB(_amount);
        _burn(validator, sharesAmount);
    }

    /*----------------- view functions -----------------*/
    function totalReceivedReward() external view returns (uint256) {
        return _getTotalReceivedReward();
    }

    function totalPooledBNB() external view returns (uint256) {
        return _getTotalPooledBNB();
    }

    function lockedShares(address _delegator) external view returns (uint256) {
        return _lockedShares[_delegator];
    }

    /*----------------- internal functions -----------------*/
    /**
     * @dev Process user deposit, mints liquid tokens and increase the pool staked BNB
     * @param _delegator address of the delegator.
     * @param _bnbAmount amount of BNB to stake.
     * @return amount of StBNB generated
     */
    function _stake(address _delegator, uint256 _bnbAmount) internal returns (uint256) {
        require(_bnbAmount != 0, "ZERO_DEPOSIT");

        uint256 sharesAmount = getSharesByPooledBNB(_bnbAmount);
        _totalPooledBNB += _bnbAmount;
        emit Delegated(_delegator, _bnbAmount);

        _mint(_delegator, sharesAmount);
        return sharesAmount;
    }

    function _bootstrapInitialHolder(uint256 _initAmount) internal {
        assert(validator != address(0));
        assert(_getTotalShares() == 0);

        // mint initial tokens to the validator
        // shares is equal to the amount of BNB staked
        _totalPooledBNB = _initAmount;
        emit Delegated(validator, _initAmount);
        _mint(validator, _initAmount);
    }

    function _getTotalPooledBNB() internal view override returns (uint256) {
        return _totalPooledBNB;
    }

    function _getTotalReceivedReward() internal view returns (uint256) {
        return _totalReceivedReward;
    }
}
