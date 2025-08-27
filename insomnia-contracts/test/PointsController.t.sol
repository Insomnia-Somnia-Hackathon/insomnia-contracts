// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SomniaTestBase} from "./TestBase.t.sol";

contract PointsControllerTest is SomniaTestBase {
    function testAccrualIncreasesOverTime() public {
        // Alice deposits 10 ether
        vm.prank(alice);
        vault.depositNative{value: 10 ether}(alice);

        // Snapshot initial preview
        (uint256 total0,,) = pc.preview(address(vault), alice);
        assertEq(total0, 0, "Initial points should be zero");

        // Advance time and poke indices
        vm.warp(block.timestamp + 1 hours);
        bytes32[] memory emptyArray = new bytes32[](1);
        emptyArray[0] = bytes32(0);
        pc.poke(address(vault), emptyArray);

        // Accumulate for Alice
        pc.accumulate(address(vault), alice);

        (uint256 total1,,) = pc.preview(address(vault), alice);
        assertGt(total1, 0, "Points should grow after time passes");
    }

    function testChangingBaseRateAffectsAccrual() public {
        vm.prank(alice);
        vault.depositNative{value: 5 ether}(alice);

        // let some time pass
        vm.warp(block.timestamp + 30 minutes);
        bytes32[] memory emptyArray1 = new bytes32[](1);
        emptyArray1[0] = bytes32(0);
        pc.poke(address(vault), emptyArray1);
        pc.accumulate(address(vault), alice);
        (uint256 before,,) = pc.preview(address(vault), alice);

        // Change base rate
        bytes32 sn = keccak256("SOMNIA_NETWORK");
        vm.prank(admin);
        pc.setBaseRate(address(vault), sn, 5e16); // increase 5x

        // move forward in time and accumulate again
        vm.warp(block.timestamp + 30 minutes);
        bytes32[] memory emptyArray2 = new bytes32[](1);
        emptyArray2[0] = bytes32(0);
        pc.poke(address(vault), emptyArray2);
        pc.accumulate(address(vault), alice);
        (uint256 afterValue,,) = pc.preview(address(vault), alice);

        assertGt(
            afterValue - before,
            before / 2,
            "Accrual should be faster after rate bump"
        );
    }
}
