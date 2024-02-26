// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import "./System.sol";
import "./interface/IStakeCredit.sol";

contract GovToken is
    System,
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable
{
    /*----------------- constants -----------------*/
    string private constant NAME = "BSC Governance Token";
    string private constant SYMBOL = "govBNB";

    /*----------------- errors -----------------*/
    // @notice signature: 0x8cd22d19
    error TransferNotAllowed();
    // @notice signature: 0x20287471
    error ApproveNotAllowed();
    // @notice signature: 0xe5d87767
    error BurnNotAllowed();

    /*----------------- storage -----------------*/
    // validator StakeCredit contract => user => amount
    mapping(address => mapping(address => uint256)) public mintedMap;

    /*----------------- init -----------------*/
    function initialize() public initializer onlyCoinbase onlyZeroGasPrice {
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __ERC20Permit_init(NAME);
        __ERC20Votes_init();
    }

    /*----------------- external functions -----------------*/
    /**
     * @dev Sync the account's govBNB amount to the actual BNB value of the StakingCredit he holds
     * @param stakeCredit the stakeCredit Token contract
     * @param account the account to sync gov tokens to
     */
    function sync(address stakeCredit, address account) external onlyStakeHub {
        _sync(stakeCredit, account);
    }

    /**
     * @dev Batch sync the account's govBNB amount to the actual BNB value of the StakingCredit he holds
     * @param stakeCredits the stakeCredit Token contracts
     * @param account the account to sync gov tokens to
     */
    function syncBatch(address[] calldata stakeCredits, address account) external onlyStakeHub {
        uint256 _length = stakeCredits.length;
        for (uint256 i = 0; i < _length; ++i) {
            _sync(stakeCredits[i], account);
        }
    }

    /**
     * @dev delegate govBNB votes to delegatee
     * @param delegator the delegator
     * @param delegatee the delegatee
     */
    function delegateVote(address delegator, address delegatee) external onlyStakeHub {
        _delegate(delegator, delegatee);
    }

    function burn(uint256) public pure override {
        revert BurnNotAllowed();
    }

    function burnFrom(address, uint256) public pure override {
        revert BurnNotAllowed();
    }

    /*----------------- internal functions -----------------*/
    function _sync(address stakeCredit, address account) internal {
        uint256 latestBNBAmount = IStakeCredit(stakeCredit).getPooledBNB(account);
        uint256 _mintedAmount = mintedMap[stakeCredit][account];

        if (_mintedAmount < latestBNBAmount) {
            uint256 _needMint = latestBNBAmount - _mintedAmount;
            mintedMap[stakeCredit][account] = latestBNBAmount;
            _mint(account, _needMint);
        } else if (_mintedAmount > latestBNBAmount) {
            uint256 _needBurn = _mintedAmount - latestBNBAmount;
            mintedMap[stakeCredit][account] = latestBNBAmount;
            _burn(account, _needBurn);
        }
    }

    function _transfer(address, address, uint256) internal pure override {
        revert TransferNotAllowed();
    }

    function _approve(address, address, uint256) internal pure override {
        revert ApproveNotAllowed();
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        ERC20VotesUpgradeable._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        ERC20VotesUpgradeable._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        ERC20VotesUpgradeable._burn(account, amount);
    }
}
