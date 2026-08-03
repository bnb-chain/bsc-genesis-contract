// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./SystemV2.sol";
import "./lib/0.8.x/Utils.sol";

/**
 * @title PaymentLane
 * @notice Configuration contract for BEP-703 (Payment Lane on BNB Smart Chain).
 *
 * It holds exactly two things:
 *   - the eight governable parameters of BEP-703 section 3.6;
 *   - the payment contract address list of BEP-703 section 3.7.
 *
 * It holds no lane state. The `paymentLaneSize` accumulator lives in the BSC client
 * and in the block header; the block validity rule of section 3.3 is enforced there.
 *
 * @dev The BSC Parlia consensus engine reads this contract once per block, before
 *      transaction execution, against the parent block's post-state, via
 *      `getPaymentLaneParams()` and `arePaymentContracts(address[])`. Those two
 *      function signatures and their return encodings are therefore consensus
 *      critical: changing either is a hard fork. The storage layout is NOT
 *      consensus critical, because the client reads through the ABI rather than
 *      through raw storage slots.
 *
 *      `paymentLaneMax == 0` is unreachable in any valid configuration (invariant
 *      (4) plus the MIN_LANE_GAS floor), so the client MUST treat it as the
 *      "not yet initialized" sentinel and disable the lane. That is the intended
 *      pre-activation behaviour and the reason no enable/disable flag exists.
 */
contract PaymentLane is SystemV2, Initializable {
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constants -----------------*/
    // BEP-703 section 3.6 protocol constants. Named after the BEP rather than this
    // repo's `*_SCALE` / `*_BASE` convention (BLOCK_FEES_RATIO_SCALE,
    // COMMISSION_RATE_BASE) so the identifiers match the specification formulas and
    // the client implementations verbatim. Governance can move the ranges but can
    // never collapse them.
    uint256 public constant RATIO_DENOM = 10000;
    uint256 public constant TRIGGER_GAP_MIN = 1000;
    uint256 public constant RATIO_GAP_MIN = 500;

    // Absolute governance ceilings. These are NOT in BEP-703 section 3.6; they close
    // a gap in it. The six invariants of section 3.6 are closed over the parameters
    // but open with respect to the environment: they say nothing about GasLimit, and
    // nothing about the mandatory end-of-block system transactions that a block
    // producer cannot decline and that count as general gas. A Solidity contract can
    // see neither. A parameter set satisfying all six invariants can therefore pin
    // paymentLaneSize at 90% of the block and leave less general gas than the system
    // transactions require, at which point no valid block exists at that height.
    //
    // Bounding the RATIO is what closes this, because a ratio bound is scale
    // invariant: MAX_LANE_RATIO guarantees general gas keeps at least 80% of every
    // block at any GasLimit. MIN_EXPAND_TRIGGER_RATIO is a second, independent lock:
    // via invariant (5) it forces paymentLaneMaxRatio <= 5000 on its own.
    //
    // These must stay `constant`. Governance able to raise its own ceiling is no
    // ceiling at all - the same reasoning that makes TRIGGER_GAP_MIN and
    // RATIO_GAP_MIN protocol constants in the BEP. Widening them is a hard fork.
    uint256 public constant MAX_LANE_RATIO = 2000; // 20% of any GasLimit
    uint256 public constant MIN_EXPAND_TRIGGER_RATIO = 5000; // the lane may only expand under real congestion
    uint256 public constant MIN_SHRINK_TRIGGER_RATIO = 2000; // a zero trigger can never fire, so the lane would ratchet
    uint256 public constant MAX_STEP_RATIO = 1000; // one step may not jump the whole range

    // A lane below the intrinsic gas of the cheapest possible transaction holds no
    // transactions at all. The ceiling is a fat-finger guard: it leaves ~18x headroom
    // over today's GasLimit while sitting nine orders of magnitude below a wei-scale
    // paste. The absolute bounds enter section 3.4.4 through a min(), so they can only
    // ever shrink the lane - the ratio bounds above are what carry the safety property.
    uint256 public constant MIN_LANE_GAS = 21_000;
    uint256 public constant MAX_LANE_GAS = 1_000_000_000;

    // System contract state is never pruned and there is no mechanism to reclaim it,
    // so the list needs an absolute ceiling. Membership lookup is O(1) regardless.
    uint256 public constant MAX_PAYMENT_CONTRACTS = 256;

    // Blocks every precompile and every BSC system contract (0x1000-0x3000) from the
    // list. BEP-703 section 3.2 excludes precompiles from category 1 because a
    // precompile that rejects its input consumes every unit of gas the call was given,
    // but section 3.7's list carries no such exclusion. Listing a system contract is
    // worse still: Parlia's own system transactions target system contracts, so
    // listing one would reclassify them, and the BEP never defines how system
    // transactions are classified.
    uint256 public constant MAX_RESERVED_ADDRESS = 0xFFFF;

    // Genesis values. `INIT_X` next to a governable `x` is this repo's marker for
    // "seed only, governance may retune". Values from BEP-703 section 3.6.
    uint256 public constant INIT_PAYMENT_LANE_MIN_RATIO = 200; // 2%
    uint256 public constant INIT_PAYMENT_LANE_MAX_RATIO = 800; // 8%
    uint256 public constant INIT_EXPAND_TRIGGER_RATIO = 8000; // 80%
    uint256 public constant INIT_SHRINK_TRIGGER_RATIO = 7000; // 70%
    uint256 public constant INIT_EXPAND_STEP_RATIO = 200; // 2%
    uint256 public constant INIT_SHRINK_STEP_RATIO = 50; // 0.5%
    uint256 public constant INIT_PAYMENT_LANE_MIN = 2_000_000;
    uint256 public constant INIT_PAYMENT_LANE_MAX = 8_000_000;

    /*----------------- errors -----------------*/
    // UnknownParam, InvalidValue, OnlyCoinbase, OnlyZeroGasPrice and
    // OnlySystemContract are inherited from SystemV2.
    // @notice signature: 0x6e45c90c
    error PaymentContractAlreadyExists();
    // @notice signature: 0x949d443a
    error PaymentContractNotFound();
    // @notice signature: 0x647ecf12
    error ExceedsMaxPaymentContracts();

    /*----------------- storage -----------------*/
    // Append only. Deprecate with `// @dev deprecated`, never delete.

    // BEP-703 section 3.6 governable parameters
    uint256 public paymentLaneMinRatio;
    uint256 public paymentLaneMaxRatio;
    uint256 public expandTriggerRatio;
    uint256 public shrinkTriggerRatio;
    uint256 public expandStepRatio;
    uint256 public shrinkStepRatio;
    uint256 public paymentLaneMin;
    uint256 public paymentLaneMax;

    // BEP-703 section 3.7 payment contract list
    EnumerableSet.AddressSet private _paymentContracts;

    /*----------------- structs and events -----------------*/
    /// @dev Memory-only view of the eight parameters. Not a storage struct.
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
     * @notice Emitted on every successful parameter change, carrying the COMPLETE
     *         resulting configuration rather than only the field that moved.
     *
     * @dev This is deliberate. `GovHub.notifyUpdates` wraps the call to this contract
     *      in a try/catch and discards the return code (contracts/GovHub.sol:48-55
     *      and :40), so a rejected parameter change does not revert the governance
     *      execution: the transaction still reports success and only a
     *      `failReasonWithBytes` log distinguishes it. A proposal that batches several
     *      parameter changes in the wrong order can therefore half-apply silently.
     *      Every single-key update revalidates all six invariants against the full
     *      resulting tuple, so the on-chain state is always valid - but it may not be
     *      the state that was voted on. Emitting the whole tuple makes the last
     *      occurrence of this event the authoritative final state, so reconciling a
     *      proposal against what actually landed is one log read rather than eight
     *      storage reads. Operators should also alert on GovHub's
     *      `failReasonWithStr` / `failReasonWithBytes`.
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
     * @notice Genesis bakes only code and balance for this address, never storage, so
     *         the defaults have to be written here. Until this runs, `paymentLaneMax`
     *         is zero and the client keeps the lane disabled.
     *
     *         `onlyCoinbase` authenticates the coinbase, not the consensus engine: the
     *         in-turn validator can also reach this from an ordinary zero-gas-price
     *         transaction. That is harmless because the function takes no arguments,
     *         is `initializer` guarded and writes constants. It stops being harmless
     *         the moment anyone adds a `reinitializer` that takes arguments.
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

        // Run the defaults through the same validator as governance, so a bad default
        // can never reach a live network.
        _validateParams(p, "initialize", "");
        _storeParams(p);
        _emitParamsUpdated(p);
    }

    /*----------------- system functions -----------------*/
    /**
     * @param key the key of the param
     * @param value the value of the param
     *
     * @dev Every parameter key revalidates ALL SIX invariants of BEP-703 section 3.6
     *      against the full resulting tuple, not just the pair it belongs to. StakeHub
     *      can get away with pairwise checks because its constraints form four
     *      independent pairs; BEP-703's six invariants connect all eight parameters
     *      into one graph, so moving any one of them can break three others.
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        // Load the current configuration into memory. Every check runs against this
        // copy and nothing is written until all of them pass, so no storage write can
        // precede validation.
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
        } else if (key.compareStrings("addPaymentContract")) {
            // 20 bytes, so the value must be abi.encodePacked(addr), not abi.encode(addr).
            // Utils.bytesToAddress reads a full word at `_input + _offset`, so the offset
            // argument has to equal the byte length or it silently returns a shifted address.
            if (value.length != 20) revert InvalidValue(key, value);
            address paymentContract = value.bytesToAddress(20);
            if (paymentContract == address(0)) revert InvalidValue(key, value);
            if (uint160(paymentContract) <= MAX_RESERVED_ADDRESS) revert InvalidValue(key, value);
            if (_paymentContracts.length() >= MAX_PAYMENT_CONTRACTS) revert ExceedsMaxPaymentContracts();
            // Reverting rather than being idempotent keeps PaymentContractAdded a
            // one-to-one signal of an actual mutation. This is the governance path, not
            // a consensus path, so a revert cannot brick a block: GovHub catches it.
            if (!_paymentContracts.add(paymentContract)) revert PaymentContractAlreadyExists();

            emit PaymentContractAdded(paymentContract);
            emit ParamChange(key, value);
            // The list is independent of the parameters: no invariant check, no
            // PaymentLaneParamsUpdated.
            return;
        } else if (key.compareStrings("removePaymentContract")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address paymentContract = value.bytesToAddress(20);
            if (!_paymentContracts.remove(paymentContract)) revert PaymentContractNotFound();

            emit PaymentContractRemoved(paymentContract);
            emit ParamChange(key, value);
            return;
        } else {
            revert UnknownParam(key, value);
        }

        _validateParams(p, key, value);
        _storeParams(p);
        _emitParamsUpdated(p);
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @dev this function will be used by BSC Parlia consensus engine.
     *
     * @notice Read once per block, against the parent block's post-state, to derive
     *         laneMin, laneMax and the step of BEP-703 section 3.4.
     *
     * @return _paymentLaneMinRatio ratio lower bound, over RATIO_DENOM
     * @return _paymentLaneMaxRatio ratio upper bound, over RATIO_DENOM
     * @return _expandTriggerRatio congestion threshold that triggers expansion
     * @return _shrinkTriggerRatio slack threshold that triggers contraction
     * @return _expandStepRatio per-block expansion step, over RATIO_DENOM
     * @return _shrinkStepRatio per-block contraction step, over RATIO_DENOM
     * @return _paymentLaneMin absolute lower bound, in gas
     * @return _paymentLaneMax absolute upper bound, in gas. Zero means this contract
     *         has not been initialized yet and the lane MUST be treated as disabled.
     */
    function getPaymentLaneParams()
        external
        view
        returns (
            uint256 _paymentLaneMinRatio,
            uint256 _paymentLaneMaxRatio,
            uint256 _expandTriggerRatio,
            uint256 _shrinkTriggerRatio,
            uint256 _expandStepRatio,
            uint256 _shrinkStepRatio,
            uint256 _paymentLaneMin,
            uint256 _paymentLaneMax
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
     * @dev this function will be used by BSC Parlia consensus engine.
     *
     * @notice Batch membership query, read once per block with every candidate `to`
     *         address of that block. `results[i]` corresponds to `addrs[i]`.
     *
     * @param addrs the addresses to test
     *
     * @return results whether each address is a listed payment contract
     */
    function arePaymentContracts(
        address[] calldata addrs
    ) external view returns (bool[] memory results) {
        results = new bool[](addrs.length);
        for (uint256 i; i < addrs.length; ++i) {
            results[i] = _paymentContracts.contains(addrs[i]);
        }
    }

    /**
     * @param paymentContract the address to test
     *
     * @return whether the address is a listed payment contract
     */
    function isPaymentContract(
        address paymentContract
    ) external view returns (bool) {
        return _paymentContracts.contains(paymentContract);
    }

    /**
     * @return the number of listed payment contracts
     */
    function paymentContractsLength() external view returns (uint256) {
        return _paymentContracts.length();
    }

    /**
     * @notice Paginated query of the payment contract list.
     *
     * @dev The order is NOT stable across mutations: removal swaps the last element
     *      into the freed position. Do not persist an index.
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

    /// @dev Writes all eight slots. Seven of them are same-value writes to warm slots
    ///      just read by _loadParams, ~100 gas each, in exchange for keeping every
    ///      storage write out of the dispatch branches.
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
     * @dev Two stages, and the order between them is load bearing.
     *
     *      Stage one pins every field into an absolute range. Stage two checks the six
     *      invariants of BEP-703 section 3.6 against the resulting tuple. Because
     *      stage one has already bounded every operand by RATIO_DENOM or MAX_LANE_GAS,
     *      the additions in stage two provably cannot overflow.
     *
     *      Every invariant is written as an addition. The natural subtraction form,
     *      `paymentLaneMaxRatio - paymentLaneMinRatio < RATIO_GAP_MIN`, evaluates to
     *      Panic(0x11) instead of InvalidValue whenever max < min. None of this repo's
     *      0.8.x updateParam implementations contains a single arithmetic operator,
     *      precisely to avoid that.
     */
    function _validateParams(Params memory p, string memory key, bytes memory value) internal pure {
        // stage one: absolute bounds
        if (p.paymentLaneMinRatio > RATIO_DENOM) revert InvalidValue(key, value);
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

        // stage two: BEP-703 section 3.6 invariants, over the full tuple
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
        // (6) EXPAND_STEP_RATIO <= EXPAND_TRIGGER_RATIO - SHRINK_TRIGGER_RATIO
        if (p.expandStepRatio + p.shrinkTriggerRatio > p.expandTriggerRatio) revert InvalidValue(key, value);
    }

    uint256[50] private __reservedSlot;
}
