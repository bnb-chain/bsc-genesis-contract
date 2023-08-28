// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

//import "forge-std/Test.sol";
//
//import "contracts/BC_fusion/StakePool.sol";
//
//contract StakePoolTest is Test {
//    address public init_holder = address(0xdead);
//
//    StakePool public pool;
//
//    function setUp() public {
//        pool = new StakePool();
//        pool.initialize{value: 1 ether}(address(this));
//    }
//
//    function testInitState() public {
//        uint256 initTotalShares = pool.totalSupply();
//        assertEq(initTotalShares, 1 ether);
//
//        uint256 initTotalStakedBNB = pool.totalStakedBNB();
//        assertEq(initTotalStakedBNB, 1 ether);
//
//        uint256 initHolderShares = pool.balanceOf(init_holder);
//        assertEq(initHolderShares, 1 ether);
//    }
//
//    function testDelegate() public {
//        // 1. delegate same BNB and get same shares when no reward received
//        // 1 BNB = 1 stBNB
//        address delegator1 = address(0x1);
//        address delegator2 = address(0x2);
//
//        uint256 shares1 = pool.delegate(delegator1, 1 ether);
//        uint256 shares2 = pool.delegate(delegator1, 1 ether);
//        assertEq(shares1, shares2);
//
//        uint256 shares3 = pool.delegate(delegator2, 1 ether);
//        assertEq(shares1, shares3);
//
//        // 2. delegate same BNB and get different shares if received reward
//        // totalPooledBNB = totalStakedBNB + totalReward
//        // newShares = _bnbAmount * totalShares / totalPooledBNB
//        uint256 postTotalStakedBNB = pool.totalStakedBNB();
//        uint256 postTotalShares = pool.totalSupply();
//        uint256 reward = 1 ether;
//        pool.distributeReward(reward);
//
//        uint256 newShares = pool.delegate(delegator1, 1 ether);
//        uint256 expectedShares = (1 ether * postTotalShares) / (postTotalStakedBNB + reward);
//        assertEq(newShares, expectedShares);
//    }
//
//    function testReward() public {
//        // 1. no reward received
//        // 1 BNB = 1 stBNB
//        address delegator = address(0x1);
//        uint256 shares = pool.delegate(delegator, 1 ether);
//        uint256 bnbAmount = pool.getPooledBNBByShares(shares);
//        assertEq(bnbAmount, shares);
//
//        // 2. reward received
//        // totalPooledBNB = totalStakedBNB + totalReward
//        // bnbAmount = shares * totalPooledBNB / totalShares
//        uint256 postTotalStakedBNB = pool.totalStakedBNB();
//        uint256 postTotalShares = pool.totalSupply();
//        uint256 reward = 1 ether;
//        pool.distributeReward(reward);
//
//        uint256 expectedAmount = (shares * (postTotalStakedBNB + reward)) / postTotalShares;
//        bnbAmount = pool.getPooledBNBByShares(shares);
//        assertEq(bnbAmount, expectedAmount);
//    }
//}
