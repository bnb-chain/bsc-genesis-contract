// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./SystemV2.sol";
import "./interface/0.8.x/IPaymentLaneMeta.sol";
import "./lib/0.8.x/Utils.sol";

/**
 * @title PaymentLane
 * @notice Configuration for BEP-703: the one governable ratio of section 3.6.1 and the payment
 *         contract list of section 3.6.2. Section 3.6.3 specifies this contract itself.
 *
 * @dev The BSC client reads this contract against the parent block's post-state, through
 *      IPaymentLaneMeta - the ratio to derive the block's lane quota, and membership to classify
 *      each transaction's destination. Section 3.6.4 requires those getters to be pure functions
 *      of this contract's own storage: no block/msg/tx environment reads, no blockhash, and no
 *      external calls, so a node may cache them by this account's `(codeHash, storageRoot)`.
 *
 *      An upgrade must preserve the getters and their meaning: `getPaymentLaneRatio()`'s
 *      zero-means-unwritten fallback, which is why the client is forbidden from decoding storage
 *      directly, and the pagination semantics of `getPaymentContracts()`.
 *
 *      There is no `initialize()` and no genesis storage, per section 3.6.3: 0 is not a settable
 *      ratio, so an unwritten slot reads as `DEFAULT_PAYMENT_LANE_RATIO` and all-zero storage
 *      already IS the shipped configuration - installing the code is the whole of activation. New
 *      storage must be appended, never inserted or reordered.
 */
contract PaymentLane is SystemV2, IPaymentLaneMeta {
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constants -----------------*/
    // BEP-703 section 3.6.1. A stored ratio `N` means `N / RATIO_DENOM` of the block gas limit.
    uint256 public constant RATIO_DENOM = 10_000;

    // Section 3.6.1's guard is `0 < PAYMENT_LANE_RATIO <= MAX_PAYMENT_LANE_RATIO`, and it is the
    // only bound on the reservation: what keeps the share from being voted to one that starves
    // general traffic. Must stay `constant` - a ceiling governance can raise is not a ceiling.
    uint256 public constant MAX_PAYMENT_LANE_RATIO = 1_000; // lane <= 10% of any GasLimit

    // Section 3.6.1: caps the work of materialising the list. Enforced here on the governance
    // write and checked by nodes on read, so the value moves only at a fork - here and in
    // every client at once.
    uint256 public constant MAX_PAYMENT_CONTRACTS = 100_000;

    // The value an unwritten slot reads as - section 3.6.1's normative default. Revising it at a
    // later fork revises the live reservation on every chain where governance never wrote one.
    uint256 private constant DEFAULT_PAYMENT_LANE_RATIO = 500; // 5%

    /*----------------- errors -----------------*/
    // @notice signature: 0x6e45c90c
    error PaymentContractAlreadyExists();
    // @notice signature: 0x949d443a
    error PaymentContractNotFound();
    // @notice signature: 0xb3a28ad3
    error PaymentContractLimitExceeded();

    /*----------------- storage -----------------*/
    // Append new state at the bottom; do not insert or reorder. The slot stays private so callers
    // always read through getPaymentLaneRatio(), the one place the default fallback is applied.
    uint256 private _paymentLaneRatio;

    // BEP-703 section 3.6.2. Starts empty: the fork lists nothing.
    EnumerableSet.AddressSet private _paymentContracts;

    /*----------------- events -----------------*/
    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);

    /*----------------- system functions -----------------*/
    /**
     * @dev BEP-703 section 3.6.5's single entry point, with all three of its keys:
     *      `paymentLaneRatio` takes `abi.encode(uint256)`, the two list keys take
     *      `abi.encodePacked(address)`.
     *
     *      A no-op is a revert here rather than a silent pass, so every accepted call is a real
     *      change: a ratio outside the guard, an address already listed, one that is not listed,
     *      and one that would carry the list past `MAX_PAYMENT_CONTRACTS`.
     *
     *      An accepted call lands in this block's post-state, and every consensus rule reads the
     *      parent's, so a change is invisible to its own block and governs from the next one on.
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("paymentLaneRatio")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newRatio = value.bytesToUint256(32);
            // The full uint256, never a narrowed copy: truncation can land a rejected value
            // inside the guard. 0 is excluded because it is the unwritten-slot marker.
            if (newRatio == 0 || newRatio > MAX_PAYMENT_LANE_RATIO) revert InvalidValue(key, value);
            _paymentLaneRatio = newRatio;
        } else if (key.compareStrings("addPaymentContract")) {
            address paymentContract = _decodeAddress(key, value);
            // The cap is checked after the add - the revert undoes it - so a duplicate on a full
            // list still reports the duplicate.
            if (!_paymentContracts.add(paymentContract)) revert PaymentContractAlreadyExists();
            if (_paymentContracts.length() > MAX_PAYMENT_CONTRACTS) revert PaymentContractLimitExceeded();
            emit PaymentContractAdded(paymentContract);
        } else if (key.compareStrings("removePaymentContract")) {
            address paymentContract = _decodeAddress(key, value);
            // Strips lane eligibility and nothing else: transactions to the address are ordinary
            // general transactions from the next block onward.
            if (!_paymentContracts.remove(paymentContract)) revert PaymentContractNotFound();
            emit PaymentContractRemoved(paymentContract);
        } else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @return the ratio of BEP-703 section 3.6.1, as governance set it or, if governance never
     *         has, its normative default.
     *
     * @dev Consensus getter, and the reason section 3.6.4 forbids reading the storage instead: a
     *      node decoding the slot would see 0 where everyone else sees the default, and derive a
     *      quota no one else derives. Keep its return width and semantics stable, and keep it a
     *      pure function of this contract's own storage.
     */
    function getPaymentLaneRatio() external view returns (uint256) {
        uint256 ratio = _paymentLaneRatio;
        return ratio == 0 ? DEFAULT_PAYMENT_LANE_RATIO : ratio;
    }

    /**
     * @dev Consensus getter: BEP-703 section 3.6.4 makes membership what this answers against the
     *      parent post-state, one test per destination. Keep it a pure function of this
     *      contract's own storage.
     */
    function isPaymentContract(
        address paymentContract
    ) external view returns (bool) {
        return _paymentContracts.contains(paymentContract);
    }

    /// @return results whether each address is listed, `results[i]` for `addrs[i]`
    function arePaymentContracts(
        address[] calldata addrs
    ) external view returns (bool[] memory results) {
        results = new bool[](addrs.length);
        for (uint256 i; i < addrs.length; ++i) {
            results[i] = _paymentContracts.contains(addrs[i]);
        }
    }

    function paymentContractCount() external view returns (uint256) {
        return _paymentContracts.length();
    }

    /**
     * @dev For inspection, and for a node that mirrors the list. Paginated because even a bounded
     *      list can be large, and every page carries the total so a walk can be checked against
     *      it. Order is not stable: removal swaps in the last element, so an index must never be
     *      carried across blocks, and a page walk that straddles a governance change can miss the
     *      swapped element.
     *
     *      Consensus getter. Keep it a pure function of this contract's own storage.
     *
     * @param limit the maximum number to return, or 0 for all remaining
     */
    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory paymentContracts, uint256 totalLength) {
        totalLength = _paymentContracts.length();
        if (offset >= totalLength) {
            return (paymentContracts, totalLength);
        }

        uint256 count = totalLength - offset;
        if (limit != 0 && limit < count) count = limit;
        paymentContracts = new address[](count);
        for (uint256 i; i < count; ++i) {
            paymentContracts[i] = _paymentContracts.at(offset + i);
        }
    }

    /*----------------- internal functions -----------------*/
    /**
     * @dev `abi.encodePacked(addr)`, not `abi.encode(addr)`: `Utils.bytesToAddress` mloads a
     *      word at `_input + _offset`, so the offset must equal the byte length or it silently
     *      returns a shifted address.
     */
    function _decodeAddress(string calldata key, bytes calldata value) internal pure returns (address) {
        if (value.length != 20) revert InvalidValue(key, value);
        return value.bytesToAddress(20);
    }
}
