// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract System {
    uint16 public constant bscChainID = 0x0060;

    address public constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
    address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
    address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
    address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
    address public constant STAKE_HUB_ADDR = 0x0000000000000000000000000000000000002002;
    address public constant STAKE_POOL_ADDR = 0x0000000000000000000000000000000000002003;
    address public constant GOVERNOR_ADDR = 0x0000000000000000000000000000000000002004;
    address public constant GOV_TOKEN_ADDR = 0x0000000000000000000000000000000000002006;
    address public constant TIMELOCK_ADDR = 0x0000000000000000000000000000000000002006;

    event ParamChange(string key, bytes value);

    modifier onlyCoinbase() {
        require(msg.sender == block.coinbase, "the message sender must be the block producer");
        _;
    }

    modifier onlyZeroGasPrice() {
        require(tx.gasprice == 0, "gasprice is not zero");
        _;
    }

    modifier onlyValidatorContract() {
        require(msg.sender == VALIDATOR_CONTRACT_ADDR, "the message sender must be validatorSet contract");
        _;
    }

    modifier onlySlash() {
        require(msg.sender == SLASH_CONTRACT_ADDR, "the message sender must be slash contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB_ADDR, "the message sender must be governance contract");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == GOVERNOR_ADDR, "the message sender must be governance v2 contract");
        _;
    }

    modifier onlyStakeHub() {
        require(msg.sender == STAKE_HUB_ADDR, "the msg sender must be stakeHub");
        _;
    }

    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _bytesToUint256(uint256 _offset, bytes memory _input) internal pure returns (uint256 _output) {
        assembly {
            _output := mload(add(_input, _offset))
        }
    }
}
