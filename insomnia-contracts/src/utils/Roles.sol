// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


library Roles {
bytes32 internal constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
bytes32 internal constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
bytes32 internal constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
}