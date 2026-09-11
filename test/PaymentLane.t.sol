// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.10;

import "./utils/Deployer.sol";
import { IPaymentLaneMeta } from "../contracts/interface/0.8.x/IPaymentLaneMeta.sol";

// The real implementation, for the fork-independent tests at the bottom of this file.
// Aliased because IPaymentLane.sol declares an interface of the same name.
import { PaymentLane as PaymentLaneImpl } from "../contracts/PaymentLane.sol";

contract PaymentLaneTest is Deployer {
    event PaymentContractAdded(address indexed paymentContract);
    event PaymentContractRemoved(address indexed paymentContract);
    event failReasonWithBytes(bytes message);

    // BEP-703 section 3.6.1's normative default for the one governable value.
    uint256 internal constant D_RATIO = 500;

    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    // No setUp: 0x…2007 does not exist on mainnet, so the harness etched fresh code onto a blank
    // account. Zero storage already reads as the shipped configuration - which is exactly the
    // state of every node the block after the fork.

    function _setRatio(
        uint256 value
    ) internal {
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("paymentLaneRatio", abi.encode(value));
    }

    function _expectInvalidRatio(
        uint256 value
    ) internal {
        vm.prank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneRatio", abi.encode(value)));
        paymentLane.updateParam("paymentLaneRatio", abi.encode(value));
    }

    function _expectListInvalid(string memory key, bytes memory value) internal {
        vm.expectRevert(abi.encodeWithSignature("InvalidValue(string,bytes)", key, value));
        paymentLane.updateParam(key, value);
    }

    /// @dev Both list keys take `abi.encode(address[])`; a single address is a one-element array.
    function _list(
        address a
    ) internal pure returns (bytes memory) {
        address[] memory addrs = new address[](1);
        addrs[0] = a;
        return abi.encode(addrs);
    }

    function _list(address a, address b) internal pure returns (bytes memory) {
        address[] memory addrs = new address[](2);
        addrs[0] = a;
        addrs[1] = b;
        return abi.encode(addrs);
    }

    function _list(address a, address b, address c) internal pure returns (bytes memory) {
        address[] memory addrs = new address[](3);
        addrs[0] = a;
        addrs[1] = b;
        addrs[2] = c;
        return abi.encode(addrs);
    }

    function _listRange(uint256 start, uint256 n) internal pure returns (bytes memory) {
        address[] memory addrs = new address[](n);
        for (uint256 i; i < n; ++i) {
            addrs[i] = address(uint160(start + i));
        }
        return abi.encode(addrs);
    }

    /*----------------- the ratio guard of section 3.6.1 -----------------*/

    /**
     * @dev `0 < PAYMENT_LANE_RATIO <= MAX_PAYMENT_LANE_RATIO` is the only bound on the
     *      reservation, so every edge of it is pinned here. Above the ceiling the lane would
     *      withhold a share of every block that starves general traffic, including Parlia's
     *      mandatory end-of-block system transactions; at 0 an unwritten slot and a
     *      governance-set slot would be indistinguishable.
     */
    function testRatioBounds() public {
        assertEq(paymentLane.getPaymentLaneRatio(), D_RATIO, "the default must be live before any vote");

        _setRatio(1); // the floor
        assertEq(paymentLane.getPaymentLaneRatio(), 1);

        uint256 max = paymentLane.MAX_PAYMENT_LANE_RATIO();
        _setRatio(max); // the ceiling
        assertEq(paymentLane.getPaymentLaneRatio(), max);

        _expectInvalidRatio(max + 1);
        _expectInvalidRatio(0);
        assertEq(paymentLane.getPaymentLaneRatio(), max, "a rejected vote must not move the ratio");
    }

    /**
     * @dev BEP-703 section 3.6.4: the guard is evaluated at the getter's full uint256 width, never
     *      on a value narrowed first. Each of these lands inside the guard once truncated - to a
     *      uint64, a uint32 and a uint16 respectively - so a narrowing decode would accept them.
     */
    function testWideValuesAreRejectedNotTruncated() public {
        _expectInvalidRatio(type(uint256).max);
        _expectInvalidRatio((uint256(1) << 64) + 500);
        _expectInvalidRatio((uint256(1) << 32) + 500);
        _expectInvalidRatio((uint256(1) << 16) + 500);
        assertEq(paymentLane.getPaymentLaneRatio(), D_RATIO);
    }

    /*----------------- GovHub swallows the revert -----------------*/

    /// @dev `GovHub.notifyUpdates` catches the target's revert and discards the return code, so a
    ///      rejected change leaves the governance transaction successful. The call must not
    ///      revert, `failReasonWithBytes` must fire, and state must be inert.
    function testGovHubSwallowsRejectionAndStateIsUnchanged() public {
        vm.expectEmit(false, false, false, true, GOV_HUB_ADDR);
        emit failReasonWithBytes(
            abi.encodeWithSignature("InvalidValue(string,bytes)", "paymentLaneRatio", abi.encode(9000))
        );
        _updateParamByGovHub("paymentLaneRatio", abi.encode(uint256(9000)), address(paymentLane));

        assertEq(paymentLane.getPaymentLaneRatio(), D_RATIO);
    }

    function testGovHubHappyPath() public {
        _updateParamByGovHub("paymentLaneRatio", abi.encode(uint256(300)), address(paymentLane));
        assertEq(paymentLane.getPaymentLaneRatio(), 300);
    }

    /// @dev The list branches take the same swallowed-revert path as the ratio one - which is
    ///      why an already-listed address is not a rejection: the revert would be invisible and
    ///      would take the rest of the array with it.
    function testGovHubListPath() public {
        _updateParamByGovHub("addPaymentContract", _list(USDT), address(paymentLane));
        assertTrue(paymentLane.isPaymentContract(USDT));

        _updateParamByGovHub("addPaymentContract", _list(USDT), address(paymentLane));
        assertEq(paymentLane.paymentContractCount(), 1, "a re-listed address must not duplicate");

        bytes memory none = abi.encode(new address[](0));
        vm.expectEmit(false, false, false, true, GOV_HUB_ADDR);
        emit failReasonWithBytes(abi.encodeWithSignature("InvalidValue(string,bytes)", "addPaymentContract", none));
        _updateParamByGovHub("addPaymentContract", none, address(paymentLane));
        assertEq(paymentLane.paymentContractCount(), 1);
    }

    /*----------------- the payment contract list -----------------*/

    function testListAddRemove() public {
        assertFalse(paymentLane.isPaymentContract(USDT));

        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractAdded(USDT);
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", _list(USDT));
        assertTrue(paymentLane.isPaymentContract(USDT));

        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractRemoved(USDT);
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("removePaymentContract", _list(USDT));
        assertFalse(paymentLane.isPaymentContract(USDT));
    }

    /// @dev No address is off-limits: BEP-703 section 3.6.2 puts admission entirely on the vote,
    ///      with no mechanical gate behind it. A reinstated range check fails here rather than at
    ///      a real vote.
    function testListAcceptsAnyAddress() public {
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", _list(address(0), address(0x0a), VALIDATOR_CONTRACT_ADDR));

        assertTrue(paymentLane.isPaymentContract(address(0)));
        assertTrue(paymentLane.isPaymentContract(address(0x0a)));
        assertTrue(paymentLane.isPaymentContract(VALIDATOR_CONTRACT_ADDR));

        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("removePaymentContract", _list(address(0)));
        assertFalse(paymentLane.isPaymentContract(address(0)));
    }

    /// @dev Section 3.6.5: the list keys state a postcondition, so an address already in the
    ///      wanted state is skipped and the rest of the array still lands. Rejecting it instead
    ///      would lose the rest to a revert GovHub swallows.
    function testListIsDeclarative() public {
        vm.startPrank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", _list(USDT));

        // a re-listed address changes nothing and does not stop the new one beside it
        paymentLane.updateParam("addPaymentContract", _list(USDT, USDC));
        assertEq(paymentLane.paymentContractCount(), 2);
        assertTrue(paymentLane.isPaymentContract(USDC));

        // likewise for removing an address that was never listed - and only the real removal
        // emits, so the log is the record of what changed
        vm.expectEmit(true, false, false, false, address(paymentLane));
        emit PaymentContractRemoved(USDT);
        paymentLane.updateParam("removePaymentContract", _list(address(0x0a), USDT));
        assertEq(paymentLane.paymentContractCount(), 1);
        assertFalse(paymentLane.isPaymentContract(USDT));

        // an all-stale removal is an accepted no-op, not a revert
        paymentLane.updateParam("removePaymentContract", _list(address(0x0a), USDT));
        assertEq(paymentLane.paymentContractCount(), 1);
        vm.stopPrank();
    }

    /// @dev The loops must honour `EnumerableSet.add`/`remove`'s return value. Dropping it leaves
    ///      membership and the count correct - the set already de-duplicates - and only the event
    ///      stream wrong, so nothing but a log count catches it.
    function testOnlyRealChangesEmit() public {
        vm.startPrank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", _list(USDT));

        // USDT is already listed: one PaymentContractAdded for USDC, then ParamChange
        vm.recordLogs();
        paymentLane.updateParam("addPaymentContract", _list(USDT, USDC));
        assertEq(vm.getRecordedLogs().length, 2, "a skipped add must not emit");
        assertEq(paymentLane.paymentContractCount(), 2, "the count must grow by the real additions");

        // the same address twice in one array is one entry and one event
        vm.recordLogs();
        paymentLane.updateParam("addPaymentContract", _list(address(0x0a), address(0x0a)));
        assertEq(vm.getRecordedLogs().length, 2, "an intra-array duplicate must not emit twice");
        assertEq(paymentLane.paymentContractCount(), 3);

        // 0x0b was never listed: one PaymentContractRemoved for USDT, then ParamChange
        vm.recordLogs();
        paymentLane.updateParam("removePaymentContract", _list(address(0x0b), USDT));
        assertEq(vm.getRecordedLogs().length, 2, "a skipped removal must not emit");
        vm.stopPrank();
    }

    function testGetPaymentContracts() public {
        (address[] memory empty, uint256 emptyTotal) = paymentLane.getPaymentContracts(0, 0);
        assertEq(empty.length, 0);
        assertEq(emptyTotal, 0);

        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", _listRange(0x10000, 5));

        // limit 0 means "the rest", so this is the whole list
        (address[] memory all, uint256 total) = paymentLane.getPaymentContracts(0, 0);
        assertEq(all.length, 5);
        assertEq(total, 5);
        assertEq(paymentLane.paymentContractCount(), 5);
        for (uint256 i; i < 5; ++i) {
            assertTrue(paymentLane.isPaymentContract(all[i]), "enumeration disagrees with membership");
        }
    }

    /// @dev The client only ever sees this contract through IPaymentLaneMeta, so every member of
    ///      it must be callable on the live contract and agree with it.
    function testMetaInterfaceReadsCurrentSemantics() public {
        IPaymentLaneMeta meta = IPaymentLaneMeta(address(paymentLane));
        assertEq(meta.getPaymentLaneRatio(), D_RATIO);

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
        paymentLane.updateParam("addPaymentContract", _list(USDT));

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
        paymentLane.updateParam("paymentLaneRatio", abi.encode(uint256(300)));

        // the timelock reaches PaymentLane only through GovHub, never directly
        vm.prank(TIMELOCK_ADDR);
        vm.expectRevert(abi.encodeWithSignature("OnlySystemContract(address)", GOV_HUB_ADDR));
        paymentLane.updateParam("paymentLaneRatio", abi.encode(uint256(300)));
    }

    /// @dev Section 3.6.5 defines exactly three keys; anything else is an unknown key whatever it
    ///      carries, because the key is matched before any branch looks at the value.
    function testUnknownParam() public {
        vm.startPrank(GOV_HUB_ADDR);
        vm.expectRevert(abi.encodeWithSignature("UnknownParam(string,bytes)", "notAParam", abi.encode(uint256(1))));
        paymentLane.updateParam("notAParam", abi.encode(uint256(1)));

        vm.expectRevert(abi.encodeWithSignature("UnknownParam(string,bytes)", "notAParam", bytes("")));
        paymentLane.updateParam("notAParam", "");

        // near misses, so a loosened key comparison fails here
        vm.expectRevert(abi.encodeWithSignature("UnknownParam(string,bytes)", "PaymentLaneRatio", abi.encode(500)));
        paymentLane.updateParam("PaymentLaneRatio", abi.encode(uint256(500)));
        vm.expectRevert(abi.encodeWithSignature("UnknownParam(string,bytes)", "paymentLaneRatio ", abi.encode(500)));
        paymentLane.updateParam("paymentLaneRatio ", abi.encode(uint256(500)));
        vm.stopPrank();
    }

    /**
     * @dev `getPaymentLaneRatio()` is consensus ABI: Parlia decodes its return value to derive
     *      every block's lane quota. Section 3.6.4 pins the return at a `uint256`, so a getter
     *      narrowed to `uint64` - or one that grew a second return value - forks the chain while
     *      every value-based test here stays green. This one would not.
     */
    function testConsensusReturnEncodingIsFrozen() public {
        _setRatio(300);

        (bool ok, bytes memory raw) = address(paymentLane).staticcall(abi.encodeWithSignature("getPaymentLaneRatio()"));
        assertTrue(ok);
        assertEq(raw.length, 32, "getPaymentLaneRatio must return exactly one word");
        assertEq(keccak256(raw), keccak256(abi.encode(uint256(300))), "return encoding changed");
    }

    /**
     * @dev The client mirrors every constant below and rejects any block whose ratio breaks them,
     *      so changing one here without the same change in core/paymentlane makes that client
     *      reject blocks its peers accept. Every other test reads them symbolically and would
     *      stay green; this one would not.
     */
    function testGuardConstantsAreFrozen() public {
        assertEq(paymentLane.RATIO_DENOM(), 10_000, "RATIO_DENOM");
        assertEq(paymentLane.MAX_PAYMENT_LANE_RATIO(), 1_000, "MAX_PAYMENT_LANE_RATIO");
        assertEq(paymentLane.MAX_PAYMENT_CONTRACTS(), 100_000, "MAX_PAYMENT_CONTRACTS");
    }

    /**
     * @dev The client hardcodes nothing about storage - section 3.6.4 forbids it from decoding
     *      any - but a shifted slot is still fatal: the ratio would read either the list's length
     *      or its own default, with no error anywhere. Inserting or reordering any state variable
     *      fails here.
     */
    function testStorageLayoutIsFrozen() public {
        _setRatio(300);
        assertEq(uint256(vm.load(address(paymentLane), bytes32(0))), 300, "the ratio slot moved");

        // slots 1 and 2 are the EnumerableSet: array length, then the index mapping
        vm.prank(GOV_HUB_ADDR);
        paymentLane.updateParam("addPaymentContract", _list(USDT));
        assertEq(uint256(vm.load(address(paymentLane), bytes32(uint256(1)))), 1, "list array moved");
        assertEq(
            uint256(vm.load(address(paymentLane), keccak256(abi.encode(USDT, uint256(2))))),
            1,
            "list index mapping moved"
        );
    }

    /// @dev The ratio takes exactly 32 bytes; the list keys take an ABI-encoded `address[]`, and
    ///      an empty one is the only malformed value this contract names itself.
    function testWrongValue() public {
        vm.startPrank(GOV_HUB_ADDR);
        _expectListInvalid("paymentLaneRatio", abi.encodePacked(uint64(500))); // 8 bytes
        _expectListInvalid("paymentLaneRatio", "");
        _expectListInvalid("paymentLaneRatio", abi.encodePacked(USDT)); // 20 bytes
        _expectListInvalid("addPaymentContract", abi.encode(new address[](0)));
        _expectListInvalid("removePaymentContract", abi.encode(new address[](0)));

        // Everything else dies in the ABI decoder, with no data to name the key. The packed forms
        // matter most: `abi.encode(address[])` of 3, 8, 13... addresses is a multiple of 20 bytes,
        // so a decoder that checked `length % 20` would have accepted a mis-encoded proposal and
        // listed word fragments as payment contracts.
        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT));
        vm.expectRevert();
        paymentLane.updateParam("addPaymentContract", abi.encodePacked(USDT, USDC, address(0x0a)));
        vm.expectRevert();
        paymentLane.updateParam("removePaymentContract", "");
        vm.stopPrank();
    }

    /*----------------- zero storage is the shipped configuration -----------------*/

    /// @dev The property that removes the need for an initializer, per BEP-703 section 3.6.3: a
    ///      contract that has never been written to must already answer with the BEP default and
    ///      an empty list, because that is the state of every node the block after the fork sets
    ///      the code.
    function testZeroStorageIsTheShippedConfiguration() public {
        address fresh = address(uint160(0x7654321));
        vm.etch(fresh, vm.getDeployedCode("PaymentLane.sol:PaymentLane"));

        for (uint256 i; i < 3; ++i) {
            assertEq(uint256(vm.load(fresh, bytes32(i))), 0, "storage must be untouched");
        }
        assertEq(IPaymentLaneMeta(fresh).getPaymentLaneRatio(), D_RATIO, "the default must be live");
        // Section 3.6.2: the fork lists nothing, every entry arrives by governance after it.
        assertEq(IPaymentLaneMeta(fresh).paymentContractCount(), 0, "the list must start empty");
        assertFalse(IPaymentLaneMeta(fresh).isPaymentContract(USDT));
    }

    /// @dev The first accepted vote materialises the slot, after which the fallback is inert - so
    ///      a later vote back to the default writes 500 rather than reverting to unwritten.
    function testFirstUpdateMaterialisesTheSlot() public {
        _setRatio(300);
        assertEq(uint256(vm.load(address(paymentLane), bytes32(0))), 300, "slot still unwritten");

        _setRatio(D_RATIO);
        assertEq(uint256(vm.load(address(paymentLane), bytes32(0))), D_RATIO, "an explicit default must be stored");
        assertEq(paymentLane.getPaymentLaneRatio(), D_RATIO);
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

    // The EnumerableSet's `_values` array length: slot 0 is the ratio.
    bytes32 internal constant LIST_LENGTH_SLOT = bytes32(uint256(1));

    function setUp() public {
        pl = new PaymentLaneImpl();
    }

    function _list(
        address a
    ) internal pure returns (bytes memory) {
        address[] memory addrs = new address[](1);
        addrs[0] = a;
        return abi.encode(addrs);
    }

    function _add(
        uint256 i
    ) internal {
        pl.updateParam("addPaymentContract", _list(address(uint160(0x10000 + i))));
    }

    function _addRange(uint256 start, uint256 n) internal {
        address[] memory addrs = new address[](n);
        for (uint256 i; i < n; ++i) {
            addrs[i] = address(uint160(0x10000 + start + i));
        }
        pl.updateParam("addPaymentContract", abi.encode(addrs));
    }

    /// @dev 300 in a single array: well below the explicit 100k cap, so a lower accidental cap -
    ///      or a loop that stops early - fails here rather than only after governance has grown
    ///      the list in production.
    function testListAllowsModeratelyLongLists() public {
        uint256 n = 300;

        vm.startPrank(GOV_HUB);
        _addRange(0, n);
        assertEq(pl.paymentContractCount(), n);

        // a re-listed address is a no-op at any length
        _add(0);
        assertEq(pl.paymentContractCount(), n);

        // and removal is unaffected by length
        pl.updateParam("removePaymentContract", _list(address(uint160(0x10000))));
        vm.stopPrank();

        assertEq(pl.paymentContractCount(), n - 1);
        assertFalse(pl.isPaymentContract(address(uint160(0x10000))), "removed address still listed");
        assertTrue(pl.isPaymentContract(address(uint160(0x10000 + n - 1))), "last add missing");
    }

    /// @dev The cap is the one hard stop left, so it is also the only place a whole array is
    ///      refused - which makes this the test that the refusal is atomic.
    function testListCapIsEnforced() public {
        uint256 max = pl.MAX_PAYMENT_CONTRACTS();

        vm.store(address(pl), LIST_LENGTH_SLOT, bytes32(max - 2));

        vm.startPrank(GOV_HUB);
        // an array that straddles the cap is refused whole, leaving no prefix behind
        vm.expectRevert(PaymentLaneImpl.PaymentContractLimitExceeded.selector);
        _addRange(0, 3);
        assertEq(uint256(vm.load(address(pl), LIST_LENGTH_SLOT)), max - 2, "a refused array must leave no trace");
        assertFalse(pl.isPaymentContract(address(uint160(0x10000))));

        // one that lands exactly on the cap is accepted
        _addRange(0, 2);
        assertEq(uint256(vm.load(address(pl), LIST_LENGTH_SLOT)), max);

        vm.expectRevert(PaymentLaneImpl.PaymentContractLimitExceeded.selector);
        _add(2);

        // but a re-listed address is still a no-op at the cap, not a violation: the cap counts
        // entries, never array length, so a `length + addrs.length` pre-check would fail here
        _add(0);
        vm.stopPrank();

        // the cap is a real ceiling and not an off-by-one
        assertEq(uint256(vm.load(address(pl), LIST_LENGTH_SLOT)), max);
    }

    /// @dev A page walk must cover the list exactly once, in the order the whole-list read gives.
    ///      BEP-703 section 3.6.4 lets a node mirror the list from these pages, and the order is
    ///      not stable across blocks, so every page - not just the first - has to carry the total
    ///      the walk is checked against.
    function testPagingCoversLongList() public {
        uint256 n = 300;
        uint256 pageSize = 64; // does not divide 300, so the last page is short

        vm.prank(GOV_HUB);
        _addRange(0, n);

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

    /// @dev Removal swaps the last entry into the gap, which is why section 3.6.4 says the order
    ///      is not stable and an index must not be carried across blocks. Membership - the only
    ///      thing consensus reads - is unaffected.
    function testRemovalSwapsTheLastEntryIntoTheGap() public {
        vm.startPrank(GOV_HUB);
        _addRange(0, 3);
        pl.updateParam("removePaymentContract", _list(address(uint160(0x10000))));
        vm.stopPrank();

        (address[] memory all,) = pl.getPaymentContracts(0, 0);
        assertEq(all.length, 2);
        assertEq(all[0], address(uint160(0x10002)), "the last entry must have moved into the gap");
        assertEq(all[1], address(uint160(0x10001)));
        assertFalse(pl.isPaymentContract(address(uint160(0x10000))));
    }

    /// @dev Over the full uint256 range, not just the legal band: an accepted value must land and
    ///      be readable through the getter, a rejected one must revert `InvalidValue` - never
    ///      Panic - and leave the stored ratio byte-identical. Acceptance must be exactly section
    ///      3.6.1's guard, which is what a narrowing decode would break.
    function testFuzzRatioAcceptOrInert(
        uint256 v
    ) public {
        uint256 before = pl.getPaymentLaneRatio();
        bytes32 rawBefore = vm.load(address(pl), bytes32(0));
        bool legal = v != 0 && v <= pl.MAX_PAYMENT_LANE_RATIO();

        vm.prank(GOV_HUB);
        try pl.updateParam("paymentLaneRatio", abi.encode(v)) {
            assertTrue(legal, "a value outside the guard was accepted");
            assertEq(pl.getPaymentLaneRatio(), v, "accepted value must have landed");
        } catch (bytes memory err) {
            assertFalse(legal, "a value inside the guard was rejected");
            assertEq(bytes4(err), bytes4(keccak256("InvalidValue(string,bytes)")), "rejection must be InvalidValue");
            assertEq(pl.getPaymentLaneRatio(), before, "a rejected update must not mutate state");
            assertEq(vm.load(address(pl), bytes32(0)), rawBefore, "a rejected update must not touch storage");
        }
    }
}
