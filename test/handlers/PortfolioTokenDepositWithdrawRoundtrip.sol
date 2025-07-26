// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";
import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract PortfolioTokenDepositWithdrawRoundtrip is Test {
    CoreYieldContext context;
    PortfolioToken cyd;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
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
    }

    function debug(
        Params memory params,
        uint256 virtualAmountReceived
    )
        internal
        view
    {
        console.log(
            "* ===== %s =====", "PortfolioTokenDepositWithdrawRoundtrip"
        );
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* user=%s", context.getLabel(params.user));
        console.log("* depositAmount=%d", params.amount);
        console.log("* virtualAmountReceived=%d", virtualAmountReceived);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
        params.user = context.getRandomUser(fuzz.userId);
        // Bind the deposit amount within the range defined in the context
        params.amount = bound(
            fuzz.amount,
            params.pool.minDepositAmount,
            params.pool.maxDepositAmount
        );
    }

    function skip(Params memory params) internal view returns (bool) {
        // Skip if the deposit amount is zero
        if (params.amount == 0) {
            return true;
        }
        return false;
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }

        // --- PRE-CONDITIONS ---
        // Record initial balances to verify the invariant later
        uint256 initialAssetBalance = params.pool.asset.balanceOf(params.user);
        uint256 initialCydBalance = cyd.balanceOf(params.user);
        uint256 initialSubCydBalance =
            cyd.subBalanceOf(params.user, params.pool.index);

        // --- DEPOSIT ---
        // 1. Give the user the assets to deposit
        params.pool.asset.mint(params.user, params.amount);

        // 2. User approves the PortfolioToken contract to spend their assets
        vm.prank(params.user);
        params.pool.asset.approve(address(cyd), params.amount);

        // 3. User deposits the assets into the specific pool
        vm.prank(params.user);
        cyd.deposit(params.amount, params.pool.index);

        // --- POST-DEPOSIT CHECKS ---
        // Calculate the amount of virtual CYD tokens the user received from this deposit
        uint256 virtualAmountReceived = cyd.subBalanceOf(
            params.user, params.pool.index
        ) - initialSubCydBalance;

        // The user must receive some CYD tokens for a non-zero deposit
        assert(virtualAmountReceived > 0);

        debug(params, virtualAmountReceived);

        // --- WITHDRAW ---
        // User immediately withdraws the exact amount of virtual CYD tokens they just received
        // from the same pool. We use `subWithdraw` as it's the direct inverse of a single-pool deposit.
        vm.prank(params.user);
        cyd.subWithdraw(virtualAmountReceived, params.pool.index);

        // --- FINAL ASSERTIONS (INVARIANT CHECK) ---
        uint256 finalAssetBalance = params.pool.asset.balanceOf(params.user);
        uint256 finalCydBalance = cyd.balanceOf(params.user);

        // Invariant 1: The user's final asset balance must be identical to their initial balance.
        // Any loss violates the "zero fees" promise.
        assert(finalAssetBalance == initialAssetBalance);

        // Invariant 2: The user's total CYD balance should return to its original state.
        assert(finalCydBalance == initialCydBalance);
    }
}
