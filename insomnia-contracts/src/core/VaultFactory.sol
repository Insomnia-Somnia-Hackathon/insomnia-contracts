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
        // Deploy router first with vault = address(0), but give factory governance role
        router = new StrategyRouter(address(this), address(0));
        
        // Deploy vault with router address
        vault = new SomniaVault(name_, symbol_, msg.sender, lockupSeconds, earlyExitFeeBps, treasury, address(router), address(pointsController), maxTvl);

        // Set vault address in router (factory has governance role)
        router.setVault(address(vault));
        
        // Transfer router admin to actual admin
        router.grantRole(router.DEFAULT_ADMIN_ROLE(), msg.sender);
        router.grantRole(Roles.GOVERNANCE_ROLE, msg.sender);
        router.renounceRole(router.DEFAULT_ADMIN_ROLE(), address(this));
        router.renounceRole(Roles.GOVERNANCE_ROLE, address(this));

        emit VaultCreated(address(vault), address(router), name_, lockupSeconds, earlyExitFeeBps);
    }
}