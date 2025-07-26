// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";
import { CoreYieldContext, Pool, RouterMock } from "../CoreYieldContext.sol";

contract PoolSwapToVUsd is Test {
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
        console.log("* ===== %s =====", "PoolSwapToVUsd");
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
        params.amount = bound(
            fuzz.amount, params.pool.minSwapAmount, params.pool.maxSwapAmount
        );
        params.poolAssetBalance =
            params.pool.asset.balanceOf(address(params.pool.pool));
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.amount == 0) {
            return true;
        }

        if (params.poolAssetBalance > params.pool.initialLiquidity * 5) {
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

        params.pool.asset.mint(params.user, params.amount);

        vm.prank(params.user);
        params.pool.asset.approve(address(router), params.amount);

        vm.prank(params.user);
        try router.swapToVUsd(params.pool, params.amount) { }
        catch {
            assert(false);
        }
    }
}
