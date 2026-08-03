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
 * @dev Parlia reads this contract once per block, before transaction execution, against
 *      the parent block's post-state, through `getPaymentLaneParams()` and
 *      `arePaymentContracts(address[])`. Changing either signature or return encoding is
 *      a hard fork. The client reads through the ABI, not raw slots, so the storage
 *      layout is free with respect to consensus - but not with respect to upgrades, see
 *      the storage section.
 *
 *      `paymentLaneMax == 0` is the "not yet initialized" sentinel, which is why there is
 *      no enable flag. Validation makes it unreachable once initialized; never let 0
 *      become an accepted value.
 *
 *      No `receive()` and no `Protectable`, deliberately: this contract never holds value
 *      and its only mutating entry point is governance, so there is nothing for a pause
 *      switch to protect. Adding `Protectable` later would also insert its storage ahead
 *      of the parameters and shift every slot.
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

    // Absolute governance ceilings. NOT in BEP-703 - they close a gap in it. The six
    // invariants are closed over the parameters but say nothing about GasLimit or about
    // the mandatory end-of-block system transactions, neither of which Solidity can see.
    // A tuple satisfying all six can still pin the lane at 90% of the block and leave
    // less general gas than those transactions need, at which point no valid block exists
    // at that height. A ratio bound closes this because it is scale invariant.
    //
    // These must stay `constant`. A ceiling governance can raise is not a ceiling.
    uint256 public constant MAX_LANE_RATIO = 2_000; // lane <= 20% of any GasLimit
    uint256 public constant MIN_EXPAND_TRIGGER_RATIO = 5_000; // expand only under real congestion
    uint256 public constant MIN_SHRINK_TRIGGER_RATIO = 2_000; // a zero trigger never fires, so the lane would ratchet
    uint256 public constant MAX_STEP_RATIO = 1_000;

    // A lane below the cheapest transaction's intrinsic gas holds nothing, and this floor
    // is what makes the `paymentLaneMax == 0` sentinel unreachable. The ceiling is only a
    // fat-finger guard: both absolute bounds enter section 3.4.4 through a min() and can
    // only shrink the lane, so the ratio bounds above are what carry the safety property.
    uint256 public constant MIN_LANE_GAS = 21_000;
    uint256 public constant MAX_LANE_GAS = 1_000_000_000;

    // Governance-written state with no automatic pruning, so cap it. Not a performance
    // bound - membership lookup is O(1) at any size.
    uint256 public constant MAX_PAYMENT_CONTRACTS = 256;

    // Blocks a range rather than testing `code.length`, because precompiles have no code
    // and any address can gain code later. A rejecting precompile burns all the gas it is
    // given (BEP-703 section 3.2 excludes them from category 1 for that reason), and
    // listing a system contract would reclassify Parlia's own system transactions, which
    // the BEP does not define.
    uint256 public constant MAX_RESERVED_ADDRESS = 0xFFFF;

    // Genesis seeds for the governable parameters below. BEP-703 section 3.6.
    uint256 private constant INIT_PAYMENT_LANE_MIN_RATIO = 200; // 2%
    uint256 private constant INIT_PAYMENT_LANE_MAX_RATIO = 800; // 8%
    uint256 private constant INIT_EXPAND_TRIGGER_RATIO = 8_000; // 80%
    uint256 private constant INIT_SHRINK_TRIGGER_RATIO = 7_000; // 70%
    uint256 private constant INIT_EXPAND_STEP_RATIO = 200; // 2%
    uint256 private constant INIT_SHRINK_STEP_RATIO = 50; // 0.5%
    uint256 private constant INIT_PAYMENT_LANE_MIN = 2_000_000;
    uint256 private constant INIT_PAYMENT_LANE_MAX = 8_000_000;

    /*----------------- errors -----------------*/
    // @notice signature: 0x6e45c90c
    error PaymentContractAlreadyExists();
    // @notice signature: 0x949d443a
    error PaymentContractNotFound();
    // @notice signature: 0x647ecf12
    error ExceedsMaxPaymentContracts();

    /*----------------- storage -----------------*/
    // Append only, never reorder: at a fork the code is replaced in place and the storage
    // survives. Deprecate with `// @dev deprecated`, never delete.

    // BEP-703 section 3.6
    uint256 public paymentLaneMinRatio;
    uint256 public paymentLaneMaxRatio;
    uint256 public expandTriggerRatio;
    uint256 public shrinkTriggerRatio;
    uint256 public expandStepRatio;
    uint256 public shrinkStepRatio;
    uint256 public paymentLaneMin;
    uint256 public paymentLaneMax;

    // BEP-703 section 3.7
    EnumerableSet.AddressSet private _paymentContracts;

    /*----------------- structs and events -----------------*/
    /**
     * @dev Memory-only view of the eight parameters. Not a storage struct.
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
     * @notice The complete configuration after `initialize()` and after every accepted
     *         parameter change, not only the field that moved.
     *
     * @dev `GovHub` wraps this contract's `updateParam` in a try/catch and discards the
     *      result, so a rejected change does not revert the governance execution and a
     *      batched proposal can half-apply while still reporting success. State stays
     *      valid - every key revalidates all six invariants - but may not be what was
     *      voted on, so the latest occurrence of this event is the authoritative
     *      snapshot. Operators should alert on GovHub's `failReasonWithBytes`.
     */
    event PaymentLaneParamsUpdated(
        uint256 paymentLaneMinRatio,
        uint256 paymentLaneMaxRatio,
        uint256 expandTriggerRatio,
        uint256 shrinkTriggerRatio,
        uint256 expandStepRatio,
        uint256 shrinkStepRatio,
        uint256 paymentLaneMin,
        uint256 paymentLaneMax
    );

    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);

    /*----------------- init -----------------*/
    /**
     * @dev this function is invoked by BSC Parlia consensus engine during the hard fork
     *
     * @notice Genesis bakes code and balance only, never storage, so the defaults have to
     *         be written here. Until this runs `paymentLaneMax` is 0 and the lane is off.
     *
     *         `onlyCoinbase` authenticates the coinbase, not the engine, so the in-turn
     *         validator can also reach this. Harmless only because it takes no arguments,
     *         is `initializer` guarded and writes constants. Never add a `reinitializer`
     *         that takes arguments.
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
        _emitParamsUpdated(p);
    }

    /*----------------- system functions -----------------*/
    /**
     * @param key the key of the param
     * @param value the value of the param
     *
     * @dev Every parameter key revalidates all six invariants of BEP-703 section 3.6
     *      against the full resulting tuple, not only the ones naming that key: the six
     *      couple all eight parameters, so moving one can break three others. Do not
     *      narrow a branch to "its own" invariant.
     *
     *      Unlike every other `updateParam` in this repo, the branches mutate a memory
     *      copy and validation runs on the whole tuple afterwards. A branch that writes
     *      storage directly would bypass it.
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("addPaymentContract")) {
            address paymentContract = _decodePaymentContract(key, value);
            // Revert rather than no-op, so the event is one-to-one with a real mutation.
            if (!_paymentContracts.add(paymentContract)) revert PaymentContractAlreadyExists();
            // After the add, so a duplicate on a full list still reports the duplicate.
            if (_paymentContracts.length() > MAX_PAYMENT_CONTRACTS) revert ExceedsMaxPaymentContracts();
            emit PaymentContractAdded(paymentContract);
        } else if (key.compareStrings("removePaymentContract")) {
            address paymentContract = _decodePaymentContract(key, value);
            if (!_paymentContracts.remove(paymentContract)) revert PaymentContractNotFound();
            emit PaymentContractRemoved(paymentContract);
        } else {
            Params memory p = _loadParams();

            if (key.compareStrings("paymentLaneMinRatio")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.paymentLaneMinRatio = value.bytesToUint256(32);
            } else if (key.compareStrings("paymentLaneMaxRatio")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.paymentLaneMaxRatio = value.bytesToUint256(32);
            } else if (key.compareStrings("expandTriggerRatio")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.expandTriggerRatio = value.bytesToUint256(32);
            } else if (key.compareStrings("shrinkTriggerRatio")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.shrinkTriggerRatio = value.bytesToUint256(32);
            } else if (key.compareStrings("expandStepRatio")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.expandStepRatio = value.bytesToUint256(32);
            } else if (key.compareStrings("shrinkStepRatio")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.shrinkStepRatio = value.bytesToUint256(32);
            } else if (key.compareStrings("paymentLaneMin")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.paymentLaneMin = value.bytesToUint256(32);
            } else if (key.compareStrings("paymentLaneMax")) {
                if (value.length != 32) revert InvalidValue(key, value);
                p.paymentLaneMax = value.bytesToUint256(32);
            } else {
                revert UnknownParam(key, value);
            }

            _validateParams(p, key, value);
            _storeParams(p);
            _emitParamsUpdated(p);
        }
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @dev this function will be used by Parlia consensus engine.
     *
     * @return minRatio ratio lower bound, over RATIO_DENOM
     * @return maxRatio ratio upper bound, over RATIO_DENOM
     * @return expandTrigger congestion threshold that triggers expansion
     * @return shrinkTrigger slack threshold that triggers contraction
     * @return expandStep per-block expansion step, over RATIO_DENOM
     * @return shrinkStep per-block contraction step, over RATIO_DENOM
     * @return laneMin absolute lower bound, in gas
     * @return laneMax absolute upper bound, in gas. Zero means not yet initialized and
     *         the lane MUST be treated as disabled.
     */
    function getPaymentLaneParams()
        external
        view
        returns (
            uint256 minRatio,
            uint256 maxRatio,
            uint256 expandTrigger,
            uint256 shrinkTrigger,
            uint256 expandStep,
            uint256 shrinkStep,
            uint256 laneMin,
            uint256 laneMax
        )
    {
        return (
            paymentLaneMinRatio,
            paymentLaneMaxRatio,
            expandTriggerRatio,
            shrinkTriggerRatio,
            expandStepRatio,
            shrinkStepRatio,
            paymentLaneMin,
            paymentLaneMax
        );
    }

    /**
     * @dev this function will be used by Parlia consensus engine.
     *
     * @notice Batch membership query. `results[i]` corresponds to `addrs[i]`.
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
     * @dev `abi.encodePacked(addr)`, not `abi.encode(addr)`: `Utils.bytesToAddress` mloads
     *      a word at `_input + _offset`, so the offset must equal the byte length or it
     *      silently returns a shifted address.
     */
    function _decodePaymentContract(
        string calldata key,
        bytes calldata value
    ) internal pure returns (address paymentContract) {
        if (value.length != 20) revert InvalidValue(key, value);
        paymentContract = value.bytesToAddress(20);
        // Also covers address(0).
        if (uint160(paymentContract) <= MAX_RESERVED_ADDRESS) revert InvalidValue(key, value);
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
     * @dev Writes all eight deliberately. Seven are same-value writes to slots
     *      `_loadParams` just warmed, and they buy the rule that no dispatch branch ever
     *      touches storage.
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

    function _emitParamsUpdated(
        Params memory p
    ) internal {
        emit PaymentLaneParamsUpdated(
            p.paymentLaneMinRatio,
            p.paymentLaneMaxRatio,
            p.expandTriggerRatio,
            p.shrinkTriggerRatio,
            p.expandStepRatio,
            p.shrinkStepRatio,
            p.paymentLaneMin,
            p.paymentLaneMax
        );
    }

    /**
     * @dev Stage one bounds every field absolutely; stage two checks the six invariants.
     *      The order is load bearing: stage one is what makes stage two's additions
     *      provably overflow-free.
     *
     *      Every invariant is written as an addition, never the BEP's subtraction form.
     *      `maxRatio - minRatio >= RATIO_GAP_MIN` panics 0x11 instead of reverting
     *      `InvalidValue` whenever max < min, which is the case governance gets wrong.
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
        // (5) PAYMENT_LANE_MAX_RATIO <= RATIO_DENOM - EXPAND_TRIGGER_RATIO
        if (p.paymentLaneMaxRatio + p.expandTriggerRatio > RATIO_DENOM) revert InvalidValue(key, value);
        // (6) EXPAND_STEP_RATIO <= EXPAND_TRIGGER_RATIO - SHRINK_TRIGGER_RATIO. Unreachable
        //     while MAX_STEP_RATIO == TRIGGER_GAP_MIN, since (1) already gives that gap.
        //     Kept so the code mirrors the spec and stays correct if MAX_STEP_RATIO rises.
        if (p.expandStepRatio + p.shrinkTriggerRatio > p.expandTriggerRatio) revert InvalidValue(key, value);
    }
}
