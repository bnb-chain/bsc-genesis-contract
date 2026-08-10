// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
 * @dev The client reads this contract once per block, against the parent block's
 *      post-state, by reading STORAGE SLOTS DIRECTLY - not through the getters. It cannot
 *      call into the EVM at all; `core/paymentlane/config.go` says why, and why direct
 *      reads are the only form with no node-local input, so two honest nodes cannot
 *      disagree.
 *
 *      THEREFORE THE CONSENSUS SURFACE OF THIS CONTRACT IS ITS STORAGE LAYOUT, NOT ITS
 *      ABI. Slots 0..7 are the eight parameters in declaration order; the payment-contract
 *      set takes two, slot 8 the array's length with element `i` at
 *      `keccak256(bytes32(8)) + i`, slot 9 the membership mapping. The storage section
 *      below says what that forbids. The getters are for RPC, indexers and tests;
 *      changing their signatures is safe.
 *
 *      The list has no size limit, and a client MUST NOT carry one either - not even a
 *      generous one. A bound the contract does not enforce becomes a permanent chain halt
 *      the moment governance crosses it, because the read is a pure function of the parent
 *      state and the block that crossed it can never be produced again. Against a shifted
 *      storage layout a client wants shape rather than magnitude: this is an EnumerableSet,
 *      so a repeated element proves the read is not looking at this array, which stops a
 *      garbage length after one element (geth: `core/paymentlane/config.go`).
 *
 *      Nor does the list filter by address: any 20-byte value can be listed, including
 *      zero, a precompile or a system contract. Listing is governance-only and every
 *      listing is reversible by the same vote, so the contract does not second-guess the
 *      address - and neither does the reference client, whose classifier applies no
 *      address filter above its whitelist lookup. Membership means payment class, whatever
 *      the address. A client that reintroduced a filter would silently ignore listings this
 *      contract accepted, with the event emitted and nothing anywhere to show governance
 *      that its vote did nothing.
 *
 *      The client-side formula. BEP-703 section 3.4 pins the arithmetic - multiply before
 *      dividing, truncate toward zero - and this is that rule written out per term:
 *
 *          stepGas = floor(step * GasLimit(n) / RATIO_DENOM)
 *          ceiling = min(floor(paymentLaneMaxRatio * GasLimit(n) / RATIO_DENOM), paymentLaneMax)
 *          floor   = min(max(floor(paymentLaneMinRatio * GasLimit(n) / RATIO_DENOM),
 *                            paymentLaneMin), ceiling)
 *
 *      `GasLimit(n)` is THIS block's for all three; the congestion signal's denominator is
 *      the PARENT's, because it must match the numerator's block. Divide-first differs by
 *      up to `ratio - 1` gas and agrees whenever GasLimit is a multiple of RATIO_DENOM -
 *      i.e. in the steady state - so getting it wrong stays invisible until an operator
 *      changes the gas limit, and then never reproduces.
 *
 *      `getPaymentLaneParams()` MUST NOT revert, and today cannot: `_loadParams` has no
 *      revert path and makes no external call. That is a contract-level guarantee the
 *      client depends on, because it lets the client treat EVERY read failure as
 *      infrastructure and retry. Were the getter able to revert, the client would need a
 *      deterministic-failure branch that must not fall back to a default - and a
 *      must-not-fall-back branch on a consensus path is the bug that discipline loses to.
 *
 *      `GovHub` catches this contract's reverts and discards them, so a rejected change
 *      still reports success and a batched proposal can half-apply. State stays valid -
 *      every key reruns the full validator - but may not be what was voted on, so the
 *      latest `PaymentLaneParamsUpdated`, not the transaction receipt, is where the
 *      configuration actually landed.
 *
 *      There is no `initialize()`: an unwritten slot reads as its `DEFAULT_*` constant,
 *      so all-zero storage already IS the shipped configuration and the fork only has to
 *      set the code. The price is that 0 is no longer settable - already true for seven
 *      of the eight, and for `paymentLaneMinRatio` the floor moves 0 to 1, which
 *      `paymentLaneMin` masks until GasLimit passes 210M. It also makes `DEFAULT_*` a live
 *      fallback rather than a genesis seed: changing one at a later fork changes every
 *      parameter governance has never written.
 *
 *      No `receive()` and no `Protectable`: nothing holds value and the only mutating
 *      entry point is governance. Adding `Protectable` later would insert its storage
 *      ahead of the parameters and shift every slot.
 */
contract PaymentLane is SystemV2 {
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

    // The floor is the cheapest transaction's intrinsic gas: below it the lane holds
    // nothing. The ceiling is only a fat-finger guard - both absolute bounds enter section
    // 3.4.4 through a min(), so they can only shrink the lane, never grow it.
    uint256 public constant MIN_LANE_GAS = 21_000;
    uint256 public constant MAX_LANE_GAS = 1_000_000_000;

    // The value an unwritten slot reads as. BEP-703 section 3.6 suggested values.
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

    /*----------------- storage -----------------*/
    // At a fork the code is replaced in place and the storage survives, so inserting or
    // reordering a slot silently shifts everything after it, and every parameter then
    // reads either a neighbour's value or its own default with no error anywhere.
    // New state goes at the BOTTOM, never inside the two blocks below, whichever section
    // it belongs to. Deprecate with `// @dev deprecated`, never delete.
    //
    // Slot 0 is the first parameter: there is no Initializable and nothing precedes it.

    // BEP-703 section 3.6. Private on purpose: an auto-getter would return the raw slot,
    // so a fresh contract would answer 0 here and DEFAULT_* through getPaymentLaneParams().
    // One read path, one answer.
    uint256 private _paymentLaneMinRatio;
    uint256 private _paymentLaneMaxRatio;
    uint256 private _expandTriggerRatio;
    uint256 private _shrinkTriggerRatio;
    uint256 private _expandStepRatio;
    uint256 private _shrinkStepRatio;
    uint256 private _paymentLaneMin; // gas, not a ratio
    uint256 private _paymentLaneMax; // gas, not a ratio

    // BEP-703 section 3.7
    EnumerableSet.AddressSet private _paymentContracts;

    /*----------------- structs and events -----------------*/
    /**
     * @dev The eight parameters as one value, returned by `getPaymentLaneParams()` and
     *      carried by `PaymentLaneParamsUpdated`. Consensus ABI surface on both counts:
     *      every field must stay a governable parameter, and adding one is a hard fork.
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

    /**
     * @notice The complete configuration, not only the field that moved. The contract
     *         header says why the whole tuple and not a delta.
     *
     * @dev Not emitted at the fork: with no initializer there is no transaction to emit
     *      from, so an indexer starting from logs alone has no parameters until the first
     *      governance change. Read `getPaymentLaneParams()` once to seed, then follow this.
     */
    event PaymentLaneParamsUpdated(Params params);

    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);

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
            // Revert rather than no-op, so the event is one-to-one with a real mutation.
            if (!_paymentContracts.add(paymentContract)) revert PaymentContractAlreadyExists();
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
     * @return the eight parameters of BEP-703 section 3.6, each either as governance set
     *         it or, if governance never has, as its `DEFAULT_*` constant.
     */
    function getPaymentLaneParams() external view returns (Params memory) {
        return _loadParams();
    }

    /**
     * @dev The loop is sized by the caller, not by the list.
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
     * @dev Paginated because nothing bounds the list. Order is not stable: removal swaps in
     *      the last element, so never persist an index, and a page walk that straddles a
     *      governance change can miss the swapped element.
     *
     * @param offset the index to start from
     * @param limit the maximum number to return, or 0 for all remaining
     *
     * @return paymentContracts the requested page
     * @return totalLength the full list length
     */
    function getPaymentContracts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory paymentContracts, uint256 totalLength) {
        totalLength = _paymentContracts.length();
        if (offset >= totalLength) {
            return (paymentContracts, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        paymentContracts = new address[](count);
        for (uint256 i; i < count; ++i) {
            paymentContracts[i] = _paymentContracts.at(offset + i);
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

    /**
     * @dev The one place the fallback is applied. 0 is not a settable value for any of the
     *      eight, so an unwritten slot is unambiguous. The first accepted `updateParam`
     *      writes all eight, after which the fallback is inert.
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

    /**
     * @dev All eight deliberately: seven are same-value writes to slots `_loadParams` just
     *      warmed, and they buy the rule that no dispatch branch ever touches storage.
     */
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
     * @dev Stage one bounds every field absolutely, which is what makes stage two's
     *      additions provably overflow-free. Do not reorder.
     *
     *      Every invariant is an addition, never the BEP's subtraction form: `maxRatio -
     *      minRatio >= RATIO_GAP_MIN` panics 0x11 instead of reverting `InvalidValue`
     *      whenever max < min, which is the case governance gets wrong.
     */
    function _validateParams(Params memory p, string memory key, bytes memory value) internal pure {
        // stage one
        if (p.paymentLaneMinRatio == 0 || p.paymentLaneMinRatio > MAX_LANE_RATIO) {
            revert InvalidValue(key, value);
        }
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
