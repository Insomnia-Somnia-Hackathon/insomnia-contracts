// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {VaultFactory} from "../src/core/VaultFactory.sol";
import {PointsController} from "../src/core/PointsController.sol";

// Jika pakai AccessControl dan ada KEEPER_ROLE:
bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

contract DeploySomnia is Script {
    using stdJson for string;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");

        // KEEPER opsional
        address keeper;
        try this._envAddress("KEEPER") returns (address k) { keeper = k; } catch {}

        console2.log("Owner :", owner);
        if (keeper != address(0)) console2.log("Keeper:", keeper);

        vm.startBroadcast(pk);

        PointsController pc = new PointsController(owner);
        VaultFactory vf = new VaultFactory(owner);

        console2.log("PointsController:", address(pc));
        console2.log("VaultFactory    :", address(vf));

        // (Opsional) grant role bila kontrakmu pakai AccessControl
        if (keeper != address(0)) {
            try pc.grantRole(KEEPER_ROLE, keeper) { console2.log("Granted KEEPER on PC"); } catch {}
            try vf.grantRole(KEEPER_ROLE, keeper) { console2.log("Granted KEEPER on VF"); } catch {}
        }

        vm.stopBroadcast();
    }

    function _envAddress(string memory key) external view returns (address) {
        return vm.envAddress(key);
    }
}
