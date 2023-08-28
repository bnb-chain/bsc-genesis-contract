// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @title Interest-bearing ERC20-like token for BSC New Staking protocol.
 *
 * This contract is abstract. To make the contract deployable override the
 * `_getTotalPooledBNB` function. `StakePool.sol` contract inherits StBNB and defines
 * the `_getTotalPooledBNB` function.
 *
 * StBNB balance only changes on transfers and represents the holder's share of the
 * total staked funds. Account shares aren't normalized, so the
 * contract also stores the sum of all shares. When staking happens, the user's shares
 * are calculated as:
 *
 * shares[account] = stakedAmount * _getTotalShares() / _getTotalPooledEther()
 *
 * The token inherits from `PausableUpgradeable` and uses `whenNotStopped` modifier for methods
 * which change `_shares` or `_allowances`. `_stop` and `_resume` functions are overridden
 * in `StakePool.sol` and might be called by an account with the `PAUSE_ROLE`. This is useful
 * for emergency scenarios, e.g. a protocol bug, where one might want
 * to freeze all token transfers and approvals until the emergency is resolved.
 */
abstract contract StBNB is IERC20, ContextUpgradeable {
    uint256 internal constant INFINITE_ALLOWANCE = type(uint256).max;

    // which also represents the balances of all token holders
    mapping(address => uint256) private _shares;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalShares;

    /**
     * @return the name of the token.
     */
    function name() external pure returns (string memory) {
        return "BSC staked BNB 2.0";
    }

    /**
     * @return the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external pure returns (string memory) {
        return "StBNB";
    }

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @return the amount of tokens in existence.
     *
     * @dev Equals to `_getTotalShares()`.
     */
    function totalSupply() external view returns (uint256) {
        return _getTotalShares();
    }

    /**
     * @return the entire amount of BNB controlled by the protocol.
     *
     * @dev The sum of all BNB balances in the protocol.
     */
    function getTotalPooledBNB() external view returns (uint256) {
        return _getTotalPooledBNB();
    }

    /**
     * @return the amount of tokens owned by the `_account`.
     *
     * @dev Balances are equal to the shares.
     */
    function balanceOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }

    /**
     * @notice Moves `_amount` tokens from the caller's account to the `_recipient` account.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     * - the caller must have a balance of at least `_amount`.
     * - the contract must not be paused.
     */
    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        address owner = _msgSender();
        _transfer(owner, _recipient, _amount);
        return true;
    }

    /**
     * @return the remaining number of tokens that `_spender` is allowed to spend
     * on behalf of `_owner` through `transferFrom`. This is zero by default.
     *
     * @dev This value changes when `approve` or `transferFrom` is called.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
     *
     * @return a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        address owner = _msgSender();
        _approve(owner, _spender, _amount);
        return true;
    }

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient` using the
     * allowance mechanism. `_amount` is then deducted from the caller's
     * allowance.
     *
     * @return a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_sender` and `_recipient` cannot be the zero addresses.
     * - `_sender` must have a balance of at least `_amount`.
     * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
     * - the contract must not be paused.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool) {
        address spender = _msgSender();
        _spendAllowance(_sender, spender, _amount);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `_spender` by the caller by `_addedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_spender` cannot be the the zero address.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        address owner = _msgSender();
        _approve(owner, _spender, allowance(owner, _spender) + _addedValue);
        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `_spender` by the caller by `_subtractedValue`.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in:
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/b709eae01d1da91902d06ace340df6b324e6f049/contracts/token/ERC20/IERC20.sol#L57
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `_spender` cannot be the zero address.
     * - `_spender` must have allowance for the caller of at least `_subtractedValue`.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, _spender);
        require(currentAllowance >= _subtractedValue, "ALLOWANCE_BELOW_ZERO");
        unchecked {
            _approve(owner, _spender, currentAllowance - _subtractedValue);
        }
        return true;
    }

    /**
     * @return the total amount of shares in existence.
     *
     * @dev The sum of all accounts' shares can be an arbitrary number, therefore
     * it is necessary to store it in order to calculate each account's relative share.
     */
    function getTotalShares() external view returns (uint256) {
        return _getTotalShares();
    }

    /**
     * @return the amount of shares that corresponds to `_bnbAmount` protocol-controlled BNB.
     */
    function getSharesByPooledBNB(uint256 _bnbAmount) public view returns (uint256) {
        return (_bnbAmount * _getTotalShares()) / _getTotalPooledBNB();
    }

    /**
     * @return the amount of BNB that corresponds to `_sharesAmount` token shares.
     */
    function getPooledBNBByShares(uint256 _sharesAmount) public view returns (uint256) {
        return (_sharesAmount * _getTotalPooledBNB()) / _getTotalShares();
    }

    /**
     * @return the total amount (in wei) of BNB controlled by the protocol.
     * @dev This is used for calculating tokens from shares and vice versa.
     * @dev This function is required to be implemented in a derived contract.
     */
    function _getTotalPooledBNB() internal view virtual returns (uint256);

    /**
     * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
     * Emits a `Transfer` event.
     * Emits a `TransferShares` event.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        require(_sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(_recipient != address(0), "TRANSFER_TO_ZERO_ADDR");
        require(_recipient != address(this), "TRANSFER_TO_STBNB_CONTRACT");

        uint256 currentSenderShares = _shares[_sender];
        require(currentSenderShares >= _amount, "BALANCE_EXCEEDED");
        unchecked {
            _shares[_sender] = currentSenderShares - _amount;
            // Overflow not possible: the sum of all shares is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _shares[_recipient] += _amount;
        }

        emit Transfer(_sender, _recipient, _amount);
    }

    /**
     * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
     *
     * Emits an `Approval` event.
     *
     * NB: the method can be invoked even if the protocol paused.
     *
     * Requirements:
     *
     * - `_owner` cannot be the zero address.
     * - `_spender` cannot be the zero address.
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDR");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDR");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal {
        uint256 currentAllowance = allowance(_owner, _spender);
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "ALLOWANCE_EXCEEDED");
            unchecked {
                _approve(_owner, _spender, currentAllowance - _amount);
            }
        }
    }

    /**
     * @dev Creates `_sharesAmount` tokens and assigns them to `_recipient`, increasing
     * the total shares.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `_recipient` cannot be the zero address.
     */
    function _mint(address _recipient, uint256 _sharesAmount) internal virtual {
        require(_recipient != address(0), "MINT_TO_ZERO_ADDR");

        _totalShares += _sharesAmount;
        unchecked {
            // Overflow not possible: share + _sharesAmount is at most totalShares + _sharesAmount, which is checked above.
            _shares[_recipient] += _sharesAmount;
        }
        emit Transfer(address(0), _recipient, _sharesAmount);
    }

    /**
     * @dev Destroys `_sharesAmount` tokens from `_account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `_account` cannot be the zero address.
     * - `_account` must have at least `_sharesAmount` tokens.
     */
    function _burn(address _account, uint256 _sharesAmount) internal virtual {
        require(_account != address(0), "BURN_FROM_ZERO_ADDR");

        uint256 accountShares = _shares[_account];
        require(accountShares >= _sharesAmount, "BALANCE_EXCEEDED");
        unchecked {
            _shares[_account] = accountShares - _sharesAmount;
            // Overflow not possible: _sharesAmount <= accountShares <= totalShares.
            _totalShares -= _sharesAmount;
        }

        emit Transfer(_account, address(0), _sharesAmount);
    }

    /**
     * @return the total amount of shares in existence.
     */
    function _getTotalShares() internal view returns (uint256) {
        return _totalShares;
    }

    /**
     * @return the amount of shares owned by `_account`.
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return _shares[_account];
    }
}
