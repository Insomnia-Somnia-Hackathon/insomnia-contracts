// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {SomniaVault} from "../src/core/SomniaVault.sol";
import {StrategyRouter} from "../src/core/StrategyRouter.sol";
import {PointsController} from "../src/core/PointsController.sol";
import {SimpleHoldingAdapter} from "../src/adapters/SimpleHoldingAdapter.sol";
import {Roles} from "../src/utils/Roles.sol";

contract SomniaTestBase is Test {
    // actors
    address internal admin    = address(0xA11CE);
    address internal treasury = address(0xFEE);
    address internal alice    = address(0xBEEF);
    address internal bob      = address(0xCAFE);

    // contracts
    SomniaVault internal vault;
    StrategyRouter internal router;
    PointsController internal pc;
    SimpleHoldingAdapter internal adapter;

    // config
    uint256 internal constant LOCK7D = 7 days;

    // point sources
    bytes32 internal constant SRC_NETWORK = keccak256("SOMNIA_NETWORK");
    bytes32 internal constant SRC_ECOSYS  = keccak256("ECOSYSTEM");


    function setUp() public virtual {
        vm.deal(admin, 1_000 ether);
        vm.deal(alice, 1_000 ether);
        vm.deal(bob,   1_000 ether);

        pc     = new PointsController(admin);
        router = new StrategyRouter(admin, address(0));

        vault = new SomniaVault(
            "SomETH Vault",
            "sSOM",
            admin,
            LOCK7D,
            0,
            treasury,
            address(router),
            address(pc),
            0
        );

        vm.startPrank(admin);           // satu batch
        router.setVault(address(vault));
        adapter = new SimpleHoldingAdapter(admin, address(router));
        router.addAdapter(address(adapter), 10_000);

        bytes32[] memory srcs = new bytes32[](2);
        srcs[0] = SRC_NETWORK;
        srcs[1] = SRC_ECOSYS;
        pc.registerSources(address(vault), srcs);
        pc.setBaseRate(address(vault), SRC_NETWORK, 1e16);
        pc.setMultiplier(address(vault), SRC_NETWORK, 2e18);

        vm.stopPrank();
    }
}
