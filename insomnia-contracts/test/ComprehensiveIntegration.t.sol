// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {VaultFactory} from "../src/core/VaultFactory.sol";
import {SomniaVault} from "../src/core/SomniaVault.sol";
import {StrategyRouter} from "../src/core/StrategyRouter.sol";
import {PointsController} from "../src/core/PointsController.sol";
import {SimpleHoldingAdapter} from "../src/adapters/SimpleHoldingAdapter.sol";
import {IStrategyAdapter} from "../src/interfaces/IStrategyAdapter.sol";
import {Roles} from "../src/utils/Roles.sol";

/**
 * @title ComprehensiveIntegration Test
 * @dev Complete integration test following CLAUDE.md instructions
 * @dev Tests full deployment and operation flow using VaultFactory
 */
contract ComprehensiveIntegrationTest is Test {
    // Test actors
    address internal admin = address(0x1);
    address internal treasury = address(0x2);
    address internal user = address(0x3);
    address internal keeper = address(0x4);

    // Core contracts
    VaultFactory internal vaultFactory;
    PointsController internal pointsController;
    SomniaVault internal vault;
    StrategyRouter internal router;
    SimpleHoldingAdapter internal adapter;

    // Constants
    uint256 internal constant LOCKUP_SECONDS = 7 days;
    uint256 internal constant EARLY_EXIT_FEE_BPS = 0;
    uint256 internal constant MAX_TVL = 0; // Unlimited
    
    // Point sources
    bytes32 internal constant SRC_SOMNIA_NETWORK = keccak256("SOMNIA_NETWORK");
    bytes32 internal constant SRC_ECOSYSTEM = keccak256("ECOSYSTEM");
    
    // Role hashes
    bytes32 internal constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 internal constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    event VaultCreated(address indexed vault, address router, string name, uint256 lockup, uint256 earlyExitFeeBps);

    function setUp() public {
        // Setup test actors with funds
        vm.deal(admin, 1000 ether);
        vm.deal(user, 1000 ether);
        vm.deal(keeper, 1000 ether);
        vm.deal(treasury, 1000 ether);
    }

    /**
     * @dev Test A: Deploy PointsController
     */
    function test_A_DeployPointsController() public {
        vm.startPrank(admin);
        
        // Deploy PointsController with admin
        pointsController = new PointsController(admin);
        
        // Verify admin has correct roles
        assertTrue(pointsController.hasRole(pointsController.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pointsController.hasRole(GOVERNANCE_ROLE, admin));
        
        console2.log("[PASS] PointsController deployed:", address(pointsController));
        vm.stopPrank();
    }

    /**
     * @dev Test B: Deploy VaultFactory
     */
    function test_B_DeployVaultFactory() public {
        vm.startPrank(admin);
        
        // Deploy VaultFactory with admin
        vaultFactory = new VaultFactory(admin);
        
        // Verify admin has correct roles
        assertTrue(vaultFactory.hasRole(vaultFactory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vaultFactory.hasRole(GOVERNANCE_ROLE, admin));
        
        console2.log("[PASS] VaultFactory deployed:", address(vaultFactory));
        vm.stopPrank();
    }

    /**
     * @dev Test C: Create Vault via VaultFactory
     */
    function test_C_CreateVaultViaFactory() public {
        // Setup prerequisites
        test_A_DeployPointsController();
        test_B_DeployVaultFactory();
        
        vm.startPrank(admin);
        
        // Expect VaultCreated event
        vm.expectEmit(true, false, false, true);
        emit VaultCreated(address(0), address(0), "SomETH Vault", LOCKUP_SECONDS, EARLY_EXIT_FEE_BPS);
        
        // Create vault via factory
        (SomniaVault _vault, StrategyRouter _router) = vaultFactory.createVault(
            "SomETH Vault",           // name
            "sSOM",                   // symbol
            LOCKUP_SECONDS,           // lockupSeconds (7 days)
            EARLY_EXIT_FEE_BPS,       // earlyExitFeeBps (no penalty)
            treasury,                 // treasury
            pointsController,         // pointsController
            MAX_TVL                   // maxTvl (unlimited)
        );
        
        vault = _vault;
        router = _router;
        
        // Verify vault configuration
        assertEq(vault.name(), "SomETH Vault");
        assertEq(vault.symbol(), "sSOM");
        assertEq(vault.LOCKUP_SECONDS(), LOCKUP_SECONDS);
        assertEq(vault.EARLY_EXIT_FEE_BPS(), EARLY_EXIT_FEE_BPS);
        assertEq(vault.TREASURY(), treasury);
        assertEq(vault.ROUTER(), address(router));
        assertEq(vault.POINTS_CONTROLLER(), address(pointsController));
        assertEq(vault.maxTvl(), MAX_TVL);
        
        // Verify router configuration
        assertEq(router.VAULT(), address(vault));
        
        // Verify cross-linking
        assertEq(vault.ROUTER(), address(router));
        assertEq(router.VAULT(), address(vault));
        
        console2.log("[PASS] Vault deployed:", address(vault));
        console2.log("[PASS] Router deployed:", address(router));
        console2.log("[PASS] Cross-linking verified");
        
        vm.stopPrank();
    }

    /**
     * @dev Test D: Deploy SimpleHoldingAdapter
     */
    function test_D_DeploySimpleHoldingAdapter() public {
        // Setup prerequisites
        test_C_CreateVaultViaFactory();
        
        vm.startPrank(admin);
        
        // Deploy adapter
        adapter = new SimpleHoldingAdapter(admin, address(router));
        
        // Verify adapter configuration
        assertEq(adapter.ROUTER(), address(router));
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(adapter.hasRole(GOVERNANCE_ROLE, admin));
        
        console2.log("[PASS] SimpleHoldingAdapter deployed:", address(adapter));
        
        vm.stopPrank();
    }

    /**
     * @dev Test Step 4A: Setup StrategyRouter
     */
    function test_4A_SetupStrategyRouter() public {
        // Setup prerequisites
        test_D_DeploySimpleHoldingAdapter();
        
        vm.startPrank(admin);
        
        // Add adapter with 100% weight
        router.addAdapter(address(adapter), 10000);
        
        // Verify adapter setup
        assertEq(router.adaptersLength(), 1);
        
        // Note: adapters() returns (IStrategyAdapter, uint16) so we need to unpack properly
        (IStrategyAdapter adapterInterface, uint16 weightBps) = router.adapters(0);
        assertEq(address(adapterInterface), address(adapter));
        assertEq(weightBps, 10000);
        
        console2.log("[PASS] Adapter added with 100% weight");
        
        vm.stopPrank();
    }

    /**
     * @dev Test Step 4B: Setup PointsController
     */
    function test_4B_SetupPointsController() public {
        // Setup prerequisites
        test_4A_SetupStrategyRouter();
        
        vm.startPrank(admin);
        
        // 1. Register Sources
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = SRC_SOMNIA_NETWORK;
        sources[1] = SRC_ECOSYSTEM;
        
        pointsController.registerSources(address(vault), sources);
        
        // Verify sources registered by checking sourceData exists
        (,,,, bool exists1) = pointsController.sourceData(address(vault), SRC_SOMNIA_NETWORK);
        (,,,, bool exists2) = pointsController.sourceData(address(vault), SRC_ECOSYSTEM);
        assertTrue(exists1);
        assertTrue(exists2);
        
        // 2. Set Base Rate for SOMNIA_NETWORK
        pointsController.setBaseRate(
            address(vault),
            SRC_SOMNIA_NETWORK,
            1e16  // 0.01 per second
        );
        
        // 3. Set Multiplier for SOMNIA_NETWORK  
        pointsController.setMultiplier(
            address(vault),
            SRC_SOMNIA_NETWORK,
            2e18  // 2x multiplier
        );
        
        // Verify configuration
        (uint256 globalIndex, uint256 lastUpdated, uint256 baseRatePerSec, uint256 multiplier, bool exists) = 
            pointsController.sourceData(address(vault), SRC_SOMNIA_NETWORK);
            
        assertEq(baseRatePerSec, 1e16);
        assertEq(multiplier, 2e18);
        assertTrue(exists);
        
        console2.log("[PASS] PointsController configured");
        console2.log("  - Sources registered: 2");
        console2.log("  - Base rate:", baseRatePerSec);
        console2.log("  - Multiplier:", multiplier);
        
        vm.stopPrank();
    }

    /**
     * @dev Test Step 4C: Grant Roles
     */
    function test_4C_GrantRoles() public {
        // Setup prerequisites
        test_4B_SetupPointsController();
        
        vm.startPrank(admin);
        
        // Grant KEEPER_ROLE to admin for testing
        vault.grantRole(KEEPER_ROLE, admin);
        
        // Also grant to dedicated keeper for realistic testing
        vault.grantRole(KEEPER_ROLE, keeper);
        
        // Verify roles
        assertTrue(vault.hasRole(KEEPER_ROLE, admin));
        assertTrue(vault.hasRole(KEEPER_ROLE, keeper));
        
        console2.log("[PASS] KEEPER_ROLE granted to admin and keeper");
        
        vm.stopPrank();
    }

    /**
     * @dev Test 1: Deposit
     */
    function test_1_Deposit() public {
        // Setup prerequisites
        test_4C_GrantRoles();
        
        uint256 depositAmount = 1 ether;
        uint256 userBalanceBefore = user.balance;
        
        vm.startPrank(user);
        
        // Deposit 1 ETH
        vault.depositNative{value: depositAmount}(user);
        
        // Verify deposit results
        assertEq(vault.balanceOf(user), depositAmount); // 1:1 ratio for first deposit
        assertEq(vault.totalSupply(), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(address(vault).balance, depositAmount);
        assertEq(user.balance, userBalanceBefore - depositAmount);
        
        // Verify lockup set
        assertGt(vault.unlockAt(user), block.timestamp);
        assertEq(vault.unlockAt(user), block.timestamp + LOCKUP_SECONDS);
        
        console2.log("[PASS] User deposited:", depositAmount);
        console2.log("  - Shares received:", vault.balanceOf(user));
        console2.log("  - Unlock time:", vault.unlockAt(user));
        
        vm.stopPrank();
    }

    /**
     * @dev Test 2: Check Balances
     */
    function test_2_CheckBalances() public {
        // Setup prerequisites
        test_1_Deposit();
        
        uint256 userShares = vault.balanceOf(user);
        uint256 totalAssets = vault.totalAssets();
        uint256 vaultBalance = address(vault).balance;
        
        // Log current state
        console2.log("[PASS] Balance Check:");
        console2.log("  - User shares:", userShares);
        console2.log("  - Total assets:", totalAssets);
        console2.log("  - Vault balance:", vaultBalance);
        
        // Verify consistency
        assertEq(userShares, 1 ether);
        assertEq(totalAssets, 1 ether);
        assertEq(vaultBalance, 1 ether);
        assertEq(totalAssets, vaultBalance); // No funds allocated yet
    }

    /**
     * @dev Test 3: Push to Router
     */
    function test_3_PushToRouter() public {
        // Setup prerequisites
        test_2_CheckBalances();
        
        uint256 totalAssets = vault.totalAssets();
        
        vm.startPrank(admin); // Admin has KEEPER_ROLE
        
        // Push all funds to router
        vault.pushToRouter(totalAssets);
        
        // Verify funds moved
        assertEq(address(vault).balance, 0);
        assertEq(address(router).balance, totalAssets);
        assertEq(vault.totalAssets(), totalAssets); // Total assets unchanged (vault + managed)
        
        console2.log("[PASS] Pushed to router:", totalAssets);
        console2.log("  - Vault balance:", address(vault).balance);
        console2.log("  - Router balance:", address(router).balance);
        console2.log("  - Total assets:", vault.totalAssets());
        
        vm.stopPrank();
    }

    /**
     * @dev Test 4: Allocate to Strategy
     */
    function test_4_AllocateToStrategy() public {
        // Setup prerequisites
        test_3_PushToRouter();
        
        uint256 routerBalanceBefore = address(router).balance;
        
        vm.startPrank(admin); // Admin has KEEPER_ROLE
        
        // Allocate funds to strategies
        vault.allocate();
        
        // Verify allocation results
        assertEq(address(router).balance, 0); // Router should be empty
        assertEq(address(adapter).balance, routerBalanceBefore); // Funds moved to adapter
        assertEq(adapter.totalManagedNative(), routerBalanceBefore);
        assertEq(router.totalManagedNative(), routerBalanceBefore);
        assertEq(vault.totalAssets(), routerBalanceBefore); // Total unchanged
        
        console2.log("[PASS] Allocated to strategy:", routerBalanceBefore);
        console2.log("  - Router balance:", address(router).balance);
        console2.log("  - Adapter balance:", address(adapter).balance);
        console2.log("  - Total managed:", router.totalManagedNative());
        
        vm.stopPrank();
    }

    /**
     * @dev Test 5: Points Accumulation
     */
    function test_5_PointsAccumulation() public {
        // Setup prerequisites
        test_4_AllocateToStrategy();
        
        // Simulate time passage (2 hours)
        uint256 timeElapsed = 2 hours;
        vm.warp(block.timestamp + timeElapsed);
        
        vm.startPrank(admin);
        
        // Poke to update global indices
        bytes32[] memory sources = new bytes32[](0); // Empty array = all sources
        pointsController.poke(address(vault), sources);
        
        // Accumulate points for user
        pointsController.accumulate(address(vault), user);
        
        // Check points earned
        (uint256 totalPoints, bytes32[] memory srcs, uint256[] memory perSource) = 
            pointsController.preview(address(vault), user);
        
        // Verify points accumulated
        assertGt(totalPoints, 0);
        assertEq(srcs.length, 2);
        assertGt(perSource[0], 0); // SOMNIA_NETWORK should have points
        
        console2.log("[PASS] Points accumulated after", timeElapsed, "seconds:");
        console2.log("  - Total points:", totalPoints);
        console2.log("  - SOMNIA_NETWORK points:", perSource[0]);
        console2.log("  - ECOSYSTEM points:", perSource[1]);
        
        vm.stopPrank();
    }

    /**
     * @dev Test 6: Withdraw (Fast-forward past lockup)
     */
    function test_6_Withdraw() public {
        // Setup prerequisites  
        test_5_PointsAccumulation();
        
        // Fast-forward past lockup period
        vm.warp(block.timestamp + LOCKUP_SECONDS + 1);
        
        uint256 userShares = vault.balanceOf(user);
        uint256 userBalanceBefore = user.balance;
        uint256 expectedAmount = vault.previewWithdraw(userShares);
        
        vm.startPrank(user);
        
        // Withdraw all shares
        vault.withdraw(userShares, payable(user));
        
        // Verify withdrawal results
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.totalSupply(), 0);
        assertApproxEqAbs(user.balance, userBalanceBefore + expectedAmount, 1);
        
        // Check points are still there
        (uint256 totalPoints,,) = pointsController.preview(address(vault), user);
        assertGt(totalPoints, 0);
        
        console2.log("[PASS] User withdrawn:", expectedAmount);
        console2.log("  - Final balance:", user.balance);
        console2.log("  - Remaining shares:", vault.balanceOf(user));
        console2.log("  - Points retained:", totalPoints);
        
        vm.stopPrank();
    }

    /**
     * @dev Comprehensive integration test running all steps in sequence
     */
    function testComprehensiveFlow() public {
        console2.log("=== COMPREHENSIVE INTEGRATION TEST ===");
        
        // Step A: Deploy PointsController
        vm.startPrank(admin);
        pointsController = new PointsController(admin);
        console2.log("[PASS] PointsController deployed:", address(pointsController));
        vm.stopPrank();
        
        // Step B: Deploy VaultFactory
        vm.startPrank(admin);
        vaultFactory = new VaultFactory(admin);
        console2.log("[PASS] VaultFactory deployed:", address(vaultFactory));
        vm.stopPrank();
        
        // Step C: Create Vault via Factory
        vm.startPrank(admin);
        (SomniaVault _vault, StrategyRouter _router) = vaultFactory.createVault(
            "SomETH Vault", "sSOM", LOCKUP_SECONDS, EARLY_EXIT_FEE_BPS,
            treasury, pointsController, MAX_TVL
        );
        vault = _vault;
        router = _router;
        console2.log("[PASS] Vault deployed:", address(vault));
        console2.log("[PASS] Router deployed:", address(router));
        
        // Debug: Check linking
        console2.log("Debug - vault.ROUTER():", vault.ROUTER());
        console2.log("Debug - router.VAULT():", router.VAULT());
        console2.log("Debug - Addresses match:", vault.ROUTER() == address(router) && router.VAULT() == address(vault));
        vm.stopPrank();
        
        // Step D: Deploy Adapter
        vm.startPrank(admin);
        adapter = new SimpleHoldingAdapter(admin, address(router));
        console2.log("[PASS] SimpleHoldingAdapter deployed:", address(adapter));
        vm.stopPrank();
        
        // Step 4A: Setup Router
        vm.startPrank(admin);
        router.addAdapter(address(adapter), 10000);
        console2.log("[PASS] Adapter added with 100% weight");
        vm.stopPrank();
        
        // Step 4B: Setup PointsController
        vm.startPrank(admin);
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = SRC_SOMNIA_NETWORK;
        sources[1] = SRC_ECOSYSTEM;
        pointsController.registerSources(address(vault), sources);
        pointsController.setBaseRate(address(vault), SRC_SOMNIA_NETWORK, 1e16);
        pointsController.setMultiplier(address(vault), SRC_SOMNIA_NETWORK, 2e18);
        console2.log("[PASS] PointsController configured");
        vm.stopPrank();
        
        // Step 4C: Grant Roles
        vm.startPrank(admin);
        vault.grantRole(KEEPER_ROLE, admin);
        console2.log("[PASS] KEEPER_ROLE granted");
        vm.stopPrank();
        
        // Test 1: Deposit
        vm.startPrank(user);
        vault.depositNative{value: 1 ether}(user);
        console2.log("[PASS] User deposited 1 ETH");
        vm.stopPrank();
        
        // Test 3: Push to Router
        vm.startPrank(admin);
        vault.pushToRouter(vault.totalAssets());
        console2.log("[PASS] Funds pushed to router");
        vm.stopPrank();
        
        // Test 4: Allocate
        vm.startPrank(admin);
        vault.allocate();
        console2.log("[PASS] Funds allocated to strategy");
        vm.stopPrank();
        
        // Test 5: Points
        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(admin);
        bytes32[] memory emptySources = new bytes32[](0);
        pointsController.poke(address(vault), emptySources);
        pointsController.accumulate(address(vault), user);
        console2.log("[PASS] Points accumulated");
        vm.stopPrank();
        
        // Test 6: Withdraw
        vm.warp(block.timestamp + LOCKUP_SECONDS + 1);
        vm.startPrank(user);
        uint256 userShares = vault.balanceOf(user);
        vault.withdraw(userShares, payable(user));
        console2.log("[PASS] User withdrawn");
        vm.stopPrank();
        
        console2.log("=== ALL TESTS PASSED ===");
    }

    /**
     * @dev Test error cases
     */
    function testErrorCases() public {
        test_4C_GrantRoles();
        
        // Test deposit with zero amount
        vm.startPrank(user);
        vm.expectRevert("amount");
        vault.depositNative{value: 0}(user);
        
        // Test withdraw without shares
        vm.expectRevert(); // ERC20: burn amount exceeds balance
        vault.withdraw(1 ether, payable(user));
        vm.stopPrank();
        
        // Test allocate without KEEPER_ROLE
        vm.startPrank(user);
        vm.expectRevert();
        vault.allocate();
        vm.stopPrank();
        
        // Test pushToRouter without KEEPER_ROLE
        vm.startPrank(user);
        vm.expectRevert();
        vault.pushToRouter(1 ether);
        vm.stopPrank();
        
        console2.log("[PASS] Error cases handled correctly");
    }
}