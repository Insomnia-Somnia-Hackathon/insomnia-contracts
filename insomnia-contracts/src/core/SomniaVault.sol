// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Roles} from "../utils/Roles.sol";
import {IPointsController} from "../interfaces/IPointsController.sol";
import {SafeTransferLibNative} from "../libs/SafeTransferLibNative.sol";

interface IStrategyRouterLike { function allocate() external; function unwind(uint256 amount, address receiver) external returns (uint256); function totalManagedNative() external view returns (uint256); }

/// @notice ERC4626-like native SOM vault with account-based lock and points accrual hooks.
contract SomniaVault is ERC20, AccessControl, ReentrancyGuard, Pausable {
    using SafeTransferLibNative for address;
    using SafeTransferLibNative for address payable;

    uint256 public immutable LOCKUP_SECONDS;        // e.g., 7d
    uint256 public immutable EARLY_EXIT_FEE_BPS;      // e.g., 0 for normal vault, >0 for Boost vault
    uint256 public constant BPS_DENOM = 10_000;


    address public immutable TREASURY;             // fee sink
    address public immutable ROUTER;               // StrategyRouter
    address public immutable POINTS_CONTROLLER;     // PointsController

    mapping(address => uint256) public unlockAt;   // account-based lock
    uint256 public maxTvl;                         // optional cap (0 = no cap)

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares, uint256 penalty);

    modifier onlyGov() { _checkRole(Roles.GOVERNANCE_ROLE, msg.sender); _; }

    constructor(
        string memory name_,
        string memory symbol_,
        address admin_,
        uint256 lockupSeconds_,
        uint256 earlyExitFeeBps_,
        address treasury_,
        address router_,
        address pointsController_,
        uint256 maxTvl_
    ) ERC20(name_, symbol_) {
        require(admin_ != address(0) && treasury_ != address(0) && router_ != address(0) && pointsController_ != address(0), "zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(Roles.GOVERNANCE_ROLE, admin_);
        _grantRole(Roles.KEEPER_ROLE, admin_);
        _grantRole(Roles.PAUSER_ROLE, admin_);
        LOCKUP_SECONDS = lockupSeconds_;
        EARLY_EXIT_FEE_BPS = earlyExitFeeBps_;
        TREASURY = treasury_;
        ROUTER = router_;
        POINTS_CONTROLLER = pointsController_;
        maxTvl = maxTvl_;
    }

    receive() external payable {}

    // === Views ===

    function totalAssets() public view returns (uint256) {
        uint256 onHand = address(this).balance;
        uint256 managed = IStrategyRouterLike(ROUTER).totalManagedNative();
        return onHand + managed;
    }

    function previewDeposit(uint256 amount) public view returns (uint256 shares) {
        uint256 supply = totalSupply();
        uint256 assets = totalAssets();
        shares = (supply == 0 || assets == 0) ? amount : (amount * supply) / assets;
    }

    function previewWithdraw(uint256 shares) public view returns (uint256 amount) {
        uint256 supply = totalSupply();
        uint256 assets = totalAssets();
        amount = (shares * assets) / supply;
    }

    // === Admin ===

    function setMaxTvl(uint256 cap) external onlyGov { maxTvl = cap; }
    function pause() external onlyRole(Roles.PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(Roles.PAUSER_ROLE) { _unpause(); }

    // Vault → Router flows managed by governance/keeper
    function pushToRouter(uint256 amount) external onlyRole(Roles.KEEPER_ROLE) {
        require(amount <= address(this).balance, "funds");
        address(ROUTER).safeTransferNative(amount);
    }

    function pullFromRouter(uint256 amount) external onlyRole(Roles.KEEPER_ROLE) {
        IStrategyRouterLike(ROUTER).unwind(amount, address(this));
    }

    function allocate() external onlyRole(Roles.KEEPER_ROLE) { IStrategyRouterLike(ROUTER).allocate(); }

    // === User Flows ===

    function depositNative(address receiver) external payable nonReentrant whenNotPaused {
        require(receiver != address(0), "receiver");
        require(msg.value > 0, "amount");
        if (maxTvl != 0) require(totalAssets() + msg.value <= maxTvl, "cap");

        // Accrue points on existing shares before we change them
        IPointsController(POINTS_CONTROLLER).accumulate(address(this), receiver);

        uint256 shares = previewDeposit(msg.value);
        _mint(receiver, shares);

        // Update lock (single-timer model)
        uint256 newUnlock = block.timestamp + LOCKUP_SECONDS;
        uint256 prev = unlockAt[receiver];
        if (newUnlock > prev) unlockAt[receiver] = newUnlock;

        // Baseline user index after shares changed
        IPointsController(POINTS_CONTROLLER).updateUserIndex(address(this), receiver);

        emit Deposit(receiver, msg.value, shares);
    }

    function withdraw(uint256 shares, address payable receiver) external nonReentrant whenNotPaused {
        require(shares > 0, "shares");
        require(receiver != address(0), "receiver");

        // Accrue points before burning shares
        IPointsController(POINTS_CONTROLLER).accumulate(address(this), msg.sender);

        uint256 amount = previewWithdraw(shares);
        _burn(msg.sender, shares);

        uint256 penalty;
        if (block.timestamp < unlockAt[msg.sender]) {
            require(EARLY_EXIT_FEE_BPS > 0, "locked");
            penalty = (amount * EARLY_EXIT_FEE_BPS) / BPS_DENOM;
        }

        // Ensure sufficient liquidity on-hand; otherwise unwind from router
        uint256 onHand = address(this).balance;
        if (onHand < amount) {
            IStrategyRouterLike(ROUTER).unwind(amount - onHand, address(this));
        }

        // Send penalty to treasury, remainder to receiver
        if (penalty > 0) {
            address(TREASURY).safeTransferNative(penalty);
            amount -= penalty;
        }
        receiver.safeTransferNative(amount);

        // Baseline user index after shares changed
        IPointsController(POINTS_CONTROLLER).updateUserIndex(address(this), msg.sender);

        emit Withdraw(msg.sender, amount, shares, penalty);
    }
}