// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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

    /*----------------- storage -----------------*/
    // validator StakeCredit contract => user => amount
    mapping(address => mapping(address => uint256)) public mintedMap;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    function initialize() public initializer {
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __ERC20Permit_init(NAME);
        __ERC20Votes_init();
    }

    /*----------------- external functions -----------------*/

    /**
     * @dev delegate govBNB votes to delegatee
     * @param delegator the delegator
     * @param delegatee the delegatee
     */
    function delegateVote(address delegator, address delegatee) external onlyStakeHub {
        _delegate(delegator, delegatee);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
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
