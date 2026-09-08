// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

/// @dev The BEP-703 section 3.6.4 consensus getters, the only way a node may read the payment
///      lane configuration. An upgrade of PaymentLane must preserve every member and its meaning.
interface IPaymentLaneMeta {
    function getPaymentLaneRatio() external view returns (uint256);

    function isPaymentContract(
        address paymentContract
    ) external view returns (bool);

    function arePaymentContracts(
        address[] calldata addrs
    ) external view returns (bool[] memory results);

    function paymentContractCount() external view returns (uint256);

    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory paymentContracts, uint256 totalLength);
}
