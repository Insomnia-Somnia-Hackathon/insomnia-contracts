// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


library SafeTransferLibNative {
error NativeTransferFailed();

function safeTransferNative(address to, uint256 amount) internal {
if (amount == 0) return;
(bool ok, ) = to.call{value: amount}("");
if (!ok) revert NativeTransferFailed();
}
}