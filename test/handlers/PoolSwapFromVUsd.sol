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
        console.log("* ===== %s =====", "PoolSwap");
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
        params.poolAssetBalance = params.pool.pool.tokenBalance();

        // Get the current vUSD balance to determine a realistic swap size
        uint256 currentVUsdBalance = params.pool.pool.vUsdBalance();

        // Set a threshold, e.g, 10% of the balance, to avoid draining the pool.
        // This keeps the system in a healthy state for other fuzz tests.
        uint256 maxSwapAmount = (currentVUsdBalance * 10) / 100;

        if (maxSwapAmount > 0 && maxSwapAmount > params.pool.minSwapAmount) {
            // Bound the swap amount to be between 1 and the calculated threshold
            params.amount =
                bound(fuzz.amount, params.pool.minSwapAmount, maxSwapAmount);
        }
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.amount == 0) {
            return true;
        }
        if (params.poolAssetBalance < params.pool.initialLiquidity) {
            return true;
        }
        return false;
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
