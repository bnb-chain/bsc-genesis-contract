// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./System.sol";
import "./interface/IStakeHub.sol";

contract StakeCredit is System, Initializable, ReentrancyGuardUpgradeable, ERC20Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    /*----------------- constants -----------------*/
    uint256 private constant COMMISSION_RATE_BASE = 10_000; // 100%

    /*----------------- errors -----------------*/
    error ZeroTotalShares();
    error ZeroTotalPooledBNB();
    error TransferNotAllowed();
    error ApproveNotAllowed();
    error WrongInitContext();
    error TransferFailed();
    error ZeroAmount();
    error InsufficientBalance();
    error NoUnbondRequest();
    error NoClaimableUnbondRequest();

    /*----------------- storage -----------------*/
    address public validator; // validator's operator address
    uint256 public totalPooledBNB; // total reward plus total BNB staked in the pool

    // hash of the unbond request => unbond request
    mapping(bytes32 => UnbondRequest) private _unbondRequests;
    // delegator address => unbond request queue(hash of the request)
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) private _unbondRequestsQueue;
    // delegator address => personal unbond sequence
    mapping(address => CountersUpgradeable.Counter) private _unbondSequence;

    /*----------------- structs and events -----------------*/
    struct UnbondRequest {
        uint256 shares;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    event RewardReceived(uint256 rewardToAll, uint256 commission);

    /*----------------- init -----------------*/
    function initialize(address _validator, string calldata _moniker) external payable initializer onlyStakeHub {
        string memory name_ = string.concat("Stake ", _moniker, " Credit");
        string memory symbol_ = string.concat("st", _moniker);
        __ERC20_init_unchained(name_, symbol_);

        validator = _validator;

        _bootstrapInitialHolder(msg.value);
    }

    /*----------------- external functions -----------------*/
    function delegate(address delegator) external payable onlyStakeHub returns (uint256 shares) {
        if (msg.value == 0) revert ZeroAmount();
        shares = _mintAndSync(delegator, msg.value);
    }

    function undelegate(address delegator, uint256 shares) external onlyStakeHub returns (uint256 bnbAmount) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf(delegator)) revert InsufficientBalance();

        // add to the queue
        bnbAmount = _burnAndSync(delegator, shares);
        uint256 unlockTime = block.timestamp + IStakeHub(STAKE_HUB_ADDR).unbondPeriod();
        UnbondRequest memory request = UnbondRequest({ shares: shares, bnbAmount: bnbAmount, unlockTime: unlockTime });
        bytes32 hash = keccak256(abi.encodePacked(delegator, _useSequence(delegator)));
        _unbondRequests[hash] = request;
        _unbondRequestsQueue[delegator].pushBack(hash);
    }

    /**
     * @dev Unbond immediately without adding to the queue.
     * Only for redelegate process.
     */
    function unbond(address delegator, uint256 shares) external onlyStakeHub returns (uint256 bnbAmount) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf(delegator)) revert InsufficientBalance();

        bnbAmount = _burnAndSync(delegator, shares);

        (bool success,) = STAKE_HUB_ADDR.call{ value: bnbAmount }("");
        if (!success) revert TransferFailed();
    }

    function claim(address payable delegator, uint256 number) external onlyStakeHub nonReentrant returns (uint256) {
        // number == 0 means claim all
        // number should not exceed the length of the queue
        if (_unbondRequestsQueue[delegator].length() == 0) revert NoUnbondRequest();
        number = (number == 0 || number > _unbondRequestsQueue[delegator].length())
            ? _unbondRequestsQueue[delegator].length()
            : number;

        uint256 _totalBnbAmount;
        while (number != 0) {
            bytes32 hash = _unbondRequestsQueue[delegator].front();
            UnbondRequest memory request = _unbondRequests[hash];
            if (block.timestamp < request.unlockTime) {
                break;
            }

            // remove from the queue
            _unbondRequestsQueue[delegator].popFront();
            delete _unbondRequests[hash];

            _totalBnbAmount += request.bnbAmount;
            --number;
        }
        if (_totalBnbAmount == 0) revert NoClaimableUnbondRequest();

        uint256 _gasLimit = IStakeHub(STAKE_HUB_ADDR).transferGasLimit();
        (bool success,) = delegator.call{ gas: _gasLimit, value: _totalBnbAmount }("");
        if (!success) revert TransferFailed();

        return _totalBnbAmount;
    }

    function distributeReward(uint64 commissionRate) external payable onlyStakeHub {
        uint256 bnbAmount = msg.value;
        uint256 _commission = (bnbAmount * uint256(commissionRate)) / COMMISSION_RATE_BASE;
        uint256 _reward = bnbAmount - _commission;
        totalPooledBNB += _reward;

        // mint commission to the validator
        _mintAndSync(validator, _commission);

        emit RewardReceived(_reward, _commission);
    }

    function slash(uint256 slashBnbAmount) external onlyStakeHub returns (uint256) {
        uint256 selfDelegation = balanceOf(validator);
        uint256 slashShares = getSharesByPooledBNB(slashBnbAmount);

        slashShares = slashShares > selfDelegation ? selfDelegation : slashShares;
        uint256 realSlashBnbAmount = _burnAndSync(validator, slashShares);

        (bool success,) = SYSTEM_REWARD_ADDR.call{ value: realSlashBnbAmount }("");
        if (!success) revert TransferFailed();

        return realSlashBnbAmount;
    }

    /*----------------- view functions -----------------*/
    /**
     * @return the amount of shares that corresponds to `_bnbAmount` protocol-controlled BNB.
     */
    function getSharesByPooledBNB(uint256 bnbAmount) public view returns (uint256) {
        if (totalPooledBNB == 0) revert ZeroTotalPooledBNB();
        return (bnbAmount * totalSupply()) / totalPooledBNB;
    }

    /**
     * @return the amount of BNB that corresponds to `_sharesAmount` token shares.
     */
    function getPooledBNBByShares(uint256 shares) public view returns (uint256) {
        if (totalSupply() == 0) revert ZeroTotalShares();
        return (shares * totalPooledBNB) / totalSupply();
    }

    function unbondRequest(address delegator, uint256 _index) public view returns (UnbondRequest memory, uint256) {
        bytes32 hash = _unbondRequestsQueue[delegator].at(_index);
        return (_unbondRequests[hash], _unbondRequestsQueue[delegator].length());
    }

    function lockedBNBs(address delegator) public view returns (uint256) {
        uint256 length = _unbondRequestsQueue[delegator].length();
        if (length == 0) {
            return 0;
        }

        uint256 _totalBnbAmount;
        for (uint256 i; i < length; ++i) {
            bytes32 hash = _unbondRequestsQueue[delegator].front();
            UnbondRequest memory request = _unbondRequests[hash];
            _totalBnbAmount += request.bnbAmount;
        }
        return _totalBnbAmount;
    }

    function unbondSequence(address delegator) public view returns (uint256) {
        return _unbondSequence[delegator].current();
    }

    function getPooledBNB(address account) public view returns (uint256) {
        return getPooledBNBByShares(balanceOf(account));
    }

    /*----------------- internal functions -----------------*/
    function _bootstrapInitialHolder(uint256 initAmount) internal onlyInitializing {
        // check before mint
        uint256 toLock = IStakeHub(STAKE_HUB_ADDR).INIT_LOCK_AMOUNT();
        if (initAmount <= toLock || validator == address(0) || totalSupply() != 0) revert WrongInitContext();

        // mint initial tokens to the validator and lock some of them
        // shares is equal to the amount of BNB staked
        address deadAddress = IStakeHub(STAKE_HUB_ADDR).DEAD_ADDRESS();
        _mint(deadAddress, toLock);
        uint256 initShares = initAmount - toLock;
        _mint(validator, initShares);

        totalPooledBNB = initAmount;
    }

    function _mintAndSync(address account, uint256 bnbAmount) internal returns (uint256 shares) {
        shares = getSharesByPooledBNB(bnbAmount);
        _mint(account, shares);
        totalPooledBNB += bnbAmount;
    }

    function _burnAndSync(address account, uint256 shares) internal returns (uint256 bnbAmount) {
        bnbAmount = getPooledBNBByShares(shares);
        _burn(account, shares);
        totalPooledBNB -= bnbAmount;
    }

    function _useSequence(address delegator) internal returns (uint256 current) {
        CountersUpgradeable.Counter storage sequence = _unbondSequence[delegator];
        current = sequence.current();
        sequence.increment();
    }

    function _transfer(address, address, uint256) internal pure override {
        revert TransferNotAllowed();
    }

    function _approve(address, address, uint256) internal pure override {
        revert ApproveNotAllowed();
    }
}
