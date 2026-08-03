// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

// The real implementation, for the fork-independent tests at the bottom of this file.
// Aliased because IPaymentLane.sol declares an interface of the same name.
import {PaymentLane as PaymentLaneImpl} from "../contracts/PaymentLane.sol";

contract PaymentLaneTest is Deployer {
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
    event failReasonWithBytes(bytes message);

    // BEP-703 section 3.6 suggested values, in the order the eight keys are declared.
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
        // PaymentLane does not exist on the mainnet fork, so the harness etched fresh
        // code onto a blank account. Storage is zero, exactly like the fork block.
        _initializeIfNeeded();
    }

    function _initializeIfNeeded() internal {
        if (paymentLane.paymentLaneMax() == 0) {
            vm.prank(block.coinbase);
            vm.txGasPrice(0);
            paymentLane.initialize();
        }
    }

    function _set(string memory key, uint256 value) internal {
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam(key, abi.encode(value));
    }

    function _params() internal view returns (uint256[8] memory p) {
        (p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]) = paymentLane.getPaymentLaneParams();
    }

    function _assertParams(uint256[8] memory expected) internal {
        uint256[8] memory actual = _params();
        for (uint256 i; i < 8; ++i) {
            assertEq(actual[i], expected[i], "param mismatch");
        }
    }

    /*----------------- 1. chain-halt regression -----------------*/

    /**
     * @dev The reason MAX_LANE_RATIO and friends exist. This tuple satisfies all six
     *      BEP-703 section 3.6 invariants:
     *        (1) 1000 - 0 = 1000 >= 1000      (2) 1000 > 1 > 0
     *        (3) 9000 - 0 = 9000 >= 500       (4) 2e18 > 1e18 > 0
     *        (5) 9000 <= 10000 - 1000         (6) 1000 <= 1000 - 0
     *      but at GasLimit 55M it pins paymentLaneSize at 49.5M, leaving 5.5M of
     *      general gas against the ~12.71M that Parlia's mandatory system
     *      transactions consume on a breathe block. No valid block would exist at
     *      that height, and remediation takes ~8 days of governance. Each of the four
     *      fields below must be rejected on its own.
     */
    function testChainHaltTupleIsRejectedFieldByField() public {
        vm.startPrank(GOV_HUB_ADDR);

        // paymentLaneMaxRatio = 9000 > MAX_LANE_RATIO (2000)
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneMaxRatio", abi.encode(9000)));
        paymentLane.updateParam("paymentLaneMaxRatio", abi.encode(uint256(9000)));

        // expandTriggerRatio = 1000 < MIN_EXPAND_TRIGGER_RATIO (5000)
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "expandTriggerRatio", abi.encode(1000)));
        paymentLane.updateParam("expandTriggerRatio", abi.encode(uint256(1000)));

        // shrinkTriggerRatio = 0 < MIN_SHRINK_TRIGGER_RATIO (2000); a zero trigger can
        // never fire because system transactions floor the signal, so the lane would
        // ratchet to its ceiling and never unwind.
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "shrinkTriggerRatio", abi.encode(0)));
        paymentLane.updateParam("shrinkTriggerRatio", abi.encode(uint256(0)));

        // paymentLaneMin = 1e18 > MAX_LANE_GAS (1e9). A huge floor is what pins
        // laneMin onto laneMax in section 3.4.4 and removes the dynamic behaviour.
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneMin", abi.encode(1e18)));
        paymentLane.updateParam("paymentLaneMin", abi.encode(uint256(1e18)));

        vm.stopPrank();

        // nothing moved
        _assertParams(
            [D_MIN_RATIO, D_MAX_RATIO, D_EXPAND_TRIGGER, D_SHRINK_TRIGGER, D_EXPAND_STEP, D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX]
        );
    }

    /// @dev Every value BEP-703 section 3.6 suggests must remain reachable.
    function testBepSuggestedDefaultsAreAccepted() public {
        _assertParams(
            [D_MIN_RATIO, D_MAX_RATIO, D_EXPAND_TRIGGER, D_SHRINK_TRIGGER, D_EXPAND_STEP, D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX]
        );
    }

    /*----------------- 2. every key revalidates all six invariants -----------------*/

    /**
     * @dev The property that per-key updates depend on. A key that is not part of an
     *      invariant's own pair must still be blocked by it. Here expandStepRatio is
     *      raised to a legal 900, then lowering expandTriggerRatio to 6000 must fail
     *      on invariant (1) (6000 < 7000 + 1000) even though the branch being executed
     *      is expandTriggerRatio's.
     */
    function testEveryKeyChecksAllInvariants() public {
        _set("expandStepRatio", 900);

        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "expandTriggerRatio", abi.encode(6000)));
        paymentLane.updateParam("expandTriggerRatio", abi.encode(uint256(6000)));

        // the ordering that does work
        _set("shrinkTriggerRatio", 5000);
        _set("expandTriggerRatio", 6000);
        _assertParams([D_MIN_RATIO, D_MAX_RATIO, 6000, 5000, 900, D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX]);
    }

    /*----------------- 3. GovHub swallows the revert -----------------*/

    /**
     * @dev `GovHub.notifyUpdates` catches the target's revert and discards the return
     *      code, so a rejected parameter change leaves the governance transaction
     *      successful. This test pins that behaviour: the call must not revert, a
     *      `failReasonWithBytes` must be emitted, and the state must be untouched.
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
        _updateParamByGovHub("expandStepRatio", abi.encode(uint256(300)), address(paymentLane));
        assertEq(paymentLane.expandStepRatio(), 300);
    }

    /*----------------- 4. InvalidValue, never Panic -----------------*/

    /**
     * @dev The invariants are written as additions on purpose. The natural subtraction
     *      form would evaluate to Panic(0x11) rather than InvalidValue whenever the
     *      operands are inverted, which surfaces through GovHub as an opaque
     *      `failReasonWithBytes(0x4e487b71...)`.
     */
    function testInvertedOperandsGiveInvalidValueNotPanic() public {
        // drive maxRatio below minRatio: raise minRatio past it
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneMinRatio", abi.encode(9000)));
        paymentLane.updateParam("paymentLaneMinRatio", abi.encode(uint256(9000)));

        // drive expandTrigger below shrinkTrigger: raise shrinkTrigger past it
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "shrinkTriggerRatio", abi.encode(9500)));
        paymentLane.updateParam("shrinkTriggerRatio", abi.encode(uint256(9500)));

        // and lane gas the same way
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneMin", abi.encode(9_000_000))
        );
        paymentLane.updateParam("paymentLaneMin", abi.encode(uint256(9_000_000)));
    }

    /*----------------- 5. bounds matrix -----------------*/

    /// @dev Every bound is read into a local first. A getter call inside an argument
    ///      expression is evaluated before the call being tested and would consume the
    ///      pending `vm.expectRevert`.
    function testAbsoluteBoundsAtTheEdge() public {
        uint256 ratioGapMin = paymentLane.RATIO_GAP_MIN();
        uint256 maxStep = paymentLane.MAX_STEP_RATIO();
        uint256 minLaneGas = paymentLane.MIN_LANE_GAS();
        uint256 maxLaneGas = paymentLane.MAX_LANE_GAS();

        // paymentLaneMinRatio: absolute range is [0, RATIO_DENOM], but invariant (3)
        // binds tighter against the current maxRatio of 800.
        _set("paymentLaneMinRatio", 0);
        _set("paymentLaneMinRatio", D_MAX_RATIO - ratioGapMin); // exactly at (3)
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("paymentLaneMinRatio", abi.encode(D_MAX_RATIO - ratioGapMin + 1));
        _set("paymentLaneMinRatio", D_MIN_RATIO);

        // paymentLaneMaxRatio ceiling. With expandTrigger at 8000, invariant (5) allows
        // exactly MAX_LANE_RATIO, so the two bind at the same point.
        _set("paymentLaneMaxRatio", 2000); // == MAX_LANE_RATIO, and 2000 + 8000 == RATIO_DENOM
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("paymentLaneMaxRatio", abi.encode(uint256(2001)));
        _set("paymentLaneMaxRatio", D_MAX_RATIO);

        // expandTriggerRatio floor
        _set("shrinkTriggerRatio", 3000);
        _set("expandTriggerRatio", 5000); // == MIN_EXPAND_TRIGGER_RATIO
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("expandTriggerRatio", abi.encode(uint256(4999)));

        // shrinkTriggerRatio floor
        _set("shrinkTriggerRatio", 2000); // == MIN_SHRINK_TRIGGER_RATIO
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("shrinkTriggerRatio", abi.encode(uint256(1999)));

        // step ceilings and the zero floor
        _set("shrinkStepRatio", 1);
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("shrinkStepRatio", abi.encode(uint256(0)));
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("expandStepRatio", abi.encode(maxStep + 1));

        // lane gas floor and ceiling
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("paymentLaneMin", abi.encode(minLaneGas - 1));
        _set("paymentLaneMin", minLaneGas);
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("paymentLaneMax", abi.encode(maxLaneGas + 1));
        _set("paymentLaneMax", maxLaneGas);
    }

    function testInvariantBoundaries() public {
        // (1) expandTrigger >= shrinkTrigger + TRIGGER_GAP_MIN
        _set("shrinkTriggerRatio", 6000);
        _set("expandTriggerRatio", 7000); // exactly at the gap
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("expandTriggerRatio", abi.encode(uint256(6999)));

        // (2) expandStep > shrinkStep. Raise the upper one first: the intermediate
        // state has to satisfy the invariant too, which is the whole point of per-key.
        _set("expandStepRatio", 301);
        _set("shrinkStepRatio", 300);
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("expandStepRatio", abi.encode(uint256(300)));

        // (6) expandStep + shrinkTrigger <= expandTrigger, i.e. step <= 1000 here
        _set("expandStepRatio", 1000);
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("shrinkTriggerRatio", abi.encode(uint256(6001)));

        // (4) laneMax > laneMin
        _set("paymentLaneMin", 5_000_000);
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("paymentLaneMax", abi.encode(uint256(5_000_000)));
    }

    /*----------------- 6. the full-tuple event -----------------*/

    function testParamsUpdatedCarriesTheWholeTuple() public {
        vm.expectEmit(false, false, false, true, address(paymentLane));
        emit PaymentLaneParamsUpdated(
            D_MIN_RATIO, D_MAX_RATIO, D_EXPAND_TRIGGER, D_SHRINK_TRIGGER, 300, D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX
        );
        _set("expandStepRatio", 300);
    }

    /*----------------- 7. the payment contract list -----------------*/

    function testListAddRemove() public {
        assertEq(paymentLane.paymentContractsLength(), 0);
        assertFalse(paymentLane.isPaymentContract(USDT));

        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractAdded(USDT);
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));

        assertTrue(paymentLane.isPaymentContract(USDT));
        assertEq(paymentLane.paymentContractsLength(), 1);

        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractRemoved(USDT);
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("removePaymentContract", abi.encodePacked(USDT));

        assertFalse(paymentLane.isPaymentContract(USDT));
        assertEq(paymentLane.paymentContractsLength(), 0);
    }

    function testListRejections() public {
        vm.startPrank(GOV_HUB_ADDR);

        // abi.encode gives 32 bytes; the decoder needs the packed 20-byte form
        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encode(USDT));

        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(0)));

        // every precompile and every system contract sits at or below MAX_RESERVED_ADDRESS.
        // Listing a precompile would let one transaction burn MaxTxGas of *payment* gas;
        // listing a system contract would reclassify Parlia's own system transactions.
        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(0x0a)));
        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(VALIDATOR_CONTRACT_ADDR));
        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0xFFFF))));

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

    /*----------------- 8. the batch getter the client uses -----------------*/

    function testArePaymentContracts() public {
        vm.startPrank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        vm.stopPrank();

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

        // empty input must not revert
        assertEq(paymentLane.arePaymentContracts(new address[](0)).length, 0);
    }

    /*----------------- 9. access control -----------------*/

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
        vm.expectRevert(
            abi.encodeWithSignature("UnknownParam(string,bytes)", "notAParam", abi.encode(uint256(1)))
        );
        paymentLane.updateParam("notAParam", abi.encode(uint256(1)));
    }

    /// @dev `initializer` is declared before `onlyCoinbase`, so on an already
    ///      initialized contract the initializer check fires first. OnlyCoinbase can
    ///      therefore only be observed on a fresh instance.
    function testInitializeIsOneShotAndCoinbaseOnly() public {
        address fresh = address(uint160(0x1111111));
        vm.etch(fresh, vm.getDeployedCode("PaymentLane.sol:PaymentLane"));
        vm.txGasPrice(0);
        vm.expectRevert(abi.encodeWithSignature("OnlyCoinbase()"));
        PaymentLane(fresh).initialize();

        vm.prank(block.coinbase);
        vm.expectRevert("Initializable: contract is already initialized");
        paymentLane.initialize();
    }

    function testInitializeRejectsNonZeroGasPrice() public {
        // fresh, uninitialized instance
        address fresh = address(uint160(0x1234567));
        vm.etch(fresh, vm.getDeployedCode("PaymentLane.sol:PaymentLane"));

        vm.prank(block.coinbase);
        vm.txGasPrice(1);
        vm.expectRevert(abi.encodeWithSignature("OnlyZeroGasPrice()"));
        PaymentLane(fresh).initialize();
    }

    /*----------------- 10. the uninitialized sentinel -----------------*/

    /**
     * @dev `paymentLaneMax == 0` is unreachable in any valid configuration, so the
     *      client uses it as the "lane not active yet" sentinel. This asserts the
     *      branch is reachable, which is the pre-activation behaviour of every node.
     */
    function testUninitializedSentinel() public {
        address fresh = address(uint160(0x7654321));
        vm.etch(fresh, vm.getDeployedCode("PaymentLane.sol:PaymentLane"));

        (,,,,,,, uint256 laneMax) = PaymentLane(fresh).getPaymentLaneParams();
        assertEq(laneMax, 0, "an uninitialized PaymentLane must read as lane-disabled");

        vm.prank(block.coinbase);
        vm.txGasPrice(0);
        PaymentLane(fresh).initialize();

        (,,,,,,, laneMax) = PaymentLane(fresh).getPaymentLaneParams();
        assertEq(laneMax, D_LANE_MAX);
    }

    /*----------------- 11. no-ops and value length -----------------*/

    /// @dev Resending the current value is accepted, matching all 39 existing keys in
    ///      this repo. Governance relies on it when moving one field of a set.
    function testNoOpUpdateIsAccepted() public {
        _set("expandStepRatio", D_EXPAND_STEP);
        assertEq(paymentLane.expandStepRatio(), D_EXPAND_STEP);
    }

    function testWrongValueLength() public {
        vm.startPrank(GOV_HUB_ADDR);
        vm.expectRevert();
        paymentLane.updateParam("expandStepRatio", abi.encodePacked(uint64(200))); // 8 bytes
        vm.expectRevert();
        paymentLane.updateParam("expandStepRatio", ""); // 0 bytes
        vm.stopPrank();
    }
}

/**
 * @notice PaymentLane has no dependency on any other system contract, no precompile
 *         and no mainnet state, so everything that does not go through the real GovHub
 *         can be exercised against a locally deployed instance.
 *
 * @dev This matters for more than tidiness. The address 0x...2007 does not exist on
 *      mainnet, so on a fork every cold storage slot of the etched contract is fetched
 *      from the upstream node. A test that writes hundreds of fresh slots outruns the
 *      ~128-block state window of a non-archive endpoint and fails with "missing trie
 *      node". A locally created account has no upstream to consult.
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

    function testListCap() public {
        uint256 cap = pl.MAX_PAYMENT_CONTRACTS();

        vm.startPrank(GOV_HUB);
        for (uint256 i; i < cap; ++i) {
            pl.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + i))));
        }
        assertEq(pl.paymentContractsLength(), cap);

        vm.expectRevert(PaymentLaneImpl.ExceedsMaxPaymentContracts.selector);
        pl.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + cap))));

        // freeing one slot lets exactly one more in
        pl.updateParam("removePaymentContract", abi.encodePacked(address(uint160(0x10000))));
        pl.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + cap))));
        assertEq(pl.paymentContractsLength(), cap);
        vm.stopPrank();
    }

    /// @dev Removal is swap-and-pop, so the first/middle/last/only cases each take a
    ///      different branch inside EnumerableSet.
    function testRemovalOrderCases() public {
        address a = address(uint160(0x10001));
        address b = address(uint160(0x10002));
        address c = address(uint160(0x10003));

        vm.startPrank(GOV_HUB);
        pl.updateParam("addPaymentContract", abi.encodePacked(a));
        pl.updateParam("addPaymentContract", abi.encodePacked(b));
        pl.updateParam("addPaymentContract", abi.encodePacked(c));

        // middle
        pl.updateParam("removePaymentContract", abi.encodePacked(b));
        assertTrue(pl.isPaymentContract(a));
        assertFalse(pl.isPaymentContract(b));
        assertTrue(pl.isPaymentContract(c));
        assertEq(pl.paymentContractsLength(), 2);

        // last
        pl.updateParam("removePaymentContract", abi.encodePacked(c));
        assertTrue(pl.isPaymentContract(a));
        assertFalse(pl.isPaymentContract(c));

        // only
        pl.updateParam("removePaymentContract", abi.encodePacked(a));
        assertEq(pl.paymentContractsLength(), 0);

        // re-adding a previously removed address must work
        pl.updateParam("addPaymentContract", abi.encodePacked(b));
        assertTrue(pl.isPaymentContract(b));
        vm.stopPrank();
    }

    /// @dev The invariants must hold for every accepted value, not only the ones the
    ///      hand-written boundary cases happen to probe.
    function testFuzzAcceptedParamsAlwaysSatisfyInvariants(uint256 raw) public {
        uint256 v = bound(raw, 0, pl.RATIO_DENOM());

        vm.prank(GOV_HUB);
        try pl.updateParam("expandTriggerRatio", abi.encode(v)) {
            (, uint256 maxRatio, uint256 expandTrigger, uint256 shrinkTrigger, uint256 expandStep,,,) =
                pl.getPaymentLaneParams();
            assertEq(expandTrigger, v, "accepted value must have landed");
            assertGe(expandTrigger, shrinkTrigger + pl.TRIGGER_GAP_MIN(), "invariant (1)");
            assertLe(maxRatio + expandTrigger, pl.RATIO_DENOM(), "invariant (5)");
            assertLe(expandStep + shrinkTrigger, expandTrigger, "invariant (6)");
            assertGe(expandTrigger, pl.MIN_EXPAND_TRIGGER_RATIO(), "absolute floor");
        } catch {
            // rejected values must leave the previous configuration untouched
            (,, uint256 expandTrigger,,,,,) = pl.getPaymentLaneParams();
            assertEq(expandTrigger, pl.INIT_EXPAND_TRIGGER_RATIO(), "a rejected update must not mutate state");
        }
    }
}
