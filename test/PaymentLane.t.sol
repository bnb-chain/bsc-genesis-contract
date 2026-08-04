// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

// The real implementation, for the fork-independent tests at the bottom of this file.
// Aliased because IPaymentLane.sol declares an interface of the same name.
import {PaymentLane as PaymentLaneImpl} from "../contracts/PaymentLane.sol";

contract PaymentLaneTest is Deployer {
    event PaymentLaneParamsUpdated(PaymentLane.Params params);
    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);
    event failReasonWithBytes(bytes message);

    // BEP-703 section 3.6 suggested values, in key order.
    uint256 internal constant D_MIN_RATIO = 200;
    uint256 internal constant D_MAX_RATIO = 800;
    uint256 internal constant D_EXPAND_TRIGGER = 8000;
    uint256 internal constant D_SHRINK_TRIGGER = 7000;
    uint256 internal constant D_EXPAND_STEP = 200;
    uint256 internal constant D_SHRINK_STEP = 50;
    uint256 internal constant D_LANE_MIN = 2_000_000;
    uint256 internal constant D_LANE_MAX = 8_000_000;

    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    function setUp() public {
        // 0x…2007 does not exist on mainnet, so the harness etched fresh code onto a
        // blank account: storage is zero, exactly as at the fork block.
        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        paymentLane.initialize();
    }

    function _set(string memory key, uint256 value) internal {
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam(key, abi.encode(value));
    }

    function _expectInvalid(string memory key, uint256 value) internal {
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", key, abi.encode(value)));
        paymentLane.updateParam(key, abi.encode(value));
    }

    function _expectListInvalid(string memory key, bytes memory value) internal {
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", key, value));
        paymentLane.updateParam(key, value);
    }

    function _params() internal view returns (uint256[8] memory p) {
        PaymentLane.Params memory q = paymentLane.getPaymentLaneParams();
        p = [
            q.paymentLaneMinRatio,
            q.paymentLaneMaxRatio,
            q.expandTriggerRatio,
            q.shrinkTriggerRatio,
            q.expandStepRatio,
            q.shrinkStepRatio,
            q.paymentLaneMin,
            q.paymentLaneMax
        ];
    }

    function _assertParams(uint256[8] memory expected) internal {
        uint256[8] memory actual = _params();
        for (uint256 i; i < 8; ++i) {
            assertEq(actual[i], expected[i], "param mismatch");
        }
    }

    function _defaults() internal pure returns (uint256[8] memory) {
        return [
            D_MIN_RATIO,
            D_MAX_RATIO,
            D_EXPAND_TRIGGER,
            D_SHRINK_TRIGGER,
            D_EXPAND_STEP,
            D_SHRINK_STEP,
            D_LANE_MIN,
            D_LANE_MAX
        ];
    }

    /*----------------- the reason the extra ceilings exist -----------------*/

    /**
     * @dev This tuple satisfies all six BEP-703 section 3.6 invariants but pins the lane
     *      at 90% of the block, starving the mandatory end-of-block system transactions.
     *      Each of the four fields must be rejected on its own by a ceiling the BEP does
     *      not have. If any assertion here starts failing, a chain-halting configuration
     *      has become reachable by a single governance vote.
     */
    function testChainHaltTupleIsRejectedFieldByField() public {
        // First the premise: BEP-703 alone really does accept this tuple. If any of these
        // stops holding, the extra ceilings are guarding something else than advertised.
        uint256 minR = 0;
        uint256 maxR = 9000;
        uint256 expT = 1000;
        uint256 shrT = 0;
        uint256 expS = 1000;
        uint256 shrS = 1;
        assertGe(expT, shrT + paymentLane.TRIGGER_GAP_MIN(), "(1)");
        assertGt(expS, shrS, "(2)");
        assertGe(maxR, minR + paymentLane.RATIO_GAP_MIN(), "(3)");
        assertGt(uint256(2e18), uint256(1e18), "(4)");
        assertLe(maxR + expT, paymentLane.RATIO_DENOM(), "(5)");
        assertLe(expS + shrT, expT, "(6)");

        // and now each field on its own against a ceiling the BEP does not have
        _expectInvalid("paymentLaneMaxRatio", 9000); // > MAX_LANE_RATIO
        _expectInvalid("expandTriggerRatio", 1000); // < MIN_EXPAND_TRIGGER_RATIO
        _expectInvalid("shrinkTriggerRatio", 0); // < MIN_SHRINK_TRIGGER_RATIO
        _expectInvalid("paymentLaneMin", 1e18); // > MAX_LANE_GAS

        _assertParams(_defaults()); // and the BEP defaults are still what is stored
    }

    /*----------------- every key revalidates all six invariants -----------------*/

    /**
     * @dev The property per-key updates depend on. `expandStepRatio` is raised to a legal
     *      900, then lowering `expandTriggerRatio` to 6000 must fail on invariant (1)
     *      even though the branch executing is `expandTriggerRatio`'s.
     */
    function testEveryKeyChecksAllInvariants() public {
        _set("expandStepRatio", 900);
        _expectInvalid("expandTriggerRatio", 6000);

        // the ordering that does work
        _set("shrinkTriggerRatio", 5000);
        _set("expandTriggerRatio", 6000);
        _assertParams([D_MIN_RATIO, D_MAX_RATIO, 6000, 5000, 900, D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX]);
    }

    /*----------------- GovHub swallows the revert -----------------*/

    /**
     * @dev `GovHub.notifyUpdates` catches the target's revert and discards the return
     *      code, so a rejected change leaves the governance transaction successful. The
     *      call must not revert, `failReasonWithBytes` must fire, and state must be inert.
     */
    function testGovHubSwallowsRejectionAndStateIsUnchanged() public {
        uint256[8] memory before = _params();

        vm.expectEmit(false, false, false, true, GOV_HUB_ADDR);
        emit failReasonWithBytes(
            abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneMaxRatio", abi.encode(9000))
        );
        _updateParamByGovHub("paymentLaneMaxRatio", abi.encode(uint256(9000)), address(paymentLane));

        _assertParams(before);
    }

    function testGovHubHappyPath() public {
        vm.expectEmit(false, false, false, true, address(paymentLane));
        emit paramChange("expandStepRatio", abi.encode(uint256(300)));
        _updateParamByGovHub("expandStepRatio", abi.encode(uint256(300)), address(paymentLane));
        assertEq(paymentLane.expandStepRatio(), 300);
    }

    /// @dev The list branches take the same swallowed-revert path as the numeric ones.
    function testGovHubListPath() public {
        _updateParamByGovHub("addPaymentContract", abi.encodePacked(USDT), address(paymentLane));
        assertTrue(paymentLane.isPaymentContract(USDT));

        vm.expectEmit(false, false, false, true, GOV_HUB_ADDR);
        emit failReasonWithBytes(abi.encodeWithSignature("PaymentContractAlreadyExists()"));
        _updateParamByGovHub("addPaymentContract", abi.encodePacked(USDT), address(paymentLane));
        assertTrue(paymentLane.isPaymentContract(USDT));
    }

    /*----------------- InvalidValue, never Panic -----------------*/

    /**
     * @dev The invariants are written as additions so that inverted operands revert
     *      `InvalidValue` rather than `Panic(0x11)`, which would reach operators only as
     *      an opaque `failReasonWithBytes` blob. `_expectInvalid` pins the selector, so
     *      a regression that reordered the two stages would fail here.
     */
    function testInvertedOperandsGiveInvalidValueNotPanic() public {
        _expectInvalid("paymentLaneMinRatio", 9000); // would be maxRatio - minRatio
        _expectInvalid("shrinkTriggerRatio", 9500); // would be expandTrigger - shrinkTrigger
        _expectInvalid("paymentLaneMin", 9_000_000); // would be laneMax - laneMin
        _expectInvalid("paymentLaneMinRatio", type(uint256).max);
        _expectInvalid("paymentLaneMaxRatio", type(uint256).max);
        _expectInvalid("expandTriggerRatio", type(uint256).max);
        _expectInvalid("shrinkTriggerRatio", type(uint256).max);
    }

    /*----------------- bounds, one parameter family per test -----------------*/

    function testMinRatioBounds() public {
        // The declared ceiling is MAX_LANE_RATIO, but invariant (3) binds tighter against
        // the current maxRatio of 800, so the reachable ceiling is 300.
        _set("paymentLaneMinRatio", 0);
        _set("paymentLaneMinRatio", D_MAX_RATIO - paymentLane.RATIO_GAP_MIN());
        _expectInvalid("paymentLaneMinRatio", D_MAX_RATIO - paymentLane.RATIO_GAP_MIN() + 1);
    }

    function testMaxRatioCeilingIsolatedFromInvariant5() public {
        // Both bind at 2000 under the defaults, so make room in (5) first. shrinkTrigger
        // has to come down before expandTrigger, or (1) rejects the move.
        _set("shrinkTriggerRatio", 3000);
        _set("expandTriggerRatio", 5000);

        _set("paymentLaneMaxRatio", 2000); // == MAX_LANE_RATIO, and (5) has 3000 to spare
        _expectInvalid("paymentLaneMaxRatio", 2001); // the ceiling alone
        _expectInvalid("expandTriggerRatio", 8001); // invariant (5) alone
    }

    function testTriggerFloors() public {
        _set("shrinkTriggerRatio", 3000); // make room under invariant (1)
        _set("expandTriggerRatio", 5000); // == MIN_EXPAND_TRIGGER_RATIO
        _expectInvalid("expandTriggerRatio", 4999);

        _set("shrinkTriggerRatio", 2000); // == MIN_SHRINK_TRIGGER_RATIO
        _expectInvalid("shrinkTriggerRatio", 1999);
    }

    function testStepBounds() public {
        _set("shrinkStepRatio", 1);
        _expectInvalid("shrinkStepRatio", 0);
        _set("expandStepRatio", paymentLane.MAX_STEP_RATIO()); // accepted at the ceiling
        _expectInvalid("expandStepRatio", paymentLane.MAX_STEP_RATIO() + 1);
    }

    function testLaneGasBounds() public {
        uint256 minLaneGas = paymentLane.MIN_LANE_GAS();
        uint256 maxLaneGas = paymentLane.MAX_LANE_GAS();

        _expectInvalid("paymentLaneMin", minLaneGas - 1);
        _set("paymentLaneMin", minLaneGas);
        _expectInvalid("paymentLaneMax", maxLaneGas + 1);
        _set("paymentLaneMax", maxLaneGas);
    }

    /**
     * @dev Values inside a parameter's declared range that the contract nonetheless
     *      refuses, because another constraint binds tighter. These are the rejections an
     *      operator is most likely to be surprised by.
     */
    function testSurprisingRejections() public {
        _expectInvalid("paymentLaneMinRatio", 1501); // maxRatio 800 - 500 = 300 is the real cap
        _expectInvalid("expandStepRatio", 1); // must exceed shrinkStep, which is 50 by default
        _expectInvalid("paymentLaneMin", 1e9); // must stay below laneMax
        _expectInvalid("paymentLaneMax", 21_000); // must stay above laneMin
    }

    function testInvariantBoundaries() public {
        // (1) expandTrigger >= shrinkTrigger + TRIGGER_GAP_MIN
        _set("shrinkTriggerRatio", 6000);
        _set("expandTriggerRatio", 7000); // exactly at the gap
        _expectInvalid("expandTriggerRatio", 6999);

        // (2) expandStep > shrinkStep. Raise the upper one first: the intermediate state
        // has to satisfy the invariant too, which is the whole point of per-key updates.
        _set("expandStepRatio", 301);
        _set("shrinkStepRatio", 300);
        _expectInvalid("expandStepRatio", 300);

        // (3) maxRatio >= minRatio + RATIO_GAP_MIN
        _set("paymentLaneMinRatio", D_MAX_RATIO - 500);
        _expectInvalid("paymentLaneMinRatio", D_MAX_RATIO - 499);

        // (4) laneMax > laneMin, accepted at exactly one gas of separation
        _set("paymentLaneMin", 5_000_000);
        _expectInvalid("paymentLaneMax", 5_000_000);
        _set("paymentLaneMax", 5_000_001);

        // (6) expandStep + shrinkTrigger <= expandTrigger is unreachable while
        // MAX_STEP_RATIO == TRIGGER_GAP_MIN, because (1) is checked first and already
        // guarantees the gap. There is deliberately no test for it.
    }

    /*----------------- the full-tuple event -----------------*/

    function testParamsUpdatedCarriesTheWholeTuple() public {
        vm.expectEmit(false, false, false, true, address(paymentLane));
        emit PaymentLaneParamsUpdated(
            PaymentLane.Params({
                paymentLaneMinRatio: D_MIN_RATIO,
                paymentLaneMaxRatio: D_MAX_RATIO,
                expandTriggerRatio: D_EXPAND_TRIGGER,
                shrinkTriggerRatio: D_SHRINK_TRIGGER,
                expandStepRatio: 300,
                shrinkStepRatio: D_SHRINK_STEP,
                paymentLaneMin: D_LANE_MIN,
                paymentLaneMax: D_LANE_MAX
            })
        );
        _set("expandStepRatio", 300);
    }

    /*----------------- the payment contract list -----------------*/

    function testListAddRemove() public {
        assertFalse(paymentLane.isPaymentContract(USDT));

        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractAdded(USDT);
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        assertTrue(paymentLane.isPaymentContract(USDT));

        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractRemoved(USDT);
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("removePaymentContract", abi.encodePacked(USDT));
        assertFalse(paymentLane.isPaymentContract(USDT));
    }

    function testListRejections() public {
        vm.startPrank(GOV_HUB_ADDR);

        // abi.encode gives 32 bytes; the decoder needs the packed 20-byte form
        _expectListInvalid("addPaymentContract", abi.encode(USDT));

        // every precompile and every system contract sits at or below MAX_RESERVED_ADDRESS.
        // Listing a precompile would let one transaction burn MaxTxGas of *payment* gas;
        // listing a system contract would reclassify Parlia's own system transactions.
        _expectListInvalid("addPaymentContract", abi.encodePacked(address(0)));
        _expectListInvalid("addPaymentContract", abi.encodePacked(address(0x0a)));
        _expectListInvalid("addPaymentContract", abi.encodePacked(VALIDATOR_CONTRACT_ADDR));
        _expectListInvalid("addPaymentContract", abi.encodePacked(address(uint160(0xFFFF))));

        // the first address above the reserved range is fine
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000))));

        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        vm.expectRevert(abi.encodeWithSignature("PaymentContractAlreadyExists()"));
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));

        vm.expectRevert(abi.encodeWithSignature("PaymentContractNotFound()"));
        paymentLane.updateParam("removePaymentContract", abi.encodePacked(USDC));

        vm.stopPrank();
    }

    function testGetPaymentContractsPagination() public {
        vm.startPrank(GOV_HUB_ADDR);
        for (uint256 i; i < 5; ++i) {
            paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + i))));
        }
        vm.stopPrank();

        (address[] memory all, uint256 total) = paymentLane.getPaymentContracts(0, 0); // 0 means all
        assertEq(total, 5);
        assertEq(all.length, 5);

        (address[] memory page,) = paymentLane.getPaymentContracts(3, 10);
        assertEq(page.length, 2);

        // over-paginating returns an empty page and the real length, it must not revert
        (address[] memory none, uint256 total2) = paymentLane.getPaymentContracts(99, 10);
        assertEq(none.length, 0);
        assertEq(total2, 5);
    }

    /*----------------- the batch getter the client uses -----------------*/

    function testArePaymentContracts() public {
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));

        address[] memory q = new address[](4);
        q[0] = USDC; // not listed
        q[1] = USDT; // listed
        q[2] = USDT; // duplicate of a listed address
        q[3] = address(0); // never listable

        bool[] memory r = paymentLane.arePaymentContracts(q);
        assertEq(r.length, 4);
        assertFalse(r[0]);
        assertTrue(r[1]);
        assertTrue(r[2]);
        assertFalse(r[3]);

        assertEq(paymentLane.arePaymentContracts(new address[](0)).length, 0);
    }

    /*----------------- access control -----------------*/

    function testOnlyGovCanUpdateParam() public {
        vm.expectRevert(abi.encodeWithSignature("OnlySystemContract(address)", GOV_HUB_ADDR));
        paymentLane.updateParam("expandStepRatio", abi.encode(uint256(300)));

        // the timelock reaches PaymentLane only through GovHub, never directly
        vm.prank(TIMELOCK_ADDR);
        vm.expectRevert(abi.encodeWithSignature("OnlySystemContract(address)", GOV_HUB_ADDR));
        paymentLane.updateParam("expandStepRatio", abi.encode(uint256(300)));
    }

    function testUnknownParam() public {
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("UnknownParam(string,bytes)", "notAParam", abi.encode(uint256(1))));
        paymentLane.updateParam("notAParam", abi.encode(uint256(1)));

        // The length guard runs before the dispatch, so an unknown key carrying a
        // non-32-byte value is reported as a bad value rather than a bad key.
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "notAParam", bytes("")));
        paymentLane.updateParam("notAParam", "");
    }

    /**
     * @dev `getPaymentLaneParams()` is consensus ABI: Parlia decodes its return value
     *      every block. `Params` doubles as this contract's internal working type, which
     *      is exactly the pressure that would tempt someone to add a ninth field to it —
     *      silently making the return 288 bytes and forking the chain. Every field-name
     *      based test would keep passing; this one would not.
     */
    function testConsensusReturnEncodingIsFrozen() public {
        // The defaults contain 200 twice, so at the defaults a swap of those two fields
        // would hash identically. Move one first: with eight distinct values no
        // permutation survives.
        _set("expandStepRatio", 300);
        uint256[8] memory expected =
            [D_MIN_RATIO, D_MAX_RATIO, D_EXPAND_TRIGGER, D_SHRINK_TRIGGER, uint256(300), D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX];

        (bool ok, bytes memory raw) =
            address(paymentLane).staticcall(abi.encodeWithSignature("getPaymentLaneParams()"));
        assertTrue(ok);
        assertEq(raw.length, 256, "getPaymentLaneParams must return exactly eight words");
        assertEq(keccak256(raw), keccak256(abi.encode(expected)), "field order or encoding changed");
    }

    /**
     * @dev The client hardcodes nothing about storage, but a shifted slot is still fatal:
     *      a `paymentLaneMax` that reads 0 puts every node into "lane off" permanently,
     *      because `initialize()` is spent and no single key escapes an all-zero tuple.
     *      Inserting or reordering any state variable fails here.
     */
    function testStorageLayoutIsFrozen() public {
        for (uint256 i; i < 8; ++i) {
            assertEq(uint256(vm.load(address(paymentLane), bytes32(i + 1))), _defaults()[i], "param slot moved");
        }
        // slots 9 and 10 are the EnumerableSet: array length, then the index mapping
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        assertEq(uint256(vm.load(address(paymentLane), bytes32(uint256(9)))), 1, "list array moved");
        assertEq(
            uint256(vm.load(address(paymentLane), keccak256(abi.encode(USDT, uint256(10))))),
            1,
            "list index mapping moved"
        );
    }

    function testWrongValueLength() public {
        vm.startPrank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("expandStepRatio", abi.encodePacked(uint64(200))); // 8 bytes
        vm.expectRevert();
        paymentLane.updateParam("expandStepRatio", ""); // 0 bytes
        vm.stopPrank();
    }

    /*----------------- the uninitialized sentinel -----------------*/

    /**
     * @dev `paymentLaneMax == 0` is unreachable in any valid configuration, so the client
     *      uses it as the "lane not active yet" signal. This asserts the branch is
     *      reachable, which is the pre-activation behaviour of every node. `initializer`
     *      also makes the call one-shot.
     */
    function testUninitializedSentinelAndOneShotInit() public {
        address fresh = address(uint160(0x7654321));
        vm.etch(fresh, vm.getDeployedCode("PaymentLane.sol:PaymentLane"));

        assertEq(
            PaymentLane(fresh).getPaymentLaneParams().paymentLaneMax,
            0,
            "an uninitialized PaymentLane must read as lane-disabled"
        );

        // onlyCoinbase can only be observed before `initializer` consumes the call
        vm.txGasPrice(0);
        vm.expectRevert(abi.encodeWithSignature("OnlyCoinbase()"));
        PaymentLane(fresh).initialize();

        vm.prank(block.coinbase);
        PaymentLane(fresh).initialize();
        assertEq(PaymentLane(fresh).getPaymentLaneParams().paymentLaneMax, D_LANE_MAX);

        vm.prank(block.coinbase);
        vm.expectRevert("Initializable: contract is already initialized");
        PaymentLane(fresh).initialize();
    }
}

/**
 * @notice PaymentLane depends on no other system contract, no precompile and no mainnet
 *         state, so anything that does not go through the real GovHub can run against a
 *         locally deployed instance.
 *
 * @dev Not only tidiness: 0x…2007 does not exist on mainnet, so on a fork every cold slot
 *      of the etched contract is fetched from upstream, and a test that writes hundreds of
 *      fresh slots outruns a non-archive node's state window. A locally created account
 *      has no upstream to consult.
 */
contract PaymentLaneStandaloneTest is Test {
    PaymentLaneImpl internal pl;

    address internal constant GOV_HUB = 0x0000000000000000000000000000000000001007;

    function setUp() public {
        pl = new PaymentLaneImpl();
        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        pl.initialize();
    }

    function _add(uint256 i) internal {
        pl.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + i))));
    }

    function _listLength() internal view returns (uint256 n) {
        (, n) = pl.getPaymentContracts(0, 1);
    }

    function testListCap() public {
        uint256 cap = pl.MAX_PAYMENT_CONTRACTS();

        vm.startPrank(GOV_HUB);
        for (uint256 i; i < cap; ++i) {
            _add(i);
        }
        assertEq(_listLength(), cap);

        vm.expectRevert(PaymentLaneImpl.ExceedsMaxPaymentContracts.selector);
        _add(cap);

        // a duplicate on a full list must still report the duplicate, not "list full"
        vm.expectRevert(PaymentLaneImpl.PaymentContractAlreadyExists.selector);
        _add(0);

        // freeing one slot lets exactly one more in
        pl.updateParam("removePaymentContract", abi.encodePacked(address(uint160(0x10000))));
        _add(cap);
        assertEq(_listLength(), cap);
        vm.stopPrank();
    }

    /**
     * @dev Accepted values must land and leave the other seven untouched; rejected values
     *      must leave all eight byte-identical and must never Panic. Covers all eight
     *      keys over the full uint256 range, not just the legal band.
     */
    function testFuzzAcceptOrInert(uint8 keyIndex, uint256 v) public {
        string[8] memory keys = [
            "paymentLaneMinRatio",
            "paymentLaneMaxRatio",
            "expandTriggerRatio",
            "shrinkTriggerRatio",
            "expandStepRatio",
            "shrinkStepRatio",
            "paymentLaneMin",
            "paymentLaneMax"
        ];
        uint256 i = keyIndex % 8;
        uint256[8] memory before = _read();

        vm.prank(GOV_HUB);
        try pl.updateParam(keys[i], abi.encode(v)) {
            uint256[8] memory got = _read();
            assertEq(got[i], v, "accepted value must have landed");
            for (uint256 j; j < 8; ++j) {
                if (j != i) assertEq(got[j], before[j], "an accepted update moved another field");
            }
            _assertAllInvariants(got);
        } catch (bytes memory err) {
            assertEq(bytes4(err), bytes4(keccak256("InvalidValue(string,bytes)")), "rejection must be InvalidValue");
            uint256[8] memory got = _read();
            for (uint256 j; j < 8; ++j) {
                assertEq(got[j], before[j], "a rejected update must not mutate state");
            }
        }
    }

    function _read() internal view returns (uint256[8] memory p) {
        PaymentLaneImpl.Params memory q = pl.getPaymentLaneParams();
        p = [
            q.paymentLaneMinRatio,
            q.paymentLaneMaxRatio,
            q.expandTriggerRatio,
            q.shrinkTriggerRatio,
            q.expandStepRatio,
            q.shrinkStepRatio,
            q.paymentLaneMin,
            q.paymentLaneMax
        ];
    }

    function _assertAllInvariants(uint256[8] memory p) internal {
        assertLe(p[0], pl.MAX_LANE_RATIO());
        assertTrue(p[1] >= pl.RATIO_GAP_MIN() && p[1] <= pl.MAX_LANE_RATIO());
        assertTrue(p[2] >= pl.MIN_EXPAND_TRIGGER_RATIO() && p[2] <= pl.RATIO_DENOM());
        assertTrue(p[3] >= pl.MIN_SHRINK_TRIGGER_RATIO() && p[3] <= pl.RATIO_DENOM());
        assertTrue(p[4] > 0 && p[4] <= pl.MAX_STEP_RATIO());
        assertTrue(p[5] > 0 && p[5] <= pl.MAX_STEP_RATIO());
        assertTrue(p[6] >= pl.MIN_LANE_GAS() && p[6] <= pl.MAX_LANE_GAS());
        assertTrue(p[7] >= pl.MIN_LANE_GAS() && p[7] <= pl.MAX_LANE_GAS());
        assertGe(p[2], p[3] + pl.TRIGGER_GAP_MIN()); // (1)
        assertGt(p[4], p[5]); // (2)
        assertGe(p[1], p[0] + pl.RATIO_GAP_MIN()); // (3)
        assertGt(p[7], p[6]); // (4)
        assertLe(p[1] + p[2], pl.RATIO_DENOM()); // (5)
        assertLe(p[4] + p[3], p[2]); // (6)
    }
}
