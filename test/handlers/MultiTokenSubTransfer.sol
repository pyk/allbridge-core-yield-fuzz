// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console, expect } from "../Test.sol";

import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract MultiTokenSubTransfer is Test {
    CoreYieldContext context;
    PortfolioToken cyd;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    struct Fuzz {
        uint256 poolId;
        uint256 fromId;
        uint256 toId;
        uint256 amount;
    }

    struct Params {
        Pool pool;
        address from;
        address to;
        uint256 amount;
    }

    struct State {
        address from;
        address to;
        uint256 fromSubBalance;
        uint256 toSubBalance;
        uint256 subTotalSupply;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "MultiTokenSubTransfer");
        console.log("* poolIndex=%d", params.pool.index);
        console.log("* pool=%s", context.getLabel(address(params.pool.pool)));
        console.log("* from=%s", context.getLabel(params.from));
        console.log("* to=%s", context.getLabel(params.to));
        console.log("* amount=%d", params.amount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.pool = context.getRandomPool(fuzz.poolId);
        params.from = context.getRandomUser(fuzz.fromId);
        params.to = context.getRandomUser(fuzz.toId);
        uint256 balance = cyd.subBalanceOf(params.from, params.pool.index);
        if (balance > 0) {
            params.amount = bound(
                fuzz.amount, 1, cyd.subBalanceOf(params.from, params.pool.index)
            );
        }
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.amount == 0) {
            return true;
        }
        if (params.to == address(0)) {
            return true;
        }
        return false;
    }

    /// @notice Captures the state of the balances before or after an operation.
    function snapshot(Params memory params)
        internal
        view
        returns (State memory state)
    {
        state.from = params.from;
        state.to = params.to;
        state.fromSubBalance = cyd.subBalanceOf(params.from, params.pool.index);
        state.toSubBalance = cyd.subBalanceOf(params.to, params.pool.index);
        state.subTotalSupply = cyd.subTotalSupply(params.pool.index);
    }

    /// @notice Property: A successful subTransfer must correctly update the sender's and receiver's real balances.
    /// The amount of real tokens debited from the sender must equal the amount credited to the receiver.
    function property_subTransfer_updates_balances_correctly(
        State memory pre,
        State memory post
    )
        internal
    {
        uint256 amountDebited = pre.fromSubBalance - post.fromSubBalance;
        uint256 amountCredited = post.toSubBalance - pre.toSubBalance;

        expect.eq(
            "Amount debited must equal amount credited",
            amountDebited,
            amountCredited,
            1
        );
    }

    /// @notice Property: A subTransfer must preserve the total supply of the underlying real sub-token.
    function property_subTransfer_preserves_total_supply(
        State memory pre,
        State memory post
    )
        internal
    {
        expect.eq(
            "Real sub-token total supply must not change after a transfer",
            pre.subTotalSupply,
            post.subTotalSupply
        );
    }

    /// @notice Property: A subTransfer to the sender themselves should not change their real balance.
    function property_subTransfer_to_self_is_noop_on_real_balance(
        State memory pre,
        State memory post
    )
        internal
    {
        if (pre.from != pre.to) {
            return;
        }

        expect.eq(
            "Real balance should be unchanged after a self-transfer",
            pre.fromSubBalance,
            post.toSubBalance
        );
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }

        debug(params);
        State memory pre = snapshot(params);

        vm.prank(params.from);
        try cyd.subTransfer(params.to, params.amount, params.pool.index) {
            State memory post = snapshot(params);
            property_subTransfer_updates_balances_correctly(pre, post);
            property_subTransfer_preserves_total_supply(pre, post);
            property_subTransfer_to_self_is_noop_on_real_balance(pre, post);
        } catch {
            assert(false);
        }
    }
}
