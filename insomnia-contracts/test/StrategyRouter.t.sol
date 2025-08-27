// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SomniaTestBase} from "./TestBase.t.sol";

contract StrategyRouterTest is SomniaTestBase {
    function testAddAdapterAndWeights() public {
        // With single adapter, any weight != 10000 should REVERT
        vm.prank(admin);
        vm.expectRevert(bytes("weights!=100%"));
        router.setAdapterWeight(0, 8_000);

        // Correct to 100%
        vm.prank(admin);
        router.setAdapterWeight(0, 10_000);
    }

    function testAllocateDistributesFunds() public {
        vm.prank(alice);
        vault.depositNative{value: 9 ether}(alice);

        vm.prank(admin);
        vault.pushToRouter(9 ether);

        vm.prank(admin); // keeper
        vault.allocate();

        assertEq(address(adapter).balance, 9 ether, "adapter should hold 9 SOM");
    }
}
