// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

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
    string private constant NAME = "BSC Governance Token";
    string private constant SYMBOL = "govBNB";

    // validator StakeCredit contract => user => amount
    mapping(address => mapping(address => uint256)) public mintedMap;

    function initialize() public initializer onlyCoinbase onlyZeroGasPrice {
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __ERC20Permit_init(NAME);
        __ERC20Votes_init();
    }

    function sync(address[] calldata validatorPools, address account) external onlyStakeHub {
        uint256 _length = validatorPools.length;
        for (uint256 i = 0; i < _length; ++i) {
            _sync(validatorPools[i], account);
        }
    }

    function delegateVote(address delegator, address delegatee) external onlyStakeHub {
        _delegate(delegator, delegatee);
    }

    function _sync(address validatorPool, address account) private {
        uint256 latestBNBAmount = IStakeCredit(validatorPool).getPooledBNB(account);
        uint256 _mintedAmount = mintedMap[validatorPool][account];

        if (_mintedAmount < latestBNBAmount) {
            uint256 _needMint = latestBNBAmount - _mintedAmount;
            mintedMap[validatorPool][account] = latestBNBAmount;
            _mint(account, _needMint);
        } else if (_mintedAmount > latestBNBAmount) {
            uint256 _needBurn = _mintedAmount - latestBNBAmount;
            mintedMap[validatorPool][account] = latestBNBAmount;
            _burn(account, _needBurn);
        }
    }

    function _transfer(address, address, uint256) internal pure override(ERC20Upgradeable) {
        revert("transfer not allowed");
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(account, amount);
    }
}
