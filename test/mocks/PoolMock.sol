// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IPool } from "../../contracts/interfaces/IPool.sol";
import "../../contracts/lib/PoolUtils.sol"; // For the 'P' constant

/**
 * @title PoolMock
 * @notice A functional mock of an IPool implementation for testing and fuzzing PortfolioToken.
 *
 * FEATURES:
 * - Implements the full IPool interface.
 * - Simulates a 1:1 deposit-to-LP token minting ratio.
 * - Includes a functional rewards mechanism with a helper `addRewards` function for tests.
 * - Simplifies complex curve math functions (`d`, `vUsdBalance`) to predictable values.
 */
contract PoolMock is IPool {
    ERC20 public immutable override token;

    // State for LP token balances (virtual tokens)
    mapping(address => uint256) private _lpBalances;
    uint256 private _totalLpSupply;

    // State for underlying token balance
    uint256 private _tokenBalance;

    // State for rewards
    // Using a large number for precision in reward calculations
    uint256 private constant REWARD_PRECISION = 1e18;
    uint256 public override accRewardPerShareP;
    mapping(address => uint256) public override userRewardDebt;

    // Internal mapping to track rewards owed upon claim
    mapping(address => uint256) private _rewardsOwed;

    event RewardsAdded(uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(ERC20 token_) {
        token = token_;
    }

    // --- IPool Interface Implementation ---

    /**
     * @notice The decimals for the LP token. Must be 3 for PortfolioToken.
     */
    function decimals() external pure override returns (uint8) {
        return 3;
    }

    /**
     * @notice Returns the LP token balance of a user.
     */
    function balanceOf(address user) public view override returns (uint256) {
        return _lpBalances[user];
    }

    /**
     * @notice Total amount of the underlying token held by the pool.
     */
    function tokenBalance() external view override returns (uint256) {
        return _tokenBalance;
    }

    /**
     * @notice Mocked vUSD balance. Simulates a perfectly balanced pool.
     */
    function vUsdBalance() external view override returns (uint256) {
        return _tokenBalance;
    }

    /**
     * @notice Mocked 'd' invariant. Used for deposit estimations.
     */
    function d() external view override returns (uint256) {
        // A simple, predictable value for testing estimations.
        return _tokenBalance * 2;
    }

    /**
     * @notice Mocked getY. Not used by PortfolioToken's core logic, so returns a simple value.
     */
    function getY(uint256 x) external pure override returns (uint256) {
        return x;
    }

    /**
     * @notice Receives tokens and mints LP tokens to the depositor (msg.sender).
     * @dev In this mock, 1 token = 1 LP token.
     */
    function deposit(uint256 amount) external override {
        require(amount > 0, "PoolMock: Cannot deposit 0");

        // Update rewards for the user *before* their LP balance changes.
        _updateUserRewards(msg.sender);

        // Pull tokens from the depositor (PortfolioToken contract)
        token.transferFrom(msg.sender, address(this), amount);

        // Update internal state
        _tokenBalance += amount;
        _lpBalances[msg.sender] += amount;
        _totalLpSupply += amount;
    }

    /**
     * @notice Burns LP tokens and sends back the underlying token.
     * @dev In this mock, 1 LP token = 1 token.
     */
    function withdraw(uint256 amountLp) external override {
        require(amountLp > 0, "PoolMock: Cannot withdraw 0");
        require(
            _lpBalances[msg.sender] >= amountLp,
            "PoolMock: Insufficient LP balance"
        );

        // Update rewards for the user *before* their LP balance changes.
        _updateUserRewards(msg.sender);

        // Update internal state
        _lpBalances[msg.sender] -= amountLp;
        _totalLpSupply -= amountLp;

        // This mock assumes 1 LP token is worth 1 underlying token
        uint256 amountToken = amountLp;
        require(
            _tokenBalance >= amountToken, "PoolMock: Insufficient pool reserves"
        );
        _tokenBalance -= amountToken;

        // Send tokens to the user (PortfolioToken contract)
        token.transfer(msg.sender, amountToken);
    }

    /**
     * @notice Calculates the pending rewards for a user.
     */
    function pendingReward(address user)
        public
        view
        override
        returns (uint256)
    {
        uint256 pending = (balanceOf(user) * accRewardPerShareP)
            / (10 ** PoolUtils.P) - userRewardDebt[user];
        return pending + _rewardsOwed[user];
    }

    /**
     * @notice Claims pending rewards and transfers them to the user.
     */
    function claimRewards() external override {
        _updateUserRewards(msg.sender);

        uint256 amountToClaim = _rewardsOwed[msg.sender];
        if (amountToClaim > 0) {
            _rewardsOwed[msg.sender] = 0;

            require(
                _tokenBalance >= amountToClaim,
                "PoolMock: Not enough rewards to claim"
            );
            _tokenBalance -= amountToClaim;

            token.transfer(msg.sender, amountToClaim);
            emit RewardsClaimed(msg.sender, amountToClaim);
        }
    }

    // --- Helper Functions for Fuzzing/Testing ---

    /**
     * @notice A helper function for tests to add rewards to the pool.
     * @param amount The amount of `token` to add as rewards.
     */
    function addRewards(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        _tokenBalance += amount;

        if (_totalLpSupply > 0) {
            // Update the accumulated rewards per share
            // PoolUtils.P is 52, so we scale by 2**52
            accRewardPerShareP += (amount * (1 << PoolUtils.P)) / _totalLpSupply;
        }
        emit RewardsAdded(amount);
    }

    // --- Internal Functions ---

    /**
     * @notice Updates a user's reward debt and moves pending rewards to an "owed" state.
     * This should be called before any action that changes a user's LP balance.
     */
    function _updateUserRewards(address user) internal {
        uint256 pending = (balanceOf(user) * accRewardPerShareP)
            / (10 ** PoolUtils.P) - userRewardDebt[user];
        if (pending > 0) {
            _rewardsOwed[user] += pending;
        }
        userRewardDebt[user] =
            (balanceOf(user) * accRewardPerShareP) / (10 ** PoolUtils.P);
    }
}
