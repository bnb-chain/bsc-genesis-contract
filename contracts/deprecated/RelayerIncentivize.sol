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

    uint256 public constant ROUND_SIZE = 100;
    uint256 public constant MAXIMUM_WEIGHT = 40;

    uint256 public constant HEADER_RELAYER_REWARD_RATE_MOLECULE = 1;
    uint256 public constant HEADER_RELAYER_REWARD_RATE_DENOMINATOR = 5;
    uint256 public constant CALLER_COMPENSATION_MOLECULE = 1;
    uint256 public constant CALLER_COMPENSATION_DENOMINATOR = 80;

    uint256 public headerRelayerRewardRateMolecule;
    uint256 public headerRelayerRewardRateDenominator;
    uint256 public callerCompensationMolecule;
    uint256 public callerCompensationDenominator;

    mapping(address => uint256) public headerRelayersSubmitCount;
    address payable[] public headerRelayerAddressRecord;

    mapping(address => uint256) public packageRelayersSubmitCount;
    address payable[] public packageRelayerAddressRecord;

    uint256 public collectedRewardForHeaderRelayer = 0;
    uint256 public collectedRewardForTransferRelayer = 0;

    uint256 public roundSequence = 0;
    uint256 public countInRound = 0;

    mapping(address => uint256) public relayerRewardVault;

    uint256 public dynamicExtraIncentiveAmount;

    event distributeCollectedReward(
        uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer
    );
    event paramChange(string key, bytes value);
    event rewardToRelayer(address relayer, uint256 amount);

    function init() external onlyNotInit {
        revert("deprecated");
    }

    receive() external payable {
        revert("deprecated");
    }

    function addReward(
        address payable headerRelayerAddr,
        address payable packageRelayer,
        uint256 amount,
        bool fromSystemReward
    ) external override onlyInit onlyCrossChainContract returns (bool) {
        revert("deprecated");
    }

    function claimRelayerReward(address relayerAddr) external {
        revert("deprecated");
    }

    function calculateTransferRelayerWeight(uint256 count) public pure returns (uint256) {
        if (count <= MAXIMUM_WEIGHT) {
            return count;
        } else if (MAXIMUM_WEIGHT < count && count <= 2 * MAXIMUM_WEIGHT) {
            return MAXIMUM_WEIGHT;
        } else if (2 * MAXIMUM_WEIGHT < count && count <= (2 * MAXIMUM_WEIGHT + 3 * MAXIMUM_WEIGHT / 4)) {
            return 3 * MAXIMUM_WEIGHT - count;
        } else {
            return count / 4;
        }
    }

    function calculateHeaderRelayerWeight(uint256 count) public pure returns (uint256) {
        if (count <= MAXIMUM_WEIGHT) {
            return count;
        } else {
            return MAXIMUM_WEIGHT;
        }
    }

    function updateParam(string calldata key, bytes calldata value) external override onlyGov {
        revert("deprecated");
    }
}
