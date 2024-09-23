pragma solidity 0.6.4;

import "../interface/0.6.x/IRelayerIncentivize.sol";
import "../System.sol";
import "../lib/0.6.x/SafeMath.sol";
import "../lib/0.6.x/Memory.sol";
import "../lib/0.6.x/BytesToTypes.sol";
import "../interface/0.6.x/IParamSubscriber.sol";
import "../interface/0.6.x/ISystemReward.sol";

contract RelayerIncentivize is IRelayerIncentivize, System, IParamSubscriber {
    using SafeMath for uint256;

    uint256 public constant HEADER_RELAYER_REWARD_RATE_MOLECULE = 1;
    uint256 public constant HEADER_RELAYER_REWARD_RATE_DENOMINATOR = 5;
    uint256 public constant CALLER_COMPENSATION_MOLECULE = 1;
    uint256 public constant CALLER_COMPENSATION_DENOMINATOR = 80;

    uint256 public headerRelayerRewardRateMolecule;
    uint256 public headerRelayerRewardRateDenominator;
    uint256 public callerCompensationMolecule;
    uint256 public callerCompensationDenominator;

    mapping(address => uint256) public headerRelayersSubmitCount;  // @dev deprecated
    address payable[] public headerRelayerAddressRecord;  // @dev deprecated

    mapping(address => uint256) public packageRelayersSubmitCount;  // @dev deprecated
    address payable[] public packageRelayerAddressRecord;  // @dev deprecated

    uint256 public collectedRewardForHeaderRelayer = 0;  // @dev deprecated
    uint256 public collectedRewardForTransferRelayer = 0;  // @dev deprecated

    uint256 public roundSequence = 0;  // @dev deprecated
    uint256 public countInRound = 0;  // @dev deprecated

    mapping(address => uint256) public relayerRewardVault;

    uint256 public dynamicExtraIncentiveAmount;  // @dev deprecated

    event rewardToRelayer(address relayer, uint256 amount);

    event distributeCollectedReward(
        uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer
    );  // @dev deprecated
    event paramChange(string key, bytes value);  // @dev deprecated

    function init() external onlyNotInit {
        require(!alreadyInit, "already initialized");
        headerRelayerRewardRateMolecule = HEADER_RELAYER_REWARD_RATE_MOLECULE;
        headerRelayerRewardRateDenominator = HEADER_RELAYER_REWARD_RATE_DENOMINATOR;
        callerCompensationMolecule = CALLER_COMPENSATION_MOLECULE;
        callerCompensationDenominator = CALLER_COMPENSATION_DENOMINATOR;
        alreadyInit = true;
    }

    receive() external payable { }

    function addReward(
        address payable headerRelayerAddr,
        address payable packageRelayer,
        uint256 amount,
        bool fromSystemReward
    ) external override onlyInit onlyCrossChainContract returns (bool) {
        revert("deprecated");
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyGov {
        revert("deprecated");
    }
}
