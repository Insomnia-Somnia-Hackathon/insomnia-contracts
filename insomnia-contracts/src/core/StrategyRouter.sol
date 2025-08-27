// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IStrategyAdapter} from "../interfaces/IStrategyAdapter.sol";
import {SafeTransferLibNative} from "../libs/SafeTransferLibNative.sol";
import {Roles} from "../utils/Roles.sol";

/// @notice Holds no business logic beyond allocation, harvest, and unwind orchestration.
contract StrategyRouter is AccessControl, ReentrancyGuard, Pausable {
    using SafeTransferLibNative for address;

    address public immutable VAULT; // the sole vault allowed to push/pull funds

    struct AdapterInfo { IStrategyAdapter adapter; uint16 weightBps; }
    AdapterInfo[] public adapters;
    uint16 public constant BPS_DENOM = 10_000;

    event AdapterAdded(address adapter, uint16 weightBps);
    event AdapterWeightUpdated(uint256 indexed id, uint16 weightBps);
    event Allocated(uint256 amount);
    event Unwound(uint256 requested, uint256 returned);
    event Harvested(address adapter, uint256 harvestedNative);

    modifier onlyVault() { require(msg.sender == VAULT, "NOT_VAULT"); _; }

    constructor(address _admin, address _vault) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(Roles.GOVERNANCE_ROLE, _admin);
        VAULT = _vault;
    }

    receive() external payable {}

    function addAdapter(address adapter, uint16 weightBps) external onlyRole(Roles.GOVERNANCE_ROLE) {
        require(adapter != address(0), "adapter=0");
        adapters.push(AdapterInfo(IStrategyAdapter(adapter), weightBps));
        _validateWeights();
        emit AdapterAdded(adapter, weightBps);
    }

    function setAdapterWeight(uint256 id, uint16 weightBps) external onlyRole(Roles.GOVERNANCE_ROLE) {
        require(id < adapters.length, "id");
        adapters[id].weightBps = weightBps;
        _validateWeights();
        emit AdapterWeightUpdated(id, weightBps);
    }

    function _validateWeights() internal view {
        uint256 sum;
        for (uint256 i; i < adapters.length; i++) sum += adapters[i].weightBps;
        require(sum == BPS_DENOM || adapters.length == 0, "weights!=100%" );
    }

    // === Allocation ===

    /// @notice Called by vault to allocate native SOM held by the router to adapters by weights.
    function allocate() external onlyVault nonReentrant whenNotPaused {
        uint256 bal = address(this).balance;
        require(bal > 0, "no-funds");
        for (uint256 i; i < adapters.length; i++) {
            uint256 portion = (bal * adapters[i].weightBps) / BPS_DENOM;
            if (portion == 0) continue;
            adapters[i].adapter.depositNative{value: portion}();
        }
        emit Allocated(bal);
    }

    /// @notice Called by vault to unwind liquidity from adapters back to vault.
    function unwind(uint256 amount, address receiver) external onlyVault nonReentrant whenNotPaused returns (uint256 returned) {
        uint256 needed = amount;
        for (uint256 i; i < adapters.length && needed > 0; i++) {
            uint256 tvl = adapters[i].adapter.totalManagedNative();
            uint256 pull = tvl < needed ? tvl : needed;
            if (pull == 0) continue;
            adapters[i].adapter.withdrawNative(pull, address(this));
            needed -= pull;
        }
        returned = address(this).balance;
        require(returned >= amount, "shortfall");
        receiver.safeTransferNative(returned);
        emit Unwound(amount, returned);
    }

    // === Harvest ===

    function harvest(uint256 id) external nonReentrant whenNotPaused onlyRole(Roles.KEEPER_ROLE) returns (uint256) {
        require(id < adapters.length, "id");
        uint256 gained = adapters[id].adapter.harvest();
        emit Harvested(address(adapters[id].adapter), gained);
        return gained;
    }

    // === Views ===

    function adaptersLength() external view returns (uint256) { return adapters.length; }

    function totalManagedNative() external view returns (uint256 sum) {
        for (uint256 i; i < adapters.length; i++) sum += adapters[i].adapter.totalManagedNative();
    }
}