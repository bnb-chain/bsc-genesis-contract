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
    // @notice signature: 0x2fe8dae9
    error ZeroTotalShares();
    // @notice signature: 0xf6ed9ce0
    error ZeroTotalPooledBNB();
    // @notice signature: 0x8cd22d19
    error TransferNotAllowed();
    // @notice signature: 0x20287471
    error ApproveNotAllowed();
    // @notice signature: 0x858f9ae4
    error WrongInitContext();
    // @notice signature: 0x90b8ec18
    error TransferFailed();
    // @notice signature: 0x1f2a2005
    error ZeroAmount();
    // @notice signature: 0x9811e0c7
    error ZeroShares();
    // @notice signature: 0xf4d678b8
    error InsufficientBalance();
    // @notice signature: 0xad418937
    error NoUnbondRequest();
    // @notice signature: 0x0f363824
    error NoClaimableUnbondRequest();
    // @notice signature: 0xb19e9115
    error RequestExisted();

    /*----------------- storage -----------------*/
    address public validator; // validator's operator address
    uint256 public totalPooledBNB; // total reward plus total BNB staked in the pool

    // hash of the unbond request => unbond request
    mapping(bytes32 => UnbondRequest) private _unbondRequests;
    // delegator address => unbond request queue(hash of the request)
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) private _unbondRequestsQueue;
    // delegator address => personal unbond sequence
    mapping(address => CountersUpgradeable.Counter) private _unbondSequence;

    // day index => receivedReward
    mapping(uint256 => uint256) public rewardRecord;
    // day index => totalPooledBNB
    mapping(uint256 => uint256) public totalPooledBNBRecord;

    /*----------------- structs and events -----------------*/
    struct UnbondRequest {
        uint256 shares;
        uint256 bnbAmount;
        uint256 unlockTime;
    }

    event RewardReceived(uint256 rewardToAll, uint256 commission);

    /**
     * @notice only accept BNB from `StakeHub`
     */
    receive() external payable onlyStakeHub {
        uint256 index = block.timestamp / IStakeHub(STAKE_HUB_ADDR).BREATHE_BLOCK_INTERVAL();
        totalPooledBNBRecord[index] = totalPooledBNB;
        rewardRecord[index] += msg.value;
        totalPooledBNB += msg.value;
    }

    /*----------------- init -----------------*/
    /*
     * @param _validator validator's operator address
     * @param _moniker validator's moniker
     */
    function initialize(address _validator, string calldata _moniker) external payable initializer onlyStakeHub {
        string memory name_ = string.concat("Stake ", _moniker, " Credit");
        string memory symbol_ = string.concat("st", _moniker);
        __ERC20_init_unchained(name_, symbol_);
        __ReentrancyGuard_init_unchained();

        validator = _validator;

        _bootstrapInitialHolder(msg.value);
    }

    /*----------------- external functions -----------------*/
    /**
     * @param delegator the address of the delegator
     * @return shares the amount of shares minted
     */
    function delegate(address delegator) external payable onlyStakeHub returns (uint256 shares) {
        if (msg.value == 0) revert ZeroAmount();
        shares = _mintAndSync(delegator, msg.value);
        if (shares == 0) revert ZeroShares();
    }

    /**
     * @param delegator the address of the delegator
     * @param shares the amount of shares to be undelegated
     * @return bnbAmount the amount of BNB to be unlocked
     */
    function undelegate(address delegator, uint256 shares) external onlyStakeHub returns (uint256 bnbAmount) {
        if (shares == 0) revert ZeroShares();
        if (shares > balanceOf(delegator)) revert InsufficientBalance();

        // add to the queue
        bnbAmount = _burnAndSync(delegator, shares);
        uint256 unlockTime = block.timestamp + IStakeHub(STAKE_HUB_ADDR).unbondPeriod();
        UnbondRequest memory request = UnbondRequest({ shares: shares, bnbAmount: bnbAmount, unlockTime: unlockTime });
        bytes32 hash = keccak256(abi.encodePacked(delegator, _useSequence(delegator)));
        // the hash should not exist in the queue
        // this will not happen in normal cases
        if (_unbondRequests[hash].shares != 0) revert RequestExisted();
        _unbondRequests[hash] = request;
        _unbondRequestsQueue[delegator].pushBack(hash);
    }

    /**
     * @dev Unbond immediately without adding to the queue. Only for redelegate process.
     * @param delegator the address of the delegator
     * @param shares the amount of shares to be undelegated
     * @return bnbAmount the amount of BNB unlocked
     */
    function unbond(address delegator, uint256 shares) external onlyStakeHub returns (uint256 bnbAmount) {
        if (shares == 0) revert ZeroShares();
        if (shares > balanceOf(delegator)) revert InsufficientBalance();

        bnbAmount = _burnAndSync(delegator, shares);

        (bool success,) = STAKE_HUB_ADDR.call{ value: bnbAmount }("");
        if (!success) revert TransferFailed();
    }

    /**
     * @param delegator the address of the delegator
     * @param number the number of unbond requests to be claimed. 0 means claim all
     * @return _totalBnbAmount the total amount of BNB claimed
     */
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

            _totalBnbAmount += request.bnbAmount;
            --number;
        }
        if (_totalBnbAmount == 0) revert NoClaimableUnbondRequest();

        uint256 _gasLimit = IStakeHub(STAKE_HUB_ADDR).transferGasLimit();
        (bool success,) = delegator.call{ gas: _gasLimit, value: _totalBnbAmount }("");
        if (!success) revert TransferFailed();

        return _totalBnbAmount;
    }

    /**
     * @dev Distribute the reward to the validator and all delegators. Only the `StakeHub` contract can call this function.
     * @param commissionRate the commission rate of the validator
     */
    function distributeReward(uint64 commissionRate) external payable onlyStakeHub {
        uint256 bnbAmount = msg.value;
        uint256 _commission = (bnbAmount * uint256(commissionRate)) / COMMISSION_RATE_BASE;
        uint256 _reward = bnbAmount - _commission;

        uint256 index = block.timestamp / IStakeHub(STAKE_HUB_ADDR).BREATHE_BLOCK_INTERVAL();
        totalPooledBNBRecord[index] = totalPooledBNB;
        rewardRecord[index] += _reward;
        totalPooledBNB += _reward;

        // mint commission to the validator
        _mintAndSync(validator, _commission);

        emit RewardReceived(_reward, _commission);
    }

    /**
     * @dev Slash the validator. Only the `StakeHub` contract can call this function.
     * @param slashBnbAmount the amount of BNB to be slashed
     * @return realSlashBnbAmount the real amount of BNB slashed
     */
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

    /**
     * @return the unbond request at _index.
     */
    function unbondRequest(address delegator, uint256 _index) public view returns (UnbondRequest memory) {
        bytes32 hash = _unbondRequestsQueue[delegator].at(_index);
        return _unbondRequests[hash];
    }

    /**
     * @return the total length of delegator's pending unbond queue.
     */
    function pendingUnbondRequest(address delegator) public view returns (uint256) {
        return _unbondRequestsQueue[delegator].length();
    }

    /**
     * @return the total number of delegator's claimable unbond requests.
     */
    function claimableUnbondRequest(address delegator) public view returns (uint256) {
        uint256 length = _unbondRequestsQueue[delegator].length();
        uint256 count;
        for (uint256 i; i < length; ++i) {
            bytes32 hash = _unbondRequestsQueue[delegator].at(i);
            UnbondRequest memory request = _unbondRequests[hash];
            if (block.timestamp >= request.unlockTime) {
                ++count;
            } else {
                break;
            }
        }
        return count;
    }

    /**
     * @return the sum of first `number` requests' BNB locked in delegator's unbond queue.
     */
    function lockedBNBs(address delegator, uint256 number) public view returns (uint256) {
        // number == 0 means all
        // number should not exceed the length of the queue
        if (_unbondRequestsQueue[delegator].length() == 0) {
            return 0;
        }
        number = (number == 0 || number > _unbondRequestsQueue[delegator].length())
            ? _unbondRequestsQueue[delegator].length()
            : number;

        uint256 _totalBnbAmount;
        for (uint256 i; i < number; ++i) {
            bytes32 hash = _unbondRequestsQueue[delegator].at(i);
            UnbondRequest memory request = _unbondRequests[hash];
            _totalBnbAmount += request.bnbAmount;
        }
        return _totalBnbAmount;
    }

    /**
     * @return the personal unbond sequence of the delegator.
     */
    function unbondSequence(address delegator) public view returns (uint256) {
        return _unbondSequence[delegator].current();
    }

    /**
     * @return the total amount of BNB staked and reward of the delegator.
     */
    function getPooledBNB(address account) public view returns (uint256) {
        return getPooledBNBByShares(balanceOf(account));
    }

    /*----------------- internal functions -----------------*/
    function _bootstrapInitialHolder(uint256 initAmount) internal onlyInitializing {
        // check before mint
        uint256 toLock = IStakeHub(STAKE_HUB_ADDR).LOCK_AMOUNT();
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
        // shares here could be zero
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
