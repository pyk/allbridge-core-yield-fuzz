// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";
import { CoreYieldContext, Pool, RouterMock } from "../CoreYieldContext.sol";

contract PoolSwapRoundtrip is Test {
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
        uint256 amountFromVUsd;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "RoundtripSwap");
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* user=%s", context.getLabel(params.user));
        console.log("* amountFromVUsd=%d", params.amountFromVUsd);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
        params.user = context.getRandomUser(fuzz.userId);

        // Get the current vUSD balance to determine a realistic swap size
        uint256 currentVUsdBalance = params.pool.pool.vUsdBalance();

        // Set a threshold, e.g, 10% of the balance, to avoid draining the pool.
        uint256 maxSwapAmount = (currentVUsdBalance * 10) / 100;

        if (maxSwapAmount > 0) {
            params.amountFromVUsd =
                bound(fuzz.amount, 1000 * 1e3, maxSwapAmount);
        }
    }

    /**
     * @notice Predicts if a `swapFromVUsd` call will succeed without violating the pool's balance ratio.
     * @dev This function is adapted from the PoolSwapFromVUsd handler to ensure the first leg of the swap is valid.
     */
    function isValidSwapFromVUsd(
        Pool memory pool,
        uint256 amount
    )
        internal
        view
        returns (bool isValid)
    {
        uint256 currentVUsdBalance = pool.pool.vUsdBalance();
        uint256 balanceRatioMinBP = pool.pool.balanceRatioMinBP();
        uint256 BP = 10000;

        uint256 newVUsdBalance = currentVUsdBalance + amount;
        uint256 newTokenBalance;

        try pool.pool.getY(newVUsdBalance) returns (uint256 y) {
            newTokenBalance = y;
        } catch {
            return false; // If getY reverts, the swap is invalid.
        }

        if (newVUsdBalance == 0) {
            return false; // Prevent division by zero.
        }

        // Re-implement the check from the `validateBalanceRatio` modifier.
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
        if (params.amountFromVUsd == 0) {
            return true;
        }
        // Skip if the first swap is predicted to fail.
        if (!isValidSwapFromVUsd(params.pool, params.amountFromVUsd)) {
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

        // vUSD -> Asset
        uint256 assetBalanceBefore = params.pool.asset.balanceOf(params.user);

        vm.prank(params.user);
        try router.swapFromVUsd(params.pool, params.amountFromVUsd) { }
        catch {
            assert(false);
        }
        uint256 assetBalanceAfter = params.pool.asset.balanceOf(params.user);
        uint256 receivedAssetAmount = assetBalanceAfter - assetBalanceBefore;
        assert(receivedAssetAmount > 0);

        // Asset -> vUSD
        vm.prank(params.user);
        params.pool.asset.approve(address(router), receivedAssetAmount);

        vm.prank(params.user);
        try router.swapToVUsd(params.pool, receivedAssetAmount) { }
        catch {
            assert(false);
        }
    }
}
