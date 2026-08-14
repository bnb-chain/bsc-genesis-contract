// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPaymentLaneMeta {
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

    function getPaymentLaneParams() external view returns (Params memory);

    function arePaymentContracts(
        address[] calldata addrs
    ) external view returns (bool[] memory results);

    function isPaymentContract(
        address paymentContract
    ) external view returns (bool);

    function paymentContractCount() external view returns (uint256);

    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory paymentContracts, uint256 totalLength);
}
