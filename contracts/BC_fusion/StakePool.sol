// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./System.sol";

interface IStakeHub {
    function unbondPeriod() external view returns (uint256);
    function transferGasLimit() external view returns (uint256);
    function poolImplementation() external view returns (address);
}

contract StakePool is Initializable, ReentrancyGuard, System, ERC20Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    /*----------------- constant -----------------*/
    string public constant ERC20_NAME = "BSC staked BNB";
    string public constant ERC20_SYMBOL = "stBNB";

    uint256 public constant COMMISSION_RATE_BASE = 10_000; // 100%

    /*----------------- storage -----------------*/
    address public validator; // validator operator address
    uint256 private _totalPooledBNB; // total reward plus total BNB staked in the pool

    // hash of the unbond request => unbond request
    mapping(bytes32 => UnbondRequest) private _unbondRequests;
    // user => unbond request queue(hash of the request)
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) private _unbondRequestsQueue;
    // user => locked shares
    mapping(address => uint256) private _lockedShares;
    // user => personal unbond sequence
    mapping(address => CountersUpgradeable.Counter) private _unbondSequence;

    // for slash
    bool private _freeze;
    uint256 private _remainingSlashBnbAmount;

    struct UnbondRequest {
        uint256 sharesAmount;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    /*----------------- events -----------------*/
    event Delegated(address indexed sender, uint256 sharesAmount, uint256 bnbAmount);
    event Unbonded(address indexed sender, uint256 sharesAmount, uint256 bnbAmount);
    event UnbondRequested(address indexed sender, uint256 sharesAmount, uint256 bnbAmount, uint256 unlockTime);
    event UnbondClaimed(address indexed sender, uint256 sharesAmount, uint256 bnbAmount);
    event RewardReceived(uint256 reward, uint256 commission);
    event PayFine(uint256 bnbAmount);

    /*----------------- modifiers -----------------*/
    modifier checkImplementation() {
        require(address(this) == IStakeHub(STAKE_HUB_ADDR).poolImplementation(), "NOT_LATEST_IMPLEMENTATION");
        _;
    }

    /*----------------- external functions -----------------*/
    function initialize(address _validator, uint256 minSelfDelegationBNB) public payable initializer {
        __ERC20_init_unchained(ERC20_NAME, ERC20_SYMBOL);

        validator = _validator;

        assert(msg.value != 0);
        _bootstrapInitialHolder(msg.value);
    }

    function delegate(address _delegator) external payable onlyStakeHub checkImplementation returns (uint256) {
        require(msg.value != 0, "ZERO_DEPOSIT");
        return _stake(_delegator, msg.value);
    }

    function undelegate(address _delegator, uint256 _sharesAmount) external onlyStakeHub returns (uint256) {
        require(_sharesAmount != 0, "ZERO_AMOUNT");
        require(_sharesAmount <= balanceOf(_delegator), "INSUFFICIENT_BALANCE");

        _lockedShares[_delegator] += _sharesAmount;

        // calculate the BNB amount and update state
        uint256 _bnbAmount = getPooledBNBByShares(_sharesAmount);
        _burn(_delegator, _sharesAmount);
        _totalPooledBNB -= _bnbAmount;

        // add to the queue
        bytes32 hash = keccak256(abi.encodePacked(_delegator, _useSequence(_delegator)));

        uint256 unlockTime = block.timestamp + IStakeHub(STAKE_HUB_ADDR).unbondPeriod();
        UnbondRequest memory request = UnbondRequest({sharesAmount: _sharesAmount, bnbAmount: _bnbAmount, unlockTime: unlockTime});
        _unbondRequests[hash] = request;
        _unbondRequestsQueue[_delegator].pushBack(hash);

        emit UnbondRequested(_delegator, _sharesAmount, _bnbAmount, request.unlockTime);
        return _bnbAmount;
    }

    /**
     * @dev Unbond immediately without adding to the queue.
     * Only for redelegate process.
     */
    function unbond(address _delegator, uint256 _sharesAmount) external onlyStakeHub returns (uint256) {
        require(_sharesAmount <= balanceOf(_delegator), "INSUFFICIENT_BALANCE");

        // calculate the BNB amount and update state
        uint256 _bnbAmount = getPooledBNBByShares(_sharesAmount);
        _burn(_delegator, _sharesAmount);
        _totalPooledBNB -= _bnbAmount;

        uint256 _gasLimit = IStakeHub(STAKE_HUB_ADDR).transferGasLimit();
        (bool success,) = STAKE_HUB_ADDR.call{gas: _gasLimit, value: _bnbAmount}("");
        require(success, "TRANSFER_FAILED");

        emit Unbonded(_delegator, _sharesAmount, _bnbAmount);
        return _bnbAmount;
    }

    function claim(address payable _delegator, uint256 number) external onlyStakeHub nonReentrant returns (uint256) {
        if (_delegator == validator) {
            require(!_freeze, "FROZEN");
        }

        require(_unbondRequestsQueue[_delegator].length() != 0, "NO_UNBOND_REQUEST");
        // number == 0 means claim all
        if (number == 0) {
            number = _unbondRequestsQueue[_delegator].length();
        }
        if (number > _unbondRequestsQueue[_delegator].length()) {
            number = _unbondRequestsQueue[_delegator].length();
        }

        uint256 _totalShares;
        uint256 _totalBnbAmount;
        while (number != 0) {
            bytes32 hash = _unbondRequestsQueue[_delegator].front();
            UnbondRequest memory request = _unbondRequests[hash];
            if (block.timestamp < request.unlockTime) {
                break;
            }

            _totalShares += request.sharesAmount;
            _totalBnbAmount += request.bnbAmount;

            // remove from the queue
            _unbondRequestsQueue[_delegator].popFront();
            delete _unbondRequests[hash];

            number -= 1;
        }

        _lockedShares[_delegator] -= _totalShares;
        uint256 _gasLimit = IStakeHub(STAKE_HUB_ADDR).transferGasLimit();
        (bool success,) = _delegator.call{gas: _gasLimit, value: _totalBnbAmount}("");
        require(success, "CLAIM_FAILED");

        emit UnbondClaimed(_delegator, _totalShares, _totalBnbAmount);
        return _totalBnbAmount;
    }

    function distributeReward(uint256 commissionRate) external payable onlyStakeHub {
        uint256 _bnbAmount = msg.value;
        uint256 _commission = (_bnbAmount * commissionRate) / COMMISSION_RATE_BASE;
        uint256 _reward = _bnbAmount - _commission;
        _totalPooledBNB += _reward;

        // mint reward to the validator
        uint256 _sharesAmount = getSharesByPooledBNB(_commission);
        _totalPooledBNB += _commission;
        _mint(validator, _sharesAmount);

        emit RewardReceived(_reward, _commission);
    }

    function slash(uint256 _slashBnbAmount) external onlyStakeHub returns (uint256) {
        uint256 _selfDelegation = balanceOf(validator);
        uint256 _slashShares = getSharesByPooledBNB(_slashBnbAmount);

        uint256 remainingSlashBnbAmount_;
        if (_slashShares <= _selfDelegation) {
            _totalPooledBNB -= _slashBnbAmount;
            _burn(validator, _slashShares);
        } else {
            uint256 _selfDelegationBNB = getPooledBNBByShares(_selfDelegation);
            _totalPooledBNB -= _selfDelegationBNB;
            _burn(validator, _selfDelegation);

            remainingSlashBnbAmount_ = _slashBnbAmount - _selfDelegationBNB;

            _freeze = true;
            _remainingSlashBnbAmount += remainingSlashBnbAmount_;
        }

        uint256 _gasLimit = IStakeHub(STAKE_HUB_ADDR).transferGasLimit();
        uint256 _realSlashBnbAmount = _slashBnbAmount - remainingSlashBnbAmount_;
        (bool success,) = SYSTEM_REWARD_ADDR.call{gas: _gasLimit, value: _realSlashBnbAmount}("");
        require(success, "TRANSFER_FAILED");
        return _realSlashBnbAmount;
    }

    function payFine() external payable {
        require(_freeze, "NOT_FROZEN");
        require(msg.value == _remainingSlashBnbAmount, "INVALID_AMOUNT");

        _freeze = false;
        _remainingSlashBnbAmount = 0;

        uint256 _gasLimit = IStakeHub(STAKE_HUB_ADDR).transferGasLimit();
        (bool success,) = SYSTEM_REWARD_ADDR.call{gas: _gasLimit, value: msg.value}("");
        require(success, "TRANSFER_FAILED");

        emit PayFine(msg.value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @return the amount of shares that corresponds to `_bnbAmount` protocol-controlled BNB.
     */
    function getSharesByPooledBNB(uint256 _bnbAmount) public view returns (uint256) {
        return (_bnbAmount * totalSupply()) / _totalPooledBNB;
    }

    /**
     * @return the amount of BNB that corresponds to `_sharesAmount` token shares.
     */
    function getPooledBNBByShares(uint256 _sharesAmount) public view returns (uint256) {
        return (_sharesAmount * _totalPooledBNB) / totalSupply();
    }

    function totalPooledBNB() public view returns (uint256) {
        return _totalPooledBNB;
    }

    function unbondRequest(address _delegator, uint256 _index) public view returns (UnbondRequest memory, uint256) {
        bytes32 hash = _unbondRequestsQueue[_delegator].at(_index);
        return (_unbondRequests[hash], _unbondRequestsQueue[_delegator].length());
    }

    function lockedShares(address _delegator) public view returns (uint256) {
        return _lockedShares[_delegator];
    }

    function unbondSequence(address _delegator) public view returns (uint256) {
        return _unbondSequence[_delegator].current();
    }

    function isFreeze() public view returns (bool) {
        return _freeze;
    }

    function remainingSlashBnbAmount() public view returns (uint256) {
        return _remainingSlashBnbAmount;
    }

    function getSecurityDepositBNB() public view returns (uint256) {
        return getPooledBNBByShares(balanceOf(STAKE_HUB_ADDR));
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
        assert(totalSupply() == 0);

        // mint initial tokens to the validator
        // shares is equal to the amount of BNB staked
        _totalPooledBNB = _initAmount;
        emit Delegated(validator, _initAmount, _initAmount);
        _mint(validator, _initAmount);
    }

    function _useSequence(address delegator) internal returns (uint256 current) {
        CountersUpgradeable.Counter storage sequence = _unbondSequence[delegator];
        current = sequence.current();
        sequence.increment();
    }

    function _transfer(address from, address to, uint256 amount) internal pure override {
        revert("stBNB transfer is not supported");
    }

    function _approve(address owner, address spender, uint256 amount) internal pure override {
        revert("stBNB approve is not supported");
    }
}
