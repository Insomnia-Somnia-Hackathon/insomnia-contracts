// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStrategyAdapter} from "../interfaces/IStrategyAdapter.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Roles} from "../utils/Roles.sol";
import {SafeTransferLibNative} from "../libs/SafeTransferLibNative.sol";

/// @notice Minimal adapter that simply holds native SOM. Good for testing and baseline behavior.
contract SimpleHoldingAdapter is IStrategyAdapter, AccessControl {
    using SafeTransferLibNative for address;

    address public immutable ROUTER; // only StrategyRouter can orchestrate this adapter

    modifier onlyRouter() { require(msg.sender == ROUTER, "NOT_ROUTER"); _; }

    constructor(address _admin, address _router) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(Roles.GOVERNANCE_ROLE, _admin);
        ROUTER = _router;
    }

    receive() external payable {}

    function depositNative() external payable onlyRouter {}

    function withdrawNative(uint256 amount, address receiver) external onlyRouter {
        address(receiver).safeTransferNative(amount);
    }

    function harvest() external onlyRouter returns (uint256 harvestedNative) {
        // No external yield. Any stray native here is considered harvested.
        harvestedNative = address(this).balance;
        if (harvestedNative > 0) address(msg.sender).safeTransferNative(harvestedNative);
    }

    function totalManagedNative() external view returns (uint256) { return address(this).balance; }
}