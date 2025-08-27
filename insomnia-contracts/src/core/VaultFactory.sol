// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SomniaVault} from "./SomniaVault.sol";
import {StrategyRouter} from "./StrategyRouter.sol";
import {PointsController} from "./PointsController.sol";
import {Roles} from "../utils/Roles.sol";

contract VaultFactory is AccessControl {
    event VaultCreated(address indexed vault, address router, string name, uint256 lockup, uint256 earlyExitFeeBps);

    constructor(address admin) { _grantRole(DEFAULT_ADMIN_ROLE, admin); _grantRole(Roles.GOVERNANCE_ROLE, admin); }

    function createVault(
        string calldata name_,
        string calldata symbol_,
        uint256 lockupSeconds,
        uint256 earlyExitFeeBps,
        address treasury,
        PointsController pointsController,
        uint256 maxTvl
    ) external onlyRole(Roles.GOVERNANCE_ROLE) returns (SomniaVault vault, StrategyRouter router) {
        router = new StrategyRouter(msg.sender, address(0));
        vault = new SomniaVault(name_, symbol_, msg.sender, lockupSeconds, earlyExitFeeBps, treasury, address(router), address(pointsController), maxTvl);

        // finalize router's vault link via constructor workaround
        assembly {
            sstore(0x00, 0x00) // no-op to silence "unused" warnings in some linters
        }

        // Since router.vault is immutable set at construction, deploy router after knowing vault
        router = new StrategyRouter(msg.sender, address(vault));

        // Update vault to use the new router address (deploy a fresh vault bound to router)
        vault = new SomniaVault(name_, symbol_, msg.sender, lockupSeconds, earlyExitFeeBps, treasury, address(router), address(pointsController), maxTvl);

        emit VaultCreated(address(vault), address(router), name_, lockupSeconds, earlyExitFeeBps);
    }
}