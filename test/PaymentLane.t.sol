// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.10;

import "./utils/Deployer.sol";
import { IPaymentLaneMeta } from "../contracts/interface/0.8.x/IPaymentLaneMeta.sol";

// The real implementation, for the fork-independent tests at the bottom of this file.
// Aliased because IPaymentLane.sol declares an interface of the same name.
import {PaymentLane as PaymentLaneImpl} from "../contracts/PaymentLane.sol";

/// @dev The eight parameters in key order, read the way the client reads them: through
///      IPaymentLaneMeta. Shared by both test contracts below.
function _readParams(address pl) view returns (uint256[8] memory) {
    IPaymentLaneMeta.Params memory q = IPaymentLaneMeta(pl).getPaymentLaneParams();
    return [
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

contract PaymentLaneTest is Deployer {
    event PaymentLaneParamsUpdated(PaymentLane.Params params);
    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);
    event failReasonWithBytes(bytes message);

    // BEP-703 section 3.6.1 normative values, in key order.
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

    // No setUp: 0x…2007 does not exist on mainnet, so the harness etched fresh code onto a blank
    // account. Zero storage already reads as the shipped configuration - which is exactly the
    // state of every node the block after the fork.

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

    function _assertParams(uint256[8] memory expected) internal {
        _assertParams(address(paymentLane), expected);
    }

    function _assertParams(address pl, uint256[8] memory expected) internal {
        uint256[8] memory actual = _readParams(pl);
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

    /// @dev The defaults hold 200 twice, so a swap of paymentLaneMinRatio (slot 0) and
    ///      expandStepRatio (slot 4) would leave every field-by-field assertion green. Moving one
    ///      field to 300 makes all eight values distinct; the layout and encoding tests below
    ///      start from here for that reason.
    function _setStep300() internal returns (uint256[8] memory expected) {
        _set("expandStepRatio", 300);
        expected = _defaults();
        expected[4] = 300;
    }

    /*----------------- the range guards of section 3.6.2 -----------------*/

    /**
     * @dev BEP-703 section 3.6.2 carries two sets of constraints: six invariants binding the
     *      parameters to each other, and a table of range guards bounding each one on its own.
     *      This tuple satisfies all six invariants - and the guard that every one of the eight is
     *      non-zero - yet pins the lane at 90% of the block, starving the mandatory end-of-block
     *      system transactions. Only the magnitude guards catch it. If any assertion here starts
     *      failing, a chain-halting configuration has become reachable by a single governance vote.
     */
    function testChainHaltTupleIsRejectedFieldByField() public {
        // First the premise: the six invariants really do accept this tuple. If any of these stops
        // holding, the range guards are catching something else than advertised.
        uint256 minR = 1;
        uint256 maxR = 8999;
        uint256 expT = 1001;
        uint256 shrT = 1;
        uint256 expS = 1000;
        uint256 shrS = 1;
        uint256 laneMin = 1e18;
        uint256 laneMax = 2e18;
        assertGe(expT, shrT + paymentLane.TRIGGER_GAP_MIN(), "(1)");
        assertGt(expS, shrS, "(2)");
        assertGe(maxR, minR + paymentLane.RATIO_GAP_MIN(), "(3)");
        assertGt(laneMax, laneMin, "(4)");
        assertLe(maxR + expT, paymentLane.RATIO_DENOM(), "(5)");
        assertLe(expS + shrT, expT, "(6)");

        // and now each field of that same tuple against the range guard that rejects it
        _expectInvalid("paymentLaneMaxRatio", maxR); // > MAX_LANE_RATIO
        _expectInvalid("expandTriggerRatio", expT); // < MIN_EXPAND_TRIGGER_RATIO
        _expectInvalid("shrinkTriggerRatio", shrT); // < MIN_SHRINK_TRIGGER_RATIO
        _expectInvalid("paymentLaneMin", laneMin); // > MAX_LANE_GAS
        _expectInvalid("paymentLaneMax", laneMax); // > MAX_LANE_GAS

        _assertParams(_defaults()); // and the BEP defaults are still what is stored
    }

    /*----------------- every key revalidates all six invariants -----------------*/

    /// @dev With `expandStepRatio` at a legal 900, lowering `expandTriggerRatio` to 6000 must
    ///      fail on invariant (1) even though the branch executing is `expandTriggerRatio`'s.
    function testEveryKeyChecksAllInvariants() public {
        _set("expandStepRatio", 900);
        _expectInvalid("expandTriggerRatio", 6000);

        // the ordering that does work
        _set("shrinkTriggerRatio", 5000);
        _set("expandTriggerRatio", 6000);
        _assertParams([D_MIN_RATIO, D_MAX_RATIO, 6000, 5000, 900, D_SHRINK_STEP, D_LANE_MIN, D_LANE_MAX]);
    }

    /*----------------- GovHub swallows the revert -----------------*/

    /// @dev `GovHub.notifyUpdates` catches the target's revert and discards the return code, so a
    ///      rejected change leaves the governance transaction successful. The call must not
    ///      revert, `failReasonWithBytes` must fire, and state must be inert.
    function testGovHubSwallowsRejectionAndStateIsUnchanged() public {
        uint256[8] memory before = _readParams(address(paymentLane));

        vm.expectEmit(false, false, false, true, GOV_HUB_ADDR);
        emit failReasonWithBytes(
            abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneMaxRatio", abi.encode(9000))
        );
        _updateParamByGovHub("paymentLaneMaxRatio", abi.encode(uint256(9000)), address(paymentLane));

        _assertParams(before);
    }

    function testGovHubHappyPath() public {
        _updateParamByGovHub("expandStepRatio", abi.encode(uint256(300)), address(paymentLane));
        assertEq(paymentLane.getPaymentLaneParams().expandStepRatio, 300);
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

    /// @dev The invariants are written as additions so that inverted operands revert
    ///      `InvalidValue` rather than `Panic(0x11)`, which would reach operators only as an
    ///      opaque `failReasonWithBytes` blob. `_expectInvalid` pins the selector, so a
    ///      regression that reordered the two validation stages would fail here.
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
        // The declared ceiling is MAX_LANE_RATIO, but invariant (3) binds tighter against the
        // current maxRatio of 800, so the reachable ceiling is 300.
        _set("paymentLaneMinRatio", 1); // 0 is the unwritten-slot marker, see testZeroIsNotSettable
        _set("paymentLaneMinRatio", D_MAX_RATIO - paymentLane.RATIO_GAP_MIN());
        _expectInvalid("paymentLaneMinRatio", D_MAX_RATIO - paymentLane.RATIO_GAP_MIN() + 1);
    }

    function testMaxRatioCeilingIsolatedFromInvariant5() public {
        // Both bind at 2000 under the defaults, so make room in (5) first. shrinkTrigger has to
        // come down before expandTrigger, or (1) rejects the move.
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

    /// @dev Values inside a parameter's declared range that the contract nonetheless refuses,
    ///      because another constraint binds tighter. The rejections an operator is most likely
    ///      to be surprised by.
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

        // (2) expandStep > shrinkStep. Raise the upper one first: the intermediate state has to
        // satisfy the invariant too, which is the whole point of per-key updates.
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
        // MAX_STEP_RATIO == TRIGGER_GAP_MIN, because (1) is checked first and already guarantees
        // the gap. There is deliberately no test for it.
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

    /// @dev No address is off-limits: listing is governance-only and every listing is reversible
    ///      by the same vote. A reinstated range check fails here rather than at a real vote.
    function testListAcceptsAnyAddress() public {
        vm.startPrank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(0)));
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(0x0a)));
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(VALIDATOR_CONTRACT_ADDR));
        vm.stopPrank();

        assertTrue(paymentLane.isPaymentContract(address(0)));
        assertTrue(paymentLane.isPaymentContract(address(0x0a)));
        assertTrue(paymentLane.isPaymentContract(VALIDATOR_CONTRACT_ADDR));

        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("removePaymentContract", abi.encodePacked(address(0)));
        assertFalse(paymentLane.isPaymentContract(address(0)));
    }

    function testListRejections() public {
        vm.startPrank(GOV_HUB_ADDR);

        // abi.encode gives 32 bytes; the decoder needs the packed 20-byte form
        _expectListInvalid("addPaymentContract", abi.encode(USDT));

        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        vm.expectRevert(abi.encodeWithSignature("PaymentContractAlreadyExists()"));
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));

        vm.expectRevert(abi.encodeWithSignature("PaymentContractNotFound()"));
        paymentLane.updateParam("removePaymentContract", abi.encodePacked(USDC));

        vm.stopPrank();
    }

    function testGetPaymentContracts() public {
        (address[] memory empty, uint256 emptyTotal) = paymentLane.getPaymentContracts(0, 0);
        assertEq(empty.length, 0);
        assertEq(emptyTotal, 0);

        vm.startPrank(GOV_HUB_ADDR);
        for (uint256 i; i < 5; ++i) {
            paymentLane.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + i))));
        }
        vm.stopPrank();

        // limit 0 means "the rest", so this is the whole list
        (address[] memory all, uint256 total) = paymentLane.getPaymentContracts(0, 0);
        assertEq(all.length, 5);
        assertEq(total, 5);
        for (uint256 i; i < 5; ++i) {
            assertTrue(paymentLane.isPaymentContract(all[i]), "enumeration disagrees with membership");
        }
    }

    /// @dev The client only ever sees this contract through IPaymentLaneMeta, so every member of
    ///      it must be callable on the live contract and agree with it.
    function testMetaInterfaceReadsCurrentSemantics() public {
        IPaymentLaneMeta meta = IPaymentLaneMeta(address(paymentLane));
        _assertParams(address(meta), _defaults()); // _readParams reads through the meta interface

        assertEq(meta.paymentContractCount(), 0);
        (address[] memory listed, uint256 total) = meta.getPaymentContracts(0, 0);
        assertEq(listed.length, 0);
        assertEq(total, 0);
        assertFalse(meta.isPaymentContract(USDC));
        assertFalse(meta.isPaymentContract(USDT));

        address[] memory q = new address[](2);
        q[0] = USDC;
        q[1] = USDT;
        bool[] memory results = meta.arePaymentContracts(q);
        assertEq(results.length, 2);
        assertFalse(results[0]);
        assertFalse(results[1]);
    }

    /*----------------- the batch getter -----------------*/

    function testArePaymentContracts() public {
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));

        address[] memory q = new address[](4);
        q[0] = USDC; // not listed
        q[1] = USDT; // listed
        q[2] = USDT; // duplicate of a listed address
        q[3] = address(0); // currently not listed

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

        // The length guard runs before the dispatch, so an unknown key carrying a non-32-byte
        // value is reported as a bad value rather than a bad key.
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "notAParam", bytes("")));
        paymentLane.updateParam("notAParam", "");
    }

    /**
     * @dev `getPaymentLaneParams()` is consensus ABI: Parlia decodes its return value every
     *      block. `Params` doubles as this contract's internal working type, which is exactly the
     *      pressure that would tempt someone to add a ninth field to it - silently making the
     *      return 288 bytes and forking the chain. Every field-name based test would keep
     *      passing; this one would not.
     */
    function testConsensusReturnEncodingIsFrozen() public {
        uint256[8] memory expected = _setStep300();

        (bool ok, bytes memory raw) =
            address(paymentLane).staticcall(abi.encodeWithSignature("getPaymentLaneParams()"));
        assertTrue(ok);
        assertEq(raw.length, 256, "getPaymentLaneParams must return exactly eight words");
        assertEq(keccak256(raw), keccak256(abi.encode(expected)), "field order or encoding changed");
    }

    /**
     * @dev The client mirrors every constant below and rejects any block whose tuple or list
     *      breaks them, so changing one here without the same change in core/paymentlane makes
     *      that client reject blocks its peers accept. Every other test reads them symbolically
     *      and would stay green; this one would not.
     */
    function testGuardConstantsAreFrozen() public {
        assertEq(paymentLane.RATIO_DENOM(), 10_000, "RATIO_DENOM");
        assertEq(paymentLane.TRIGGER_GAP_MIN(), 1_000, "TRIGGER_GAP_MIN");
        assertEq(paymentLane.RATIO_GAP_MIN(), 500, "RATIO_GAP_MIN");
        assertEq(paymentLane.MAX_LANE_RATIO(), 2_000, "MAX_LANE_RATIO");
        assertEq(paymentLane.MIN_EXPAND_TRIGGER_RATIO(), 5_000, "MIN_EXPAND_TRIGGER_RATIO");
        assertEq(paymentLane.MIN_SHRINK_TRIGGER_RATIO(), 2_000, "MIN_SHRINK_TRIGGER_RATIO");
        assertEq(paymentLane.MAX_STEP_RATIO(), 1_000, "MAX_STEP_RATIO");
        assertEq(paymentLane.MIN_LANE_GAS(), 21_000, "MIN_LANE_GAS");
        assertEq(paymentLane.MAX_LANE_GAS(), 1_000_000_000, "MAX_LANE_GAS");
        assertEq(paymentLane.MAX_PAYMENT_CONTRACTS(), 100_000, "MAX_PAYMENT_CONTRACTS");
    }

    /**
     * @dev The client hardcodes nothing about storage, but a shifted slot is still fatal: a
     *      `paymentLaneMax` that reads 0 puts every node into "lane off" permanently, because a
     *      shifted slot reads either a neighbour's value or its own default, with no error
     *      anywhere. Inserting or reordering any state variable fails here.
     */
    function testStorageLayoutIsFrozen() public {
        // An update materialises all eight slots, which is what lets this compare storage against
        // known values.
        uint256[8] memory expected = _setStep300();
        for (uint256 i; i < 8; ++i) {
            assertEq(uint256(vm.load(address(paymentLane), bytes32(i))), expected[i], "param slot moved");
        }
        // slots 8 and 9 are the EnumerableSet: array length, then the index mapping
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        assertEq(uint256(vm.load(address(paymentLane), bytes32(uint256(8)))), 1, "list array moved");
        assertEq(
            uint256(vm.load(address(paymentLane), keccak256(abi.encode(USDT, uint256(9))))),
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

    /*----------------- zero storage is the shipped configuration -----------------*/

    /// @dev The property that removes the need for an initializer: a contract that has never been
    ///      written to must already answer with the BEP-703 defaults, because that is the state
    ///      every node is in the block after the fork sets the code.
    function testZeroStorageReadsAsDefaults() public {
        address fresh = address(uint160(0x7654321));
        vm.etch(fresh, vm.getDeployedCode("PaymentLane.sol:PaymentLane"));

        for (uint256 i; i < 8; ++i) {
            assertEq(uint256(vm.load(fresh, bytes32(i))), 0, "storage must be untouched");
        }
        _assertParams(fresh, _defaults());
        // BEP-703 section 3.6.3: the fork lists nothing, every entry arrives by governance after it
        assertEq(IPaymentLaneMeta(fresh).paymentContractCount(), 0, "the list must start empty");
    }

    /// @dev 0 stops being a settable value - that is what makes an unwritten slot unambiguous. Six
    ///      parameters already had a positive floor in stage one and paymentLaneMaxRatio is caught
    ///      by invariant (3); this is the one the explicit zero check restricts.
    function testZeroIsNotSettable() public {
        _expectInvalid("paymentLaneMinRatio", 0);
    }

    /// @dev The first accepted update materialises all eight, after which the fallback is inert.
    function testFirstUpdateMaterialisesEveryDefault() public {
        uint256[8] memory expected = _setStep300();
        for (uint256 i; i < 8; ++i) {
            assertTrue(uint256(vm.load(address(paymentLane), bytes32(i))) != 0, "slot still unwritten");
        }
        _assertParams(expected);
    }
}

/**
 * @notice PaymentLane depends on no other system contract, no precompile and no mainnet state, so
 *         anything that does not go through the real GovHub can run against a locally deployed
 *         instance.
 *
 * @dev Not only tidiness: 0x…2007 does not exist on mainnet, so on a fork every cold slot of the
 *      etched contract is fetched from upstream, and a test that writes hundreds of fresh slots
 *      outruns a non-archive node's state window. A locally created account has no upstream.
 */
contract PaymentLaneStandaloneTest is Test {
    PaymentLaneImpl internal pl;

    address internal constant GOV_HUB = 0x0000000000000000000000000000000000001007;

    function setUp() public {
        pl = new PaymentLaneImpl();
    }

    function _add(uint256 i) internal {
        pl.updateParam("addPaymentContract", abi.encodePacked(address(uint160(0x10000 + i))));
    }

    /// @dev 300 stays well below the explicit 100k cap, so a lower accidental cap fails here
    ///      rather than only after governance has grown the list in production.
    function testListAllowsModeratelyLongLists() public {
        uint256 n = 300;

        vm.startPrank(GOV_HUB);
        for (uint256 i; i < n; ++i) {
            _add(i);
        }
        assertEq(pl.paymentContractCount(), n);

        // a duplicate is a duplicate at any length
        vm.expectRevert(PaymentLaneImpl.PaymentContractAlreadyExists.selector);
        _add(0);

        // and removal is unaffected by length
        pl.updateParam("removePaymentContract", abi.encodePacked(address(uint160(0x10000))));
        vm.stopPrank();

        assertEq(pl.paymentContractCount(), n - 1);
        assertFalse(pl.isPaymentContract(address(uint160(0x10000))), "removed address still listed");
        assertTrue(pl.isPaymentContract(address(uint160(0x10000 + n - 1))), "last add missing");
    }

    function testListCapIsEnforced() public {
        uint256 maxPaymentContracts = pl.MAX_PAYMENT_CONTRACTS();
        bytes32 lenSlot = bytes32(uint256(8));

        vm.store(address(pl), lenSlot, bytes32(maxPaymentContracts - 1));

        vm.startPrank(GOV_HUB);
        _add(0);
        assertEq(uint256(vm.load(address(pl), lenSlot)), maxPaymentContracts);

        vm.expectRevert(PaymentLaneImpl.PaymentContractLimitExceeded.selector);
        _add(1);
        vm.stopPrank();

        // the rejected add left no trace, so the cap is a real ceiling and not an off-by-one
        assertEq(uint256(vm.load(address(pl), lenSlot)), maxPaymentContracts);
    }

    /// @dev A page walk must cover the list exactly once, in the order the whole-list read gives.
    ///      BEP-703 section 3.6.5 has the client check each page against the total that call
    ///      returns, so every page - not just the first - has to carry the total.
    function testPagingCoversLongList() public {
        uint256 n = 300;
        uint256 pageSize = 64; // does not divide 300, so the last page is short

        vm.startPrank(GOV_HUB);
        for (uint256 i; i < n; ++i) {
            _add(i);
        }
        vm.stopPrank();

        (address[] memory all, uint256 total) = pl.getPaymentContracts(0, 0);
        assertEq(all.length, n);
        assertEq(total, n);

        for (uint256 offset; offset < n; offset += pageSize) {
            (address[] memory page, uint256 pageTotal) = pl.getPaymentContracts(offset, pageSize);
            assertEq(pageTotal, n, "every page must report the total");
            assertEq(page.length, n - offset > pageSize ? pageSize : n - offset, "wrong page length");
            for (uint256 i; i < page.length; ++i) {
                assertEq(page[i], all[offset + i], "page disagrees with full read");
            }
        }

        // running off the end is an empty page, not a revert
        (address[] memory past, uint256 pastTotal) = pl.getPaymentContracts(n, 0);
        assertEq(past.length, 0);
        assertEq(pastTotal, n);
    }

    /// @dev Accepted values must land and leave the other seven untouched; rejected values must
    ///      leave all eight byte-identical and must never Panic. All eight keys over the full
    ///      uint256 range, not just the legal band.
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
        uint256[8] memory before = _readParams(address(pl));

        vm.prank(GOV_HUB);
        try pl.updateParam(keys[i], abi.encode(v)) {
            uint256[8] memory got = _readParams(address(pl));
            assertEq(got[i], v, "accepted value must have landed");
            // The whole lazy-default design rests on this: if 0 were ever accepted, an unwritten
            // slot and a governance-set 0 would be indistinguishable.
            assertTrue(v != 0, "0 must never be an accepted parameter value");
            for (uint256 j; j < 8; ++j) {
                if (j != i) assertEq(got[j], before[j], "an accepted update moved another field");
            }
            _assertAllInvariants(got);
        } catch (bytes memory err) {
            assertEq(bytes4(err), bytes4(keccak256("InvalidValue(string,bytes)")), "rejection must be InvalidValue");
            uint256[8] memory got = _readParams(address(pl));
            for (uint256 j; j < 8; ++j) {
                assertEq(got[j], before[j], "a rejected update must not mutate state");
            }
        }
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
