// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./SystemV2.sol";
import "./lib/0.8.x/Utils.sol";

/**
 * @title PaymentLane
 * @notice Configuration for BEP-703: the eight governable parameters of section 3.6 and
 *         the payment contract list of section 3.7. Nothing else - the `paymentLaneSize`
 *         accumulator lives in the block header and the client. Do not mirror it here.
 *
 *         The lane is a per-block gas allowance only payment transactions may consume.
 *         Its size is an accumulator the client advances every block - it grows while the
 *         rest of the block is congested and shrinks when it is not - clamped between:
 *
 *             ceiling = min(paymentLaneMaxRatio * GasLimit / RATIO_DENOM, paymentLaneMax)
 *             floor   = min(max(paymentLaneMinRatio * GasLimit / RATIO_DENOM,
 *                               paymentLaneMin), ceiling)
 *             step    = expand/shrinkStepRatio * GasLimit / RATIO_DENOM, per block
 *
 *         Four parameters are shares of GasLimit over RATIO_DENOM and two are absolute
 *         gas. Each pair combines through a min(), which is why the absolute bounds can
 *         only shrink the lane and the ratio bounds are what cap its share of a block.
 *
 * @dev Parlia reads this contract once per block, against the parent block's post-state,
 *      through `getPaymentLaneParams()` and `arePaymentContracts(address[])`. Changing
 *      either signature or return encoding is a hard fork.
 *
 *      `GovHub` catches this contract's reverts and discards them, so a rejected change
 *      still reports success and a batched proposal can half-apply. State stays valid -
 *      every key reruns the full validator - but may not be what was voted on, so the
 *      latest `PaymentLaneParamsUpdated`, not the transaction receipt, is where the
 *      configuration actually landed.
 *
 *      `paymentLaneMax == 0` is the "not yet initialized" sentinel, which is why there is
 *      no enable flag. Validation keeps it unreachable once initialized.
 *
 *      No `receive()` and no `Protectable`: nothing holds value and the only mutating
 *      entry point is governance. Adding `Protectable` later would insert its storage
 *      ahead of the parameters and shift every slot.
 */
contract PaymentLane is SystemV2, Initializable {
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constants -----------------*/
    // BEP-703 section 3.6 protocol constants.
    uint256 public constant RATIO_DENOM = 10_000;
    uint256 public constant TRIGGER_GAP_MIN = 1_000;
    uint256 public constant RATIO_GAP_MIN = 500;

    // Absolute ceilings, NOT in BEP-703. Its six invariants constrain the parameters
    // against each other but say nothing about GasLimit or about the mandatory
    // end-of-block system transactions, so a tuple satisfying all six can still starve
    // general gas until no valid block exists. Ratio bounds close that because they are
    // scale invariant. Must stay `constant`: a ceiling governance can raise is not one.
    uint256 public constant MAX_LANE_RATIO = 2_000; // lane <= 20% of any GasLimit
    uint256 public constant MIN_EXPAND_TRIGGER_RATIO = 5_000; // expand only under real congestion
    uint256 public constant MIN_SHRINK_TRIGGER_RATIO = 2_000; // a zero trigger never fires, so the lane would ratchet
    // Must stay <= TRIGGER_GAP_MIN: raising it makes invariant (6) reachable, and (6) is
    // unreachable today so nothing tests it.
    uint256 public constant MAX_STEP_RATIO = 1_000;

    // The floor is the cheapest transaction's intrinsic gas, and it is what keeps the
    // `paymentLaneMax == 0` sentinel unreachable. The ceiling is only a fat-finger guard:
    // both absolute bounds enter section 3.4.4 through a min(), so they can only shrink.
    uint256 public constant MIN_LANE_GAS = 21_000;
    uint256 public constant MAX_LANE_GAS = 1_000_000_000;

    // Bounds governance-written state. Not a performance bound: lookup is O(1) at any size.
    uint256 public constant MAX_PAYMENT_CONTRACTS = 256;

    // A range, not a `code.length` test: precompiles have no code and any address can
    // gain code later. A rejecting precompile burns all the gas given to it, and listing
    // a system contract would reclassify Parlia's own system transactions.
    uint256 public constant MAX_RESERVED_ADDRESS = 0xFFFF;

    // Genesis seeds for the governable parameters below. BEP-703 section 3.6.
    uint256 private constant INIT_PAYMENT_LANE_MIN_RATIO = 200; // 2%
    uint256 private constant INIT_PAYMENT_LANE_MAX_RATIO = 800; // 8%
    uint256 private constant INIT_EXPAND_TRIGGER_RATIO = 8_000; // 80%
    uint256 private constant INIT_SHRINK_TRIGGER_RATIO = 7_000; // 70%
    uint256 private constant INIT_EXPAND_STEP_RATIO = 200; // 2%
    uint256 private constant INIT_SHRINK_STEP_RATIO = 50; // 0.5%
    uint256 private constant INIT_PAYMENT_LANE_MIN = 2_000_000; // gas
    uint256 private constant INIT_PAYMENT_LANE_MAX = 8_000_000; // gas

    /*----------------- errors -----------------*/
    // @notice signature: 0x6e45c90c
    error PaymentContractAlreadyExists();
    // @notice signature: 0x949d443a
    error PaymentContractNotFound();
    // @notice signature: 0x647ecf12
    error ExceedsMaxPaymentContracts();

    /*----------------- storage -----------------*/
    // At a fork the code is replaced in place and the storage survives, so inserting or
    // reordering a slot silently shifts everything after it - and a shifted
    // `paymentLaneMax` reads 0, which the client treats as "lane off", with `initialize()`
    // already consumed and no single governance key able to escape an all-zero tuple.
    // New state goes at the BOTTOM, never inside the two blocks below, whichever section
    // it belongs to. Deprecate with `// @dev deprecated`, never delete.

    // BEP-703 section 3.6
    uint256 public paymentLaneMinRatio;
    uint256 public paymentLaneMaxRatio;
    uint256 public expandTriggerRatio;
    uint256 public shrinkTriggerRatio;
    uint256 public expandStepRatio;
    uint256 public shrinkStepRatio;
    uint256 public paymentLaneMin; // gas, not a ratio
    uint256 public paymentLaneMax; // gas, not a ratio

    // BEP-703 section 3.7
    EnumerableSet.AddressSet private _paymentContracts;

    /*----------------- structs and events -----------------*/
    /**
     * @dev The eight parameters as one value. Returned by `getPaymentLaneParams()`, so
     *      this is consensus ABI surface: every field must stay a governable parameter.
     */
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

    /// @notice The complete configuration, not only the field that moved. The contract
    ///         header says why the whole tuple and not a delta.
    event PaymentLaneParamsUpdated(Params params);

    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);

    /*----------------- init -----------------*/
    /**
     * @dev this function is invoked by BSC Parlia consensus engine during the hard fork
     *
     * @notice Genesis bakes code and balance only, never storage, so the defaults are
     *         written here. Until this runs `paymentLaneMax` is 0 and the lane is off.
     *         The list is independent and may be seeded before this runs; the sentinel
     *         keeps the lane off either way and this function does not touch it.
     *
     *         `onlyCoinbase` authenticates the coinbase, not the engine, so the in-turn
     *         validator can also reach this. Harmless only while it takes no arguments:
     *         never add a `reinitializer` that does.
     */
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        Params memory p = Params({
            paymentLaneMinRatio: INIT_PAYMENT_LANE_MIN_RATIO,
            paymentLaneMaxRatio: INIT_PAYMENT_LANE_MAX_RATIO,
            expandTriggerRatio: INIT_EXPAND_TRIGGER_RATIO,
            shrinkTriggerRatio: INIT_SHRINK_TRIGGER_RATIO,
            expandStepRatio: INIT_EXPAND_STEP_RATIO,
            shrinkStepRatio: INIT_SHRINK_STEP_RATIO,
            paymentLaneMin: INIT_PAYMENT_LANE_MIN,
            paymentLaneMax: INIT_PAYMENT_LANE_MAX
        });

        // Same validator as governance, so a bad seed fails here and not on a live
        // network. Not dead code: the defaults already sit exactly on invariant (1).
        _validateParams(p, "initialize", "");
        _storeParams(p);
        emit PaymentLaneParamsUpdated(p);
    }

    /*----------------- system functions -----------------*/
    /**
     * @dev The list keys are handled inline; they share none of the numeric pipeline.
     *
     *        abi.encode(uint256), 32 bytes | paymentLaneMinRatio, paymentLaneMaxRatio,
     *                                        expandTriggerRatio, shrinkTriggerRatio,
     *                                        expandStepRatio, shrinkStepRatio,
     *                                        paymentLaneMin, paymentLaneMax
     *        abi.encodePacked(address), 20 | addPaymentContract, removePaymentContract
     *
     * @param key the key of the param
     * @param value the value of the param
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("addPaymentContract")) {
            address paymentContract = _decodeAddress(key, value);
            // Also covers address(0). Add-time only: removal needs nothing but membership,
            // so a listing stays removable even if this constant is later raised.
            if (uint160(paymentContract) <= MAX_RESERVED_ADDRESS) revert InvalidValue(key, value);
            // Revert rather than no-op, so the event is one-to-one with a real mutation.
            if (!_paymentContracts.add(paymentContract)) revert PaymentContractAlreadyExists();
            // After the add, so a duplicate on a full list still reports the duplicate.
            if (_paymentContracts.length() > MAX_PAYMENT_CONTRACTS) revert ExceedsMaxPaymentContracts();
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
     * @dev this function will be used by Parlia consensus engine.
     *
     * @return the eight parameters of BEP-703 section 3.6. `paymentLaneMax == 0` means
     *         this contract is not initialized yet and the lane MUST be treated as off.
     */
    function getPaymentLaneParams() external view returns (Params memory) {
        return _loadParams();
    }

    /**
     * @dev this function will be used by Parlia consensus engine.
     *
     * @param addrs the addresses to test
     *
     * @return results whether each address is listed, `results[i]` for `addrs[i]`
     */
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

    /**
     * @dev Order is not stable: removal swaps in the last element. Never persist an index.
     *
     * @param offset the offset of the query
     * @param limit the limit of the query, zero means all
     *
     * @return addrs the listed payment contracts
     * @return totalLength the total number of listed payment contracts
     */
    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory addrs, uint256 totalLength) {
        totalLength = _paymentContracts.length();
        if (offset >= totalLength) {
            return (addrs, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        addrs = new address[](count);
        for (uint256 i; i < count; ++i) {
            addrs[i] = _paymentContracts.at(offset + i);
        }
    }

    /*----------------- internal functions -----------------*/
    /**
     * @dev The eight uint256 parameters, and only those: a parameter of any other type
     *      needs its own branch in `updateParam`, or this 32-byte decode would misread it.
     *      The length guard runs before the dispatch, so an unknown key carrying a
     *      non-32-byte value reports `InvalidValue` rather than `UnknownParam`.
     *
     *      Every key reruns the whole validator against the full resulting tuple, both
     *      stages, not only the invariants naming that key - the six couple all eight
     *      parameters, so moving one can break three others. That is why the branches
     *      mutate a memory copy and nothing reaches storage until validation passes.
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

        _validateParams(p, key, value);
        _storeParams(p);
        emit PaymentLaneParamsUpdated(p);
    }

    /**
     * @dev `abi.encodePacked(addr)`, not `abi.encode(addr)`: `Utils.bytesToAddress` mloads
     *      a word at `_input + _offset`, so the offset must equal the byte length or it
     *      silently returns a shifted address.
     */
    function _decodeAddress(string calldata key, bytes calldata value) internal pure returns (address) {
        if (value.length != 20) revert InvalidValue(key, value);
        return value.bytesToAddress(20);
    }

    function _loadParams() internal view returns (Params memory p) {
        p.paymentLaneMinRatio = paymentLaneMinRatio;
        p.paymentLaneMaxRatio = paymentLaneMaxRatio;
        p.expandTriggerRatio = expandTriggerRatio;
        p.shrinkTriggerRatio = shrinkTriggerRatio;
        p.expandStepRatio = expandStepRatio;
        p.shrinkStepRatio = shrinkStepRatio;
        p.paymentLaneMin = paymentLaneMin;
        p.paymentLaneMax = paymentLaneMax;
    }

    /**
     * @dev All eight deliberately: seven are same-value writes to slots `_loadParams` just
     *      warmed, and they buy the rule that no dispatch branch ever touches storage.
     */
    function _storeParams(
        Params memory p
    ) internal {
        paymentLaneMinRatio = p.paymentLaneMinRatio;
        paymentLaneMaxRatio = p.paymentLaneMaxRatio;
        expandTriggerRatio = p.expandTriggerRatio;
        shrinkTriggerRatio = p.shrinkTriggerRatio;
        expandStepRatio = p.expandStepRatio;
        shrinkStepRatio = p.shrinkStepRatio;
        paymentLaneMin = p.paymentLaneMin;
        paymentLaneMax = p.paymentLaneMax;
    }

    /**
     * @dev Stage one bounds every field absolutely, which is what makes stage two's
     *      additions provably overflow-free. Do not reorder.
     *
     *      Every invariant is an addition, never the BEP's subtraction form: `maxRatio -
     *      minRatio >= RATIO_GAP_MIN` panics 0x11 instead of reverting `InvalidValue`
     *      whenever max < min, which is the case governance gets wrong.
     */
    function _validateParams(Params memory p, string memory key, bytes memory value) internal pure {
        // stage one
        if (p.paymentLaneMinRatio > MAX_LANE_RATIO) revert InvalidValue(key, value);
        if (p.paymentLaneMaxRatio < RATIO_GAP_MIN || p.paymentLaneMaxRatio > MAX_LANE_RATIO) {
            revert InvalidValue(key, value);
        }
        if (p.expandTriggerRatio < MIN_EXPAND_TRIGGER_RATIO || p.expandTriggerRatio > RATIO_DENOM) {
            revert InvalidValue(key, value);
        }
        if (p.shrinkTriggerRatio < MIN_SHRINK_TRIGGER_RATIO || p.shrinkTriggerRatio > RATIO_DENOM) {
            revert InvalidValue(key, value);
        }
        if (p.expandStepRatio == 0 || p.expandStepRatio > MAX_STEP_RATIO) revert InvalidValue(key, value);
        if (p.shrinkStepRatio == 0 || p.shrinkStepRatio > MAX_STEP_RATIO) revert InvalidValue(key, value);
        if (p.paymentLaneMin < MIN_LANE_GAS || p.paymentLaneMin > MAX_LANE_GAS) revert InvalidValue(key, value);
        if (p.paymentLaneMax < MIN_LANE_GAS || p.paymentLaneMax > MAX_LANE_GAS) revert InvalidValue(key, value);

        // stage two, BEP-703 section 3.6
        // (1) EXPAND_TRIGGER_RATIO - SHRINK_TRIGGER_RATIO >= TRIGGER_GAP_MIN
        if (p.expandTriggerRatio < p.shrinkTriggerRatio + TRIGGER_GAP_MIN) revert InvalidValue(key, value);
        // (2) EXPAND_STEP_RATIO > SHRINK_STEP_RATIO > 0, the lower half by stage one
        if (p.expandStepRatio <= p.shrinkStepRatio) revert InvalidValue(key, value);
        // (3) PAYMENT_LANE_MAX_RATIO - PAYMENT_LANE_MIN_RATIO >= RATIO_GAP_MIN
        if (p.paymentLaneMaxRatio < p.paymentLaneMinRatio + RATIO_GAP_MIN) revert InvalidValue(key, value);
        // (4) PAYMENT_LANE_MAX > PAYMENT_LANE_MIN > 0, the lower half by stage one
        if (p.paymentLaneMax <= p.paymentLaneMin) revert InvalidValue(key, value);
        // (5) PAYMENT_LANE_MAX_RATIO <= RATIO_DENOM - EXPAND_TRIGGER_RATIO. Reserved gas
        //     never competes, so the congestion signal can only come from the rest of the
        //     block: a ceiling above that point is one the lane could never grow into.
        if (p.paymentLaneMaxRatio + p.expandTriggerRatio > RATIO_DENOM) revert InvalidValue(key, value);
        // (6) EXPAND_STEP_RATIO <= EXPAND_TRIGGER_RATIO - SHRINK_TRIGGER_RATIO. Unreachable
        //     while MAX_STEP_RATIO == TRIGGER_GAP_MIN, since (1) already gives that gap.
        //     Kept so the code mirrors the spec and stays correct if MAX_STEP_RATIO rises.
        if (p.expandStepRatio + p.shrinkTriggerRatio > p.expandTriggerRatio) revert InvalidValue(key, value);
    }
}
