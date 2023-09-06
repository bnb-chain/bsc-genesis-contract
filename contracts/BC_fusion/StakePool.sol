// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./StBNB.sol";
import "./System.sol";

interface IStakeHub {
    function isPaused() external view returns (bool);
    function getUnbondTime() external view returns (uint256);
}

contract StakePool is System, StBNB {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint256 public constant MAX_CLAIM_NUMBER = 20;

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
    // user => personal unbond sequence
    mapping(address => uint256) private _unbondSequence;

    struct UnbondRequest {
        uint256 sharesAmount;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    /*----------------- events -----------------*/
    event Delegated(address indexed sender, uint256 sharesAmount, uint256 bnbAmount);
    event RewardReceived(uint256 bnbAmount);
    event UnbondRequested(address indexed sender, uint256 sharesAmount, uint256 bnbAmount, uint256 unlockTime);
    event UnbondClaimed(address indexed sender, uint256 sharesAmount, uint256 bnbAmount);

    /*----------------- modifiers -----------------*/
    modifier whenNotPaused() {
        require(!IStakeHub(STAKE_HUB_ADDR).isPaused(), "CONTRACT_IS_STOPPED");
        _;
    }

    /*----------------- external functions -----------------*/
    function initialize(address _validator) public payable initializer {
        validator = _validator;

        assert(msg.value != 0);
        _bootstrapInitialHolder(msg.value);
    }

    function delegate(address _delegator) external payable onlyStakeHub whenNotPaused returns (uint256) {
        return _stake(_delegator, msg.value);
    }

    function undelegate(address _delegator, uint256 _sharesAmount) external onlyStakeHub whenNotPaused returns (uint256) {
        require(_sharesAmount <= _sharesOf(_delegator), "INSUFFICIENT_BALANCE");

        _lockedShares[_delegator] += _sharesAmount;

        // calculate the BNB amount and update state
        uint256 _bnbAmount = getPooledBNBByShares(_sharesAmount);
        _burn(_delegator, _sharesAmount);
        _totalPooledBNB -= _bnbAmount;

        // add to the queue
        _unbondSequence[_delegator] += 1; // increase the sequence first to avoid zero sequence
        bytes32 hash = keccak256(abi.encodePacked(_delegator, _unbondSequence[_delegator]));

        uint256 unlockTime = block.timestamp + IStakeHub(STAKE_HUB_ADDR).getUnbondTime();
        UnbondRequest memory request = UnbondRequest({sharesAmount: _sharesAmount, bnbAmount: _bnbAmount, unlockTime: unlockTime});
        _unbondRequests[hash] = request;
        _unbondRequestsQueue[_delegator].pushBack(hash);

        emit UnbondRequested(_delegator, _sharesAmount, _bnbAmount, request.unlockTime);
        return _bnbAmount;
    }

    function redelegate(address _delegator, uint256 _sharesAmount) external onlyStakeHub whenNotPaused returns (uint256) {
        require(_sharesAmount <= _sharesOf(_delegator), "INSUFFICIENT_BALANCE");

        // calculate the BNB amount and update state
        uint256 _bnbAmount = getPooledBNBByShares(_sharesAmount);
        _burn(_delegator, _sharesAmount);
        _totalPooledBNB -= _bnbAmount;

        (bool success,) = STAKE_HUB_ADDR.call{value: _bnbAmount}("");
        require(success, "TRANSFER_FAILED");
        return _bnbAmount;
    }

    function claim(address payable _delegator, uint256 number) external onlyStakeHub whenNotPaused returns (uint256) {
        require(_unbondRequestsQueue[_delegator].length() != 0, "NO_UNBOND_REQUEST");
        // number == 0 means claim all
        if (number == 0) {
            number = _unbondRequestsQueue[_delegator].length();
        }
        if (number > _unbondRequestsQueue[_delegator].length()) {
            number = _unbondRequestsQueue[_delegator].length();
        }
        require(number <= MAX_CLAIM_NUMBER, "TOO_MANY_REQUESTS"); // prevent too many loop in one transaction

        uint256 _totalShares;
        uint256 _totalBnbAmount;
        while (number != 0) {
            bytes32 hash = _unbondRequestsQueue[_delegator].front();
            UnbondRequest memory request = _unbondRequests[hash];
            if (block.timestamp < request.unlockTime) {
                break;
            }

            // request is non-existed(should not happen)
            if (request.sharesAmount == 0 && request.unlockTime == 0) {
                continue;
            }

            _totalShares += request.sharesAmount;
            _totalBnbAmount += request.bnbAmount;

            // remove from the queue
            _unbondRequestsQueue[_delegator].popFront();
            delete _unbondRequests[hash];

            number -= 1;
        }

        _lockedShares[_delegator] -= _totalShares;
        (bool success,) = _delegator.call{value: _totalBnbAmount}("");
        require(success, "CLAIM_FAILED");

        emit UnbondClaimed(_delegator, _totalShares, _totalBnbAmount);
        return _totalBnbAmount;
    }

    function distributeReward() external payable onlyStakeHub {
        uint256 _bnbAmount = msg.value;
        _totalReceivedReward += _bnbAmount;
        _totalPooledBNB += _bnbAmount;
        emit RewardReceived(_bnbAmount);
    }

    function slash(uint256 _slashBnbAmount) external onlyStakeHub returns (uint256) {
        uint256 selfDelegation = _sharesOf(validator);
        uint256 _slashShares = getSharesByPooledBNB(_slashBnbAmount);

        uint256 _remainingSlashBnbAmount = _slashBnbAmount;
        uint256 _remainingSlashShares = _slashShares;
        if (_slashShares <= selfDelegation) {
            _totalPooledBNB -= _slashBnbAmount;
            _burn(validator, _slashShares);
            _remainingSlashBnbAmount = 0;
        } else {
            uint256 selfDelegationTokens = getPooledBNBByShares(selfDelegation);
            _totalPooledBNB -= selfDelegationTokens;
            _burn(validator, selfDelegation);

            _remainingSlashBnbAmount -= selfDelegationTokens;
            _remainingSlashShares -= selfDelegation;

            uint256 _unbondingShares = _lockedShares[validator];
            while (_remainingSlashBnbAmount > 0 && _unbondingShares > 0) {
                bytes32 hash = _unbondRequestsQueue[validator].front();
                UnbondRequest memory request = _unbondRequests[hash];

                if (request.bnbAmount > _remainingSlashBnbAmount) {
                    // slash the request
                    _unbondRequests[hash].sharesAmount -= _remainingSlashShares;
                    _unbondRequests[hash].bnbAmount -= _remainingSlashBnbAmount;
                    _unbondingShares -= _remainingSlashShares;
                    _remainingSlashBnbAmount = 0;
                    break;
                } else {
                    // slash the request and remove from the queue
                    _unbondingShares -= request.sharesAmount;
                    _remainingSlashBnbAmount -= request.bnbAmount;
                    _remainingSlashShares -= request.sharesAmount;
                    _unbondRequestsQueue[validator].popFront();
                    delete _unbondRequests[hash];
                }
            }

            _lockedShares[validator] = _unbondingShares;
        }

        uint256 _realSlashBnbAmount = _slashBnbAmount - _remainingSlashBnbAmount;
        (bool success,) = SYSTEM_REWARD_ADDR.call{value: _realSlashBnbAmount}("");
        require(success, "TRANSFER_FAILED");
        return _realSlashBnbAmount;
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

        uint256 _sharesAmount = getSharesByPooledBNB(_bnbAmount);
        _totalPooledBNB += _bnbAmount;
        emit Delegated(_delegator, _sharesAmount, _bnbAmount);

        _mint(_delegator, _sharesAmount);
        return _sharesAmount;
    }

    function _bootstrapInitialHolder(uint256 _initAmount) internal {
        assert(validator != address(0));
        assert(_getTotalShares() == 0);

        // mint initial tokens to the validator
        // shares is equal to the amount of BNB staked
        _totalPooledBNB = _initAmount;
        emit Delegated(validator, _initAmount, _initAmount);
        _mint(validator, _initAmount);
    }

    function _getTotalPooledBNB() internal view override returns (uint256) {
        return _totalPooledBNB;
    }

    function _getTotalReceivedReward() internal view returns (uint256) {
        return _totalReceivedReward;
    }
}
