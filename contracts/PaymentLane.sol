// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./SystemV2.sol";
import "./interface/0.8.x/IPaymentLaneMeta.sol";
import "./lib/0.8.x/Utils.sol";

/**
 * @title PaymentLane
 * @notice Configuration for BEP-703: the eight governable parameters of section 3.6.1 and the
 *         payment contract list of section 3.6.3. Section 3.6.4 specifies this contract itself.
 *
 * @dev The BSC client reads this contract once per block, against the parent block's post-state,
 *      through IPaymentLaneMeta. Those reads are cached by this account's `(codeHash,
 *      storageRoot)`, so the consensus getters MUST stay a function of this contract's own
 *      storage only: no block/msg/tx environment reads, no blockhash, and no external calls.
 *
 *      Upgrades must preserve the getter semantics the client depends on: the eight-word tuple of
 *      `getPaymentLaneParams()` and the pagination semantics of `getPaymentContracts()`.
 *
 *      There is no `initialize()`, per section 3.6.4: an unwritten slot reads as its `DEFAULT_*`
 *      constant, so all-zero storage already IS the shipped configuration and the fork only has
 *      to set the code. New storage must be appended, never inserted or reordered.
 */
contract PaymentLane is SystemV2, IPaymentLaneMeta {
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constants -----------------*/
    // BEP-703 section 3.6.1 protocol constants. Its fourth, SYSTEM_TXS_GAS_RESERVE, is
    // deliberately not mirrored here: it belongs to the client's section 3.4.4 `laneCap`, which no
    // parameter update is validated against.
    uint256 public constant RATIO_DENOM = 10_000;
    uint256 public constant TRIGGER_GAP_MIN = 1_000;
    uint256 public constant RATIO_GAP_MIN = 500;

    // BEP-703 section 3.6.2's range guards, which bound each parameter on its own. The six
    // invariants alongside them constrain the parameters only against each other and say nothing
    // about GasLimit or the mandatory end-of-block system transactions, so a tuple satisfying all
    // six can still starve general gas until no valid block exists. Ratio bounds close that, being
    // scale invariant. Must stay `constant`: a ceiling governance can raise is not one.
    uint256 public constant MAX_LANE_RATIO = 2_000; // lane <= 20% of any GasLimit
    uint256 public constant MIN_EXPAND_TRIGGER_RATIO = 5_000; // expand only under real congestion
    uint256 public constant MIN_SHRINK_TRIGGER_RATIO = 2_000; // a zero trigger never fires, so the lane would ratchet
    // Must stay <= TRIGGER_GAP_MIN: raising it makes invariant (6) reachable, and (6) is
    // unreachable today so nothing tests it.
    uint256 public constant MAX_STEP_RATIO = 1_000;

    // The floor is the cheapest transaction's intrinsic gas: below it the lane holds nothing. The
    // ceiling is only a fat-finger guard. Neither can widen the lane past the ratio bound above:
    // PAYMENT_LANE_MIN does enter section 3.4.4 through a max(), and so can raise the floor above
    // the ratio, but that max() sits inside a min() against laneMax - the floor is clamped to a
    // ceiling the ratio already bounds.
    uint256 public constant MIN_LANE_GAS = 21_000;
    uint256 public constant MAX_LANE_GAS = 1_000_000_000;

    // BEP-703 section 3.6.3: classification reads the whole list against each parent post-state,
    // so this bound is here to keep that read finite, not to ration listings.
    uint256 public constant MAX_PAYMENT_CONTRACTS = 100_000;

    // The value an unwritten slot reads as. BEP-703 section 3.6.1 normative values.
    uint256 private constant DEFAULT_PAYMENT_LANE_MIN_RATIO = 200; // 2%
    uint256 private constant DEFAULT_PAYMENT_LANE_MAX_RATIO = 800; // 8%
    uint256 private constant DEFAULT_EXPAND_TRIGGER_RATIO = 8_000; // 80%
    uint256 private constant DEFAULT_SHRINK_TRIGGER_RATIO = 7_000; // 70%
    uint256 private constant DEFAULT_EXPAND_STEP_RATIO = 200; // 2%
    uint256 private constant DEFAULT_SHRINK_STEP_RATIO = 50; // 0.5%
    uint256 private constant DEFAULT_PAYMENT_LANE_MIN = 2_000_000; // gas
    uint256 private constant DEFAULT_PAYMENT_LANE_MAX = 8_000_000; // gas

    /*----------------- errors -----------------*/
    // @notice signature: 0x6e45c90c
    error PaymentContractAlreadyExists();
    // @notice signature: 0x949d443a
    error PaymentContractNotFound();
    // @notice signature: 0xb3a28ad3
    error PaymentContractLimitExceeded();

    /*----------------- storage -----------------*/
    // Append new state at the bottom; do not insert or reorder. The slots stay private so
    // callers always read through getPaymentLaneParams(), the one place the DEFAULT_* fallback
    // is applied.
    uint256 private _paymentLaneMinRatio;
    uint256 private _paymentLaneMaxRatio;
    uint256 private _expandTriggerRatio;
    uint256 private _shrinkTriggerRatio;
    uint256 private _expandStepRatio;
    uint256 private _shrinkStepRatio;
    uint256 private _paymentLaneMin; // gas, not a ratio
    uint256 private _paymentLaneMax; // gas, not a ratio

    // BEP-703 section 3.6.3
    EnumerableSet.AddressSet private _paymentContracts;

    /*----------------- structs and events -----------------*/
    /// @dev The full tuple after every numeric update. Seed indexers from
    ///      `getPaymentLaneParams()` instead: the fork itself emits no event.
    event PaymentLaneParamsUpdated(Params params);

    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);

    /*----------------- system functions -----------------*/
    /// @dev Numeric keys take `abi.encode(uint256)`; list keys take `abi.encodePacked(address)`.
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("addPaymentContract")) {
            address paymentContract = _decodeAddress(key, value);
            // Revert rather than no-op, so the event is one-to-one with a real mutation. The cap
            // is checked after the add - the revert undoes it - so a duplicate on a full list
            // still reports the duplicate.
            if (!_paymentContracts.add(paymentContract)) revert PaymentContractAlreadyExists();
            if (_paymentContracts.length() > MAX_PAYMENT_CONTRACTS) revert PaymentContractLimitExceeded();
            emit PaymentContractAdded(paymentContract);
        } else if (key.compareStrings("removePaymentContract")) {
            address paymentContract = _decodeAddress(key, value);
            if (!_paymentContracts.remove(paymentContract)) revert PaymentContractNotFound();
            emit PaymentContractRemoved(paymentContract);
        } else {
            _updateNumericParam(key, value);
        }
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @return the eight parameters of BEP-703 section 3.6.1, each either as governance set it or,
     *         if governance never has, as its `DEFAULT_*` constant.
     *
     * @dev Consensus getter. Keep its return shape and semantics stable, and keep it a pure
     *      function of this contract's own storage.
     */
    function getPaymentLaneParams() external view returns (Params memory) {
        return _loadParams();
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

    function isPaymentContract(
        address paymentContract
    ) external view returns (bool) {
        return _paymentContracts.contains(paymentContract);
    }

    function paymentContractCount() external view returns (uint256) {
        return _paymentContracts.length();
    }

    /**
     * @dev Paginated because even a bounded list can be large. Order is not stable: removal
     *      swaps in the last element, so never persist an index, and a page walk that straddles
     *      a governance change can miss the swapped element.
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
     * @dev The eight uint256 parameters, and only those: a parameter of any other type needs
     *      its own branch in `updateParam`, or this 32-byte decode would misread it. The length
     *      guard runs before the dispatch, so an unknown key carrying a non-32-byte value
     *      reports `InvalidValue` rather than `UnknownParam`.
     *
     *      Every key revalidates the whole resulting tuple - the six invariants couple all eight
     *      parameters, so moving one can break three others. Hence the memory copy: no dispatch
     *      branch reaches storage until validation passes.
     */
    function _updateNumericParam(string calldata key, bytes calldata value) internal {
        if (value.length != 32) revert InvalidValue(key, value);
        uint256 newValue = value.bytesToUint256(32);
        Params memory p = _loadParams();

        if (key.compareStrings("paymentLaneMinRatio")) p.paymentLaneMinRatio = newValue;
        else if (key.compareStrings("paymentLaneMaxRatio")) p.paymentLaneMaxRatio = newValue;
        else if (key.compareStrings("expandTriggerRatio")) p.expandTriggerRatio = newValue;
        else if (key.compareStrings("shrinkTriggerRatio")) p.shrinkTriggerRatio = newValue;
        else if (key.compareStrings("expandStepRatio")) p.expandStepRatio = newValue;
        else if (key.compareStrings("shrinkStepRatio")) p.shrinkStepRatio = newValue;
        else if (key.compareStrings("paymentLaneMin")) p.paymentLaneMin = newValue;
        else if (key.compareStrings("paymentLaneMax")) p.paymentLaneMax = newValue;
        else revert UnknownParam(key, value);

        if (!_isValid(p)) revert InvalidValue(key, value);
        _storeParams(p);
        emit PaymentLaneParamsUpdated(p);
    }

    /**
     * @dev `abi.encodePacked(addr)`, not `abi.encode(addr)`: `Utils.bytesToAddress` mloads a
     *      word at `_input + _offset`, so the offset must equal the byte length or it silently
     *      returns a shifted address.
     */
    function _decodeAddress(string calldata key, bytes calldata value) internal pure returns (address) {
        if (value.length != 20) revert InvalidValue(key, value);
        return value.bytesToAddress(20);
    }

    /**
     * @dev 0 is not a settable value for any of the eight, so an unwritten slot is unambiguous.
     *      The first accepted `updateParam` writes all eight, after which the fallback is inert.
     */
    function _loadParams() internal view returns (Params memory p) {
        p.paymentLaneMinRatio = _orDefault(_paymentLaneMinRatio, DEFAULT_PAYMENT_LANE_MIN_RATIO);
        p.paymentLaneMaxRatio = _orDefault(_paymentLaneMaxRatio, DEFAULT_PAYMENT_LANE_MAX_RATIO);
        p.expandTriggerRatio = _orDefault(_expandTriggerRatio, DEFAULT_EXPAND_TRIGGER_RATIO);
        p.shrinkTriggerRatio = _orDefault(_shrinkTriggerRatio, DEFAULT_SHRINK_TRIGGER_RATIO);
        p.expandStepRatio = _orDefault(_expandStepRatio, DEFAULT_EXPAND_STEP_RATIO);
        p.shrinkStepRatio = _orDefault(_shrinkStepRatio, DEFAULT_SHRINK_STEP_RATIO);
        p.paymentLaneMin = _orDefault(_paymentLaneMin, DEFAULT_PAYMENT_LANE_MIN);
        p.paymentLaneMax = _orDefault(_paymentLaneMax, DEFAULT_PAYMENT_LANE_MAX);
    }

    function _orDefault(uint256 stored, uint256 fallbackValue) internal pure returns (uint256) {
        return stored == 0 ? fallbackValue : stored;
    }

    /// @dev All eight deliberately: seven are same-value writes to slots `_loadParams` just
    ///      warmed, and they buy the rule that no dispatch branch ever touches storage.
    function _storeParams(
        Params memory p
    ) internal {
        _paymentLaneMinRatio = p.paymentLaneMinRatio;
        _paymentLaneMaxRatio = p.paymentLaneMaxRatio;
        _expandTriggerRatio = p.expandTriggerRatio;
        _shrinkTriggerRatio = p.shrinkTriggerRatio;
        _expandStepRatio = p.expandStepRatio;
        _shrinkStepRatio = p.shrinkStepRatio;
        _paymentLaneMin = p.paymentLaneMin;
        _paymentLaneMax = p.paymentLaneMax;
    }

    /**
     * @dev Stage one bounds every field from above, which is what makes stage two's additions
     *      provably overflow-free. Do not reorder.
     *
     *      Every invariant is an addition, never the BEP's subtraction form: `maxRatio -
     *      minRatio >= RATIO_GAP_MIN` panics 0x11 instead of reverting `InvalidValue` whenever
     *      max < min, which is the case governance gets wrong.
     */
    function _isValid(
        Params memory p
    ) internal pure returns (bool) {
        // stage one
        if (p.paymentLaneMinRatio == 0 || p.paymentLaneMinRatio > MAX_LANE_RATIO) return false;
        // No lower bound here: (3) plus minRatio >= 1 already gives maxRatio > RATIO_GAP_MIN.
        if (p.paymentLaneMaxRatio > MAX_LANE_RATIO) return false;
        if (p.expandTriggerRatio < MIN_EXPAND_TRIGGER_RATIO || p.expandTriggerRatio > RATIO_DENOM) return false;
        if (p.shrinkTriggerRatio < MIN_SHRINK_TRIGGER_RATIO || p.shrinkTriggerRatio > RATIO_DENOM) return false;
        if (p.expandStepRatio == 0 || p.expandStepRatio > MAX_STEP_RATIO) return false;
        if (p.shrinkStepRatio == 0 || p.shrinkStepRatio > MAX_STEP_RATIO) return false;
        if (p.paymentLaneMin < MIN_LANE_GAS || p.paymentLaneMin > MAX_LANE_GAS) return false;
        if (p.paymentLaneMax < MIN_LANE_GAS || p.paymentLaneMax > MAX_LANE_GAS) return false;

        // stage two, BEP-703 section 3.6.2
        // (1) EXPAND_TRIGGER_RATIO - SHRINK_TRIGGER_RATIO >= TRIGGER_GAP_MIN
        if (p.expandTriggerRatio < p.shrinkTriggerRatio + TRIGGER_GAP_MIN) return false;
        // (2) EXPAND_STEP_RATIO > SHRINK_STEP_RATIO > 0, the lower half by stage one
        if (p.expandStepRatio <= p.shrinkStepRatio) return false;
        // (3) PAYMENT_LANE_MAX_RATIO - PAYMENT_LANE_MIN_RATIO >= RATIO_GAP_MIN
        if (p.paymentLaneMaxRatio < p.paymentLaneMinRatio + RATIO_GAP_MIN) return false;
        // (4) PAYMENT_LANE_MAX > PAYMENT_LANE_MIN > 0, the lower half by stage one
        if (p.paymentLaneMax <= p.paymentLaneMin) return false;
        // (5) PAYMENT_LANE_MAX_RATIO <= RATIO_DENOM - EXPAND_TRIGGER_RATIO. Reserved gas never
        //     competes, so a ceiling above that point is one the lane could never grow into.
        if (p.paymentLaneMaxRatio + p.expandTriggerRatio > RATIO_DENOM) return false;
        // (6) EXPAND_STEP_RATIO <= EXPAND_TRIGGER_RATIO - SHRINK_TRIGGER_RATIO. Unreachable while
        //     MAX_STEP_RATIO == TRIGGER_GAP_MIN, since (1) already gives that gap. Kept so the
        //     code mirrors the spec and stays correct if MAX_STEP_RATIO rises.
        if (p.expandStepRatio + p.shrinkTriggerRatio > p.expandTriggerRatio) return false;

        return true;
    }
}
