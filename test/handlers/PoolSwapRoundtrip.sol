// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";
import { CoreYieldContext, Pool, RouterMock } from "../CoreYieldContext.sol";

/// @notice This handler is used to generate fees in the pool. This handler is designed to keep the pool balanced.
contract PoolSwapRoundtrip is Test {
    CoreYieldContext context;
    RouterMock router;
    address user = makeAddr("PoolSwapRoundtripUser");

    constructor(CoreYieldContext _context) {
        context = _context;
        router = context.router();
    }

    struct Fuzz {
        uint256 poolId;
        uint256 amount;
    }

    struct Params {
        Pool pool;
        address user;
        uint256 assetAmount;
        uint256 vUsdAmount;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "PoolSwapRoundTrip");
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* assetAmount=%d", params.assetAmount);
        console.log("* vUsdAmount=%d", params.vUsdAmount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
        // NOTE: we hardcode the user to prevent pool imbalance
        params.user = user;
        params.assetAmount = bound(
            fuzz.amount, params.pool.minSwapAmount, params.pool.maxSwapAmount
        );
        // Swa back and forth using 1:1 value to reduce pool imbalance
        params.vUsdAmount = params.assetAmount / 1000; // Convert to virtual units, 3 decimals
    }

    function skip(Params memory params) internal view returns (bool) {
        return false;
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }

        debug(params);

        // Asset -> vUSD 1:1
        params.pool.asset.mint(user, params.assetAmount);
        vm.prank(params.user);
        params.pool.asset.approve(address(router), params.assetAmount);

        vm.prank(params.user);
        try router.swapToVUsd(params.pool, params.assetAmount) { }
        catch {
            assert(false);
        }

        // vUSD -> Asset 1:1
        vm.prank(params.user);
        try router.swapFromVUsd(params.pool, params.vUsdAmount) { }
        catch {
            assert(false);
        }
    }
}
