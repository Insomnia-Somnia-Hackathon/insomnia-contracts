// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Roles} from "../utils/Roles.sol";

/// @notice Per-vault, per-source index accrual controller for airdrop points.
contract PointsController is AccessControl {
    uint256 internal constant ONE = 1e18; // scale for rates/multipliers

    struct SourceData {
        uint256 globalIndex;     // cumulative index (1e18 scale)
        uint256 lastUpdated;     // last timestamp index updated
        uint256 baseRatePerSec;  // 1e18 scale
        uint256 multiplier;      // 1e18 scale (e.g., 1e18 = 1x, 2e18 = 2x)
        bool exists;
    }

    // vault => list of sources
    mapping(address => bytes32[]) public sourcesOf;

    // vault => source => SourceData
    mapping(address => mapping(bytes32 => SourceData)) public sourceData;

    // vault => user => source => userIndex
    mapping(address => mapping(address => mapping(bytes32 => uint256))) public userIndex;

    // vault => user => total points per source
    mapping(address => mapping(address => mapping(bytes32 => uint256))) public userPoints;

    event SourceRegistered(address indexed vault, bytes32 indexed source);
    event BaseRateSet(address indexed vault, bytes32 indexed source, uint256 rate);
    event MultiplierSet(address indexed vault, bytes32 indexed source, uint256 m);
    event IndexUpdated(address indexed vault, bytes32 indexed source, uint256 newIndex);
    event PointsAccrued(address indexed vault, address indexed user, bytes32 indexed source, uint256 delta, uint256 total);

    modifier onlyGov() { _checkRole(Roles.GOVERNANCE_ROLE, msg.sender); _; }

    constructor(address admin) { _grantRole(DEFAULT_ADMIN_ROLE, admin); _grantRole(Roles.GOVERNANCE_ROLE, admin); }

    // === Config ===

    function registerSources(address vault, bytes32[] calldata srcs) external onlyGov {
        for (uint256 i; i < srcs.length; i++) {
            bytes32 s = srcs[i];
            if (!sourceData[vault][s].exists) {
                sourceData[vault][s] = SourceData({globalIndex: 0, lastUpdated: block.timestamp, baseRatePerSec: 0, multiplier: ONE, exists: true});
                sourcesOf[vault].push(s);
                emit SourceRegistered(vault, s);
            }
        }
    }

    function setBaseRate(address vault, bytes32 source, uint256 ratePerSec) external onlyGov {
        SourceData storage sd = sourceData[vault][source];
        require(sd.exists, "source");
        _updateIndex(sd);
        sd.baseRatePerSec = ratePerSec; // 1e18 scale
        emit BaseRateSet(vault, source, ratePerSec);
    }

    function setMultiplier(address vault, bytes32 source, uint256 m) external onlyGov {
        SourceData storage sd = sourceData[vault][source];
        require(sd.exists, "source");
        _updateIndex(sd);
        sd.multiplier = m; // 1e18 scale
        emit MultiplierSet(vault, source, m);
    }

    // === Accrual ===

    function poke(address vault, bytes32[] calldata srcs) external {
        if (srcs.length == 0) {
            bytes32[] storage list = sourcesOf[vault];
            for (uint256 i; i < list.length; i++) _updateAndEmit(vault, list[i]);
        } else {
            for (uint256 i; i < srcs.length; i++) _updateAndEmit(vault, srcs[i]);
        }
    }

    function accumulate(address vault, address user) external {
        bytes32[] storage list = sourcesOf[vault];
        for (uint256 i; i < list.length; i++) {
            bytes32 s = list[i];
            SourceData storage sd = sourceData[vault][s];
            _updateIndex(sd);
            if (sd.globalIndex > userIndex[vault][user][s]) {
                // NOTE: caller must ensure msg.sender has access to user's current shares
                uint256 shares = _getShares(vault, user);
                uint256 delta = (shares * (sd.globalIndex - userIndex[vault][user][s])) / ONE;
                if (delta > 0) {
                    uint256 newTotal = userPoints[vault][user][s] + delta;
                    userPoints[vault][user][s] = newTotal;
                    emit PointsAccrued(vault, user, s, delta, newTotal);
                }
            }
        }
    }

    function updateUserIndex(address vault, address user) external {
        bytes32[] storage list = sourcesOf[vault];
        for (uint256 i; i < list.length; i++) {
            bytes32 s = list[i];
            SourceData storage sd = sourceData[vault][s];
            _updateIndex(sd);
            userIndex[vault][user][s] = sd.globalIndex;
        }
    }

    function preview(address vault, address user) external view returns (uint256 total, bytes32[] memory srcs, uint256[] memory perSource) {
        srcs = sourcesOf[vault];
        perSource = new uint256[](srcs.length);
        for (uint256 i; i < srcs.length; i++) {
            perSource[i] = userPoints[vault][user][srcs[i]];
            total += perSource[i];
        }
    }

    // === Internal ===

    function _updateAndEmit(address vault, bytes32 source) internal {
        SourceData storage sd = sourceData[vault][source];
        _updateIndex(sd);
        emit IndexUpdated(vault, source, sd.globalIndex);
    }

    function _updateIndex(SourceData storage sd) internal {
        uint256 t = block.timestamp;
        uint256 dt = t - sd.lastUpdated;
        if (dt == 0) return;
        sd.lastUpdated = t;
        if (sd.baseRatePerSec == 0) return;
        uint256 acc = (sd.baseRatePerSec * sd.multiplier * dt) / ONE;
        sd.globalIndex += acc; // 1e18 scale index
    }

    function _getShares(address vault, address user) internal view returns (uint256 shares) {
        // minimal interface to read ERC20 shares from the vault
        (bool ok, bytes memory data) = vault.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        require(ok && data.length >= 32, "shares-call");
        shares = abi.decode(data, (uint256));
    }
}