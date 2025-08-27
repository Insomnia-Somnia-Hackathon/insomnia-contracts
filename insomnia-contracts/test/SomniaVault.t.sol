// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SomniaTestBase} from "./TestBase.t.sol";
import {SomniaVault} from "../src/core/SomniaVault.sol";

contract SomniaVaultTest is SomniaTestBase {
    function testDepositMintsSharesAndSetsLock() public {
        uint256 amt = 10 ether;
        vm.prank(alice);
        vault.depositNative{value: amt}(alice);

        assertEq(vault.totalSupply(), amt);
        assertEq(vault.balanceOf(alice), amt);
        assertGt(vault.unlockAt(alice), block.timestamp);
        assertApproxEqAbs(vault.totalAssets(), amt, 1);
    }

    function testAllocateAndUnwind() public {
        vm.prank(alice);
        vault.depositNative{value: 20 ether}(alice);

        vm.prank(admin);
        vault.pushToRouter(20 ether);

        vm.prank(address(this));
        vm.expectRevert(); // missing keeper role
        vault.allocate();

        vm.prank(admin);
        vault.allocate();
        assertGt(router.totalManagedNative(), 0);

        vm.prank(admin);
        vault.pullFromRouter(10 ether);
        assertGe(address(vault).balance, 10 ether);
    }

    function testWithdrawAfterLock() public {
        vm.prank(alice);
        vault.depositNative{value: 5 ether}(alice);

        vm.prank(alice);
        vm.expectRevert(); // locked
        vault.withdraw(5 ether, payable(alice));

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(alice);
        vault.withdraw(5 ether, payable(alice));

        assertEq(vault.totalSupply(), 0);
        assertEq(vault.balanceOf(alice), 0);
    }

    function testEarlyExitPenaltyWhenEnabled() public {
        // Deploy a Boost-like vault with 5% penalty. We won't allocate, so funds remain on-hand.
        vm.startPrank(admin);
        SomniaVault boost = new SomniaVault(
            "Boost","bsSOM",
            admin,
            14 days,
            500,                 // 5%
            treasury,
            address(router),     // not used in this test (no allocate)
            address(pc),
            0
        );
        vm.stopPrank();

        vm.deal(bob, 100 ether);
        vm.prank(bob);
        boost.depositNative{value: 20 ether}(bob);

        vm.prank(bob);
        vm.expectRevert();
        boost.withdraw(20 ether, payable(address(this))); // address(this) adalah test kontrak tanpa receive/fallback

        // Early exit → penalty to treasury
        uint256 treBefore = treasury.balance;
        vm.prank(bob);
        boost.withdraw(20 ether, payable(bob));
        uint256 treAfter = treasury.balance;

        assertGt(treAfter, treBefore, "treasury should receive penalty");
    }
}
