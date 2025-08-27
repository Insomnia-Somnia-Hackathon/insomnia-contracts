// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface IPointsController {
/// @notice Register a list of point sources for a given vault.
function registerSources(address vault, bytes32[] calldata sources) external;


/// @notice Set base accrual rate (per second, 1e18 scale) for a source within a vault.
function setBaseRate(address vault, bytes32 source, uint256 ratePerSec) external;


/// @notice Set multiplier (1e18 scale) for a source within a vault.
function setMultiplier(address vault, bytes32 source, uint256 multiplier) external;


/// @notice Update global indices for a vault (optionally passing explicit sources to update).
function poke(address vault, bytes32[] calldata sources) external;


/// @notice Accumulate user points up to now using current global indices.
function accumulate(address vault, address user) external;


/// @notice Set user index baseline to current global indices after share changes.
function updateUserIndex(address vault, address user) external;


/// @notice Preview total & per-source points for a user.
function preview(address vault, address user) external view returns (uint256 total, bytes32[] memory sources, uint256[] memory perSource);
}