// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface PaymentLane {
    struct Params {
        uint256 paymentLaneMinRatio;
        uint256 paymentLaneMaxRatio;
        uint256 expandTriggerRatio;
        uint256 shrinkTriggerRatio;
        uint256 expandStepRatio;
        uint256 shrinkStepRatio;
        uint256 paymentLaneMin;
        uint256 paymentLaneMax;
    }

    error ExceedsMaxPaymentContracts();
    error InvalidValue(string key, bytes value);
    error OnlyCoinbase();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error PaymentContractAlreadyExists();
    error PaymentContractNotFound();
    error UnknownParam(string key, bytes value);

    event Initialized(uint8 version);
    event ParamChange(string key, bytes value);
    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);
    event PaymentLaneParamsUpdated(Params params);

    function MAX_LANE_GAS() external view returns (uint256);
    function MAX_LANE_RATIO() external view returns (uint256);
    function MAX_PAYMENT_CONTRACTS() external view returns (uint256);
    function MAX_RESERVED_ADDRESS() external view returns (uint256);
    function MAX_STEP_RATIO() external view returns (uint256);
    function MIN_EXPAND_TRIGGER_RATIO() external view returns (uint256);
    function MIN_LANE_GAS() external view returns (uint256);
    function MIN_SHRINK_TRIGGER_RATIO() external view returns (uint256);
    function RATIO_DENOM() external view returns (uint256);
    function RATIO_GAP_MIN() external view returns (uint256);
    function TRIGGER_GAP_MIN() external view returns (uint256);
    function arePaymentContracts(address[] memory addrs) external view returns (bool[] memory results);
    function expandStepRatio() external view returns (uint256);
    function expandTriggerRatio() external view returns (uint256);
    function getPaymentContracts(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory addrs, uint256 totalLength);
    function getPaymentLaneParams() external view returns (Params memory);
    function initialize() external;
    function isPaymentContract(address paymentContract) external view returns (bool);
    function paymentLaneMax() external view returns (uint256);
    function paymentLaneMaxRatio() external view returns (uint256);
    function paymentLaneMin() external view returns (uint256);
    function paymentLaneMinRatio() external view returns (uint256);
    function shrinkStepRatio() external view returns (uint256);
    function shrinkTriggerRatio() external view returns (uint256);
    function updateParam(string memory key, bytes memory value) external;
}
