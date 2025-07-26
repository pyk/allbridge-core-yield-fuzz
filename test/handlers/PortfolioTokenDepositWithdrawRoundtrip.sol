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

    struct State {
        uint256 userAssetBalance;
        uint256 userSubTokenBalance;
    }

    function debug(Params memory params) internal view {
        console.log(
            "* ===== %s =====", "PortfolioTokenDepositWithdrawRoundtrip"
        );
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* user=%s", context.getLabel(params.user));
        console.log("* depositAmount=%d", params.amount);
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

    function snapshot(Params memory params)
        internal
        view
        returns (State memory state)
    {
        state.userAssetBalance = params.pool.asset.balanceOf(params.user);
        state.userSubTokenBalance =
            cyd.subBalanceOf(params.user, params.pool.index);
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }
        debug(params);

        // 1. Give the user the assets to deposit
        params.pool.asset.mint(params.user, params.amount);

        // 2. User approves the PortfolioToken contract to spend their assets
        vm.prank(params.user);
        params.pool.asset.approve(address(cyd), params.amount);

        // 3. Snapshot before deposit
        State memory beforeDeposit = snapshot(params);

        // 4. User deposits the assets into the specific pool
        vm.prank(params.user);
        try cyd.deposit(params.amount, params.pool.index) { }
        catch {
            halt("User fails to deposit");
        }

        // 5. Snapshot after deposit
        State memory afterDeposit = snapshot(params);
        uint256 virtualAmountReceived =
            afterDeposit.userSubTokenBalance - beforeDeposit.userSubTokenBalance;

        // 6. User immediately withdraws the exact amount of virtual CYD tokens they just received
        vm.prank(params.user);
        cyd.subWithdraw(virtualAmountReceived, params.pool.index);

        // 7. Snapshot after deposit
        State memory afterWithdraw = snapshot(params);

        // Invariant 1: The user's final asset balance must be identical to
        // their initial balance.
        eq(
            beforeDeposit.userAssetBalance,
            afterWithdraw.userAssetBalance,
            "Asset balance mismatch after roundtrip"
        );

        // Invariant 2: The user's total sub token balance should return to
        // its original state.
        eq(
            beforeDeposit.userSubTokenBalance,
            afterWithdraw.userSubTokenBalance,
            "Sub-token balance mismatch after roundtrip"
        );
    }
}
