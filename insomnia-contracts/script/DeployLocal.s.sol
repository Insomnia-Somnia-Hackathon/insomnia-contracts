// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Script.sol";
// import {VaultFactory} from "../src/core/VaultFactory.sol";
// import {PointsController} from "../src/core/PointsController.sol";


// contract DeployLocal is Script {
// function run() external {
// vm.startBroadcast();
// PointsController pc = new PointsController(msg.sender);
// VaultFactory vf = new VaultFactory(msg.sender);
// console2.log("PointsController:", address(pc));
// console2.log("VaultFactory:", address(vf));
// vm.stopBroadcast();
// }
// }