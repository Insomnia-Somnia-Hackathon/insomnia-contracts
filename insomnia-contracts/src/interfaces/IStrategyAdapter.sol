// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface IStrategyAdapter {
/// @notice Called by the StrategyRouter to deposit native SOM into this adapter.
function depositNative() external payable;


/// @notice Withdraw native SOM from the adapter to `receiver`.
/// @param amount Native amount requested (the adapter may withdraw internal positions to fulfill).
/// @param receiver Address to receive native SOM.
function withdrawNative(uint256 amount, address receiver) external;


/// @notice Harvest yield. Must send any native SOM realized back to the caller (router).
/// @return harvestedNative Amount of native SOM realized and returned to caller.
function harvest() external returns (uint256 harvestedNative);


/// @notice Total native SOM managed by this adapter (for TVL accounting).
function totalManagedNative() external view returns (uint256);
}