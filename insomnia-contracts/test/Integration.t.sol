// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Roles} from "../src/utils/Roles.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {SomniaTestBase} from "./TestBase.t.sol";

contract IntegrationTest is SomniaTestBase {
    function testEndToEnd_Deposit_Accrue_Allocate_Withdraw() public {
    // 1) Siapkan role di vault & pc
    vm.startPrank(admin);
    vault.grantRole(Roles.KEEPER_ROLE, admin);
    // beri hak ke admin (boleh juga ke address(this) bila mau memanggil tanpa prank)
    pc.grantRole(Roles.KEEPER_ROLE, admin);
    vm.stopPrank();

    console2.log("vault.hasRole(KEEPER, admin):", vault.hasRole(Roles.KEEPER_ROLE, admin));
    console2.log("pc.hasRole(KEEPER, admin):", pc.hasRole(Roles.KEEPER_ROLE, admin));

    // 2) Deposit oleh alice
    vm.prank(alice);
    vault.depositNative{value: 12 ether}(alice);

    // 3) Accrue poin/rewards via pc (harus dari akun ber-role KEEPER di pc)
    vm.warp(block.timestamp + 2 hours);
    bytes32[] memory data = new bytes32[](1);
    data[0] = bytes32(0);

    vm.startPrank(admin);              // admin sudah KEEPER di pc
    pc.poke(address(vault), data);
    pc.accumulate(address(vault), alice);
    vm.stopPrank();

    // 4) Allocate via vault (admin punya KEEPER di vault)
    vm.startPrank(admin);
    vault.pushToRouter(vault.totalAssets());
    vault.allocate();
    vm.stopPrank();
    assertGt(router.totalManagedNative(), 0);

    // 5) Tarik balik ke vault untuk siap withdraw
    vm.prank(admin);
    vault.pullFromRouter(10 ether);
    assertGe(address(vault).balance, 10 ether);

    // 6) Tunggu lock berakhir lalu withdraw
    vm.warp(block.timestamp + 7 days + 1);
    uint256 shares = vault.balanceOf(alice);
    vm.prank(alice);
    vault.withdraw(shares, payable(alice));

    assertEq(vault.balanceOf(alice), 0);
    (uint256 total,,) = pc.preview(address(vault), alice);
    assertGt(total, 0);
}
}
