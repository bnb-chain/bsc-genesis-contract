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

    error InvalidValue(string key, bytes value);
    error OnlyCoinbase();
    error OnlySystemContract(address systemContract);
    error OnlyZeroGasPrice();
    error PaymentContractAlreadyExists();
    error PaymentContractLimitExceeded();
    error PaymentContractNotFound();
    error UnknownParam(string key, bytes value);

    event ParamChange(string key, bytes value);
    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);
    event PaymentLaneParamsUpdated(Params params);

    function MAX_LANE_GAS() external view returns (uint256);
    function MAX_LANE_RATIO() external view returns (uint256);
    function MAX_PAYMENT_CONTRACTS() external view returns (uint256);
    function MAX_STEP_RATIO() external view returns (uint256);
    function MIN_EXPAND_TRIGGER_RATIO() external view returns (uint256);
    function MIN_LANE_GAS() external view returns (uint256);
    function MIN_SHRINK_TRIGGER_RATIO() external view returns (uint256);
    function RATIO_DENOM() external view returns (uint256);
    function RATIO_GAP_MIN() external view returns (uint256);
    function TRIGGER_GAP_MIN() external view returns (uint256);
    function arePaymentContracts(address[] memory addrs) external view returns (bool[] memory results);
    function paymentContractCount() external view returns (uint256);
    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory paymentContracts, uint256 totalLength);
    function getPaymentLaneParams() external view returns (Params memory);
    function isPaymentContract(address paymentContract) external view returns (bool);
    function updateParam(string memory key, bytes memory value) external;
}
