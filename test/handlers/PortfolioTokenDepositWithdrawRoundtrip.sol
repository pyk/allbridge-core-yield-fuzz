// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console, expect } from "../Test.sol";
import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract PortfolioTokenDepositWithdrawRoundtrip is Test {
    CoreYieldContext context;
    PortfolioToken cyd;
    address user = makeAddr("DepositWithdrawRoundtripUser");

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    struct Fuzz {
        uint256 poolId;
        uint256 amount;
    }

    struct Params {
        Pool pool;
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
        console.log("* depositAmount=%d", params.amount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
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
        state.userAssetBalance = params.pool.asset.balanceOf(user);
        state.userSubTokenBalance = cyd.subBalanceOf(user, params.pool.index);
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }
        debug(params);

        // 1. Give the user the assets to deposit
        params.pool.asset.mint(user, params.amount);

        // 2. User approves the PortfolioToken contract to spend their assets
        vm.prank(user);
        params.pool.asset.approve(address(cyd), params.amount);

        // 3. Snapshot before deposit
        State memory beforeDeposit = snapshot(params);

        // 4. User deposits the assets into the specific pool
        vm.prank(user);
        try cyd.deposit(params.amount, params.pool.index) { }
        catch {
            halt("User fails to deposit");
        }

        // 5. Snapshot after deposit
        State memory afterDeposit = snapshot(params);
        uint256 virtualAmountReceived =
            afterDeposit.userSubTokenBalance - beforeDeposit.userSubTokenBalance;

        // 6. User immediately withdraws the exact amount of virtual CYD tokens they just received
        vm.prank(user);
        cyd.subWithdraw(virtualAmountReceived, params.pool.index);

        // 7. Snapshot after deposit
        State memory afterWithdraw = snapshot(params);

        // Invariant 1: The user's final asset balance must be identical to
        // their initial balance.
        expect.eq(
            "User asset balance should be equal after deposit/withdraw roundtrip",
            beforeDeposit.userAssetBalance,
            afterWithdraw.userAssetBalance,
            0.1e6
        );

        // Invariant 2: The user's total sub token balance should return to
        // its original state.
        expect.eq(
            "Sub-token balance should be equal after deposit/withdraw roundtrip",
            beforeDeposit.userSubTokenBalance,
            afterWithdraw.userSubTokenBalance
        );
    }
}
