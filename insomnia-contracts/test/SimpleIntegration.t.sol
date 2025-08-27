// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {SomniaVault} from "../src/core/SomniaVault.sol";
import {StrategyRouter} from "../src/core/StrategyRouter.sol";
import {PointsController} from "../src/core/PointsController.sol";
import {SimpleHoldingAdapter} from "../src/adapters/SimpleHoldingAdapter.sol";
import {IStrategyAdapter} from "../src/interfaces/IStrategyAdapter.sol";
import {Roles} from "../src/utils/Roles.sol";

/**
 * @title Simple Integration Test
 * @dev Test the manual deployment approach that works correctly
 */
contract SimpleIntegrationTest is Test {
    // Test actors
    address internal admin = address(0x1);
    address internal treasury = address(0x2);
    address internal user = address(0x3);

    // Core contracts
    PointsController internal pointsController;
    SomniaVault internal vault;
    StrategyRouter internal router;
    SimpleHoldingAdapter internal adapter;

    // Constants
    uint256 internal constant LOCKUP_SECONDS = 7 days;
    uint256 internal constant EARLY_EXIT_FEE_BPS = 0;
    uint256 internal constant MAX_TVL = 0;
    
    // Point sources
    bytes32 internal constant SRC_SOMNIA_NETWORK = keccak256("SOMNIA_NETWORK");
    bytes32 internal constant SRC_ECOSYSTEM = keccak256("ECOSYSTEM");
    
    // Role hashes
    bytes32 internal constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 internal constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    function setUp() public {
        vm.deal(admin, 1000 ether);
        vm.deal(user, 1000 ether);
        vm.deal(treasury, 1000 ether);
    }

    /**
     * @dev Test manual deployment that follows the working pattern
     */
    function testManualDeploymentFlow() public {
        console2.log("=== MANUAL DEPLOYMENT TEST ===");
        
        // Step 1: Deploy PointsController
        vm.startPrank(admin);
        pointsController = new PointsController(admin);
        console2.log("[PASS] PointsController deployed:", address(pointsController));
        vm.stopPrank();
        
        // Step 2: Deploy StrategyRouter with vault = address(0)
        vm.startPrank(admin);
        router = new StrategyRouter(admin, address(0));
        console2.log("[PASS] StrategyRouter deployed:", address(router));
        console2.log("Debug - router.VAULT() initial:", router.VAULT());
        vm.stopPrank();
        
        // Step 3: Deploy SomniaVault with router address
        vm.startPrank(admin);
        vault = new SomniaVault(
            "SomETH Vault", "sSOM", admin, LOCKUP_SECONDS, EARLY_EXIT_FEE_BPS,
            treasury, address(router), address(pointsController), MAX_TVL
        );
        console2.log("[PASS] SomniaVault deployed:", address(vault));
        console2.log("Debug - vault.ROUTER():", vault.ROUTER());
        vm.stopPrank();
        
        // Step 4: Set vault in router (ONE TIME ONLY!)
        vm.startPrank(admin);
        router.setVault(address(vault));
        console2.log("[PASS] Router vault set");
        console2.log("Debug - router.VAULT() after set:", router.VAULT());
        vm.stopPrank();
        
        // Step 5: Verify linking
        bool linked = vault.ROUTER() == address(router) && router.VAULT() == address(vault);
        console2.log("Debug - Properly linked:", linked);
        assertTrue(linked, "Vault and router should be properly linked");
        
        // Step 6: Deploy and setup adapter
        vm.startPrank(admin);
        adapter = new SimpleHoldingAdapter(admin, address(router));
        router.addAdapter(address(adapter), 10000);
        console2.log("[PASS] Adapter deployed and added");
        vm.stopPrank();
        
        // Step 7: Setup PointsController
        vm.startPrank(admin);
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = SRC_SOMNIA_NETWORK;
        sources[1] = SRC_ECOSYSTEM;
        pointsController.registerSources(address(vault), sources);
        pointsController.setBaseRate(address(vault), SRC_SOMNIA_NETWORK, 1e16);
        pointsController.setMultiplier(address(vault), SRC_SOMNIA_NETWORK, 2e18);
        console2.log("[PASS] PointsController configured");
        vm.stopPrank();
        
        // Step 8: Grant roles
        vm.startPrank(admin);
        vault.grantRole(KEEPER_ROLE, admin);
        console2.log("[PASS] KEEPER_ROLE granted");
        vm.stopPrank();
        
        // Step 9: Test full flow
        console2.log("=== TESTING FLOW ===");
        
        // Deposit
        vm.startPrank(user);
        vault.depositNative{value: 1 ether}(user);
        console2.log("[PASS] User deposited 1 ETH");
        console2.log("  - User shares:", vault.balanceOf(user));
        console2.log("  - Vault balance:", address(vault).balance);
        vm.stopPrank();
        
        // Push to router
        vm.startPrank(admin);
        vault.pushToRouter(vault.totalAssets());
        console2.log("[PASS] Funds pushed to router");
        console2.log("  - Vault balance:", address(vault).balance);
        console2.log("  - Router balance:", address(router).balance);
        vm.stopPrank();
        
        // Allocate - THIS SHOULD WORK NOW!
        vm.startPrank(admin);
        vault.allocate();
        console2.log("[PASS] Funds allocated to strategy");
        console2.log("  - Router balance:", address(router).balance);
        console2.log("  - Adapter balance:", address(adapter).balance);
        console2.log("  - Router total managed:", router.totalManagedNative());
        vm.stopPrank();
        
        // Points accumulation
        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(admin);
        bytes32[] memory emptySources = new bytes32[](0);
        pointsController.poke(address(vault), emptySources);
        pointsController.accumulate(address(vault), user);
        (uint256 totalPoints,,) = pointsController.preview(address(vault), user);
        console2.log("[PASS] Points accumulated:", totalPoints);
        vm.stopPrank();
        
        // Withdraw
        vm.warp(block.timestamp + LOCKUP_SECONDS + 1);
        vm.startPrank(user);
        uint256 userShares = vault.balanceOf(user);
        uint256 userBalanceBefore = user.balance;
        vault.withdraw(userShares, payable(user));
        uint256 userBalanceAfter = user.balance;
        console2.log("[PASS] User withdrawn:", userBalanceAfter - userBalanceBefore);
        vm.stopPrank();
        
        console2.log("=== ALL TESTS PASSED ===");
        
        // Final assertions
        assertEq(vault.balanceOf(user), 0, "User should have no shares left");
        assertGt(totalPoints, 0, "User should have accumulated points");
        assertGt(userBalanceAfter, userBalanceBefore, "User should have received funds");
    }
}