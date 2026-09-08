// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface PaymentLane {
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

    function MAX_PAYMENT_CONTRACTS() external view returns (uint256);
    function MAX_PAYMENT_LANE_RATIO() external view returns (uint256);
    function RATIO_DENOM() external view returns (uint256);
    function arePaymentContracts(
        address[] memory addrs
    ) external view returns (bool[] memory results);
    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory paymentContracts, uint256 totalLength);
    function getPaymentLaneRatio() external view returns (uint256);
    function isPaymentContract(
        address paymentContract
    ) external view returns (bool);
    function paymentContractCount() external view returns (uint256);
    function updateParam(string memory key, bytes memory value) external;
}
