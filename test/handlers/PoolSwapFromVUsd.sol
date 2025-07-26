// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";
import { CoreYieldContext, Pool, RouterMock } from "../CoreYieldContext.sol";

contract PoolSwapFromVUsd is Test {
    CoreYieldContext context;
    RouterMock router;

    constructor(CoreYieldContext _context) {
        context = _context;
        router = context.router();
    }

    struct Fuzz {
        uint256 poolId;
        uint256 userId;
        uint256 amount;
    }

    struct Params {
        Pool pool;
        address user;
        uint256 amount;
        uint256 poolAssetBalance;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "PoolSwapFromVUsd");
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* user=%s", context.getLabel(params.user));
        console.log("* amount=%d", params.amount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
        params.user = context.getRandomUser(fuzz.userId);
        params.poolAssetBalance =
            params.pool.asset.balanceOf(address(params.pool.pool));

        // Get the current vUSD balance to determine a realistic swap size
        uint256 currentVUsdBalance = params.pool.pool.vUsdBalance();

        // Set a threshold, e.g, 10% of the balance, to avoid draining the pool.
        // This keeps the system in a healthy state for other fuzz tests.
        uint256 maxSwapAmount = (currentVUsdBalance * 10) / 100;

        // Bound the swap amount to bebetween 1 and the calculated threshold
        if (maxSwapAmount > 0) {
            params.amount = bound(fuzz.amount, 1, maxSwapAmount);
        }
    }

    /**
     * @notice Predicts if a `swapFromVUsd` call will succeed without violating the pool's balance ratio.
     * @dev This function simulates the outcome of a swap to check against the `validateBalanceRatio` modifier's logic.
     * @param pool The pool instance on which the swap would occur.
     * @param amount The amount of vUSD to be swapped.
     * @return isValid Returns true if the swap is predicted to be valid, false otherwise.
     */
    function isValidSwapFromVUsd(
        Pool memory pool,
        uint256 amount
    )
        internal
        view
        returns (bool isValid)
    {
        // 1. Get current pool state from the passed 'pool' object.
        uint256 currentVUsdBalance = pool.pool.vUsdBalance();
        uint256 balanceRatioMinBP = pool.pool.balanceRatioMinBP();
        uint256 BP = 10000;

        // 2. Predict the state after the swap.
        uint256 newVUsdBalance = currentVUsdBalance + amount;
        uint256 newTokenBalance;

        try pool.pool.getY(newVUsdBalance) returns (uint256 y) {
            newTokenBalance = y;
        } catch {
            // If getY itself reverts (e.g., due to math issues with extreme inputs),
            // the swap is considered invalid.
            return false;
        }

        // Prevent division by zero if the pool is ever drained.
        if (newVUsdBalance == 0) {
            return false;
        }

        // 3. Re-implement the check from the `validateBalanceRatio` modifier and return the result.
        if (newTokenBalance > newVUsdBalance) {
            isValid =
                (newVUsdBalance * BP) / newTokenBalance >= balanceRatioMinBP;
        } else {
            isValid =
                (newTokenBalance * BP) / newVUsdBalance >= balanceRatioMinBP;
        }

        return isValid;
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.amount == 0) {
            return true;
        }
        if (!isValidSwapFromVUsd(params.pool, params.amount)) {
            return true;
        }
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }

        debug(params);

        vm.prank(params.user);
        try router.swapFromVUsd(params.pool, params.amount) { }
        catch {
            assert(false);
        }
    }
}
