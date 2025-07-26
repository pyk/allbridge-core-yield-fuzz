// test/handlers/PoolSwap.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";
import { CoreYieldContext, Pool } from "../CoreYieldContext.sol";

contract PoolSwap is Test {
    CoreYieldContext context;

    constructor(CoreYieldContext _context) {
        context = _context;
    }

    struct Fuzz {
        uint256 poolId;
        uint256 userId;
        uint256 amount;
        bool swapToVUsd; // true for swapToVUsd, false for swapFromVUsd
    }

    struct Params {
        Pool pool;
        address user;
        uint256 amount;
        bool swapToVUsd;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "PoolSwap");
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* user=%s", context.getLabel(params.user));
        console.log("* amount=%d", params.amount);
        console.log("* swapToVUsd=%t", params.swapToVUsd ? "true" : "false");
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
        params.user = context.getRandomUser(fuzz.userId);
        params.swapToVUsd = fuzz.swapToVUsd;

        if (params.swapToVUsd) {
            params.amount = bound(
                fuzz.amount,
                params.pool.minSwapAmount,
                params.pool.maxSwapAmount
            );
        } else {
            // Amount of vUSD to swap. Bounding this is tricky.
            // Let's use the pool's vUsdBalance as a rough guide to avoid draining it instantly.
            uint256 vUsdBalance = params.pool.pool.vUsdBalance();
            if (vUsdBalance > 0) {
                // Swap at most half of the available vUSD balance
                params.amount = bound(fuzz.amount, 1, vUsdBalance / 2);
            }
        }
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.amount == 0) {
            return true;
        }
        // Skip if the pool has not been initialized with liquidity
        if (params.pool.pool.d() == 0) {
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

        if (params.swapToVUsd) {
            params.pool.asset.mint(params.user, params.amount);
            vm.prank(params.user);
            params.pool.asset.approve(address(context), params.amount);

            try context.swapToVUsd(params.pool, params.user, params.amount) { }
            catch {
                assert(false);
            }
        } else {
            try context.swapFromVUsd(params.pool, params.user, params.amount) {
            } catch {
                assert(false);
            }
        }
    }
}
