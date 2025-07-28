// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console, expect } from "../Test.sol";
import { CoreYieldContext, PortfolioToken } from "../CoreYieldContext.sol";

contract MultiTokenTransferFrom is Test {
    CoreYieldContext context;
    PortfolioToken cyd;
    uint256 constant NUM_TOKENS = 4;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    struct Fuzz {
        uint256 fromId;
        uint256 spenderId;
        uint256 toId;
        uint256 amount;
    }

    struct Params {
        address from;
        address spender;
        address to;
        uint256 amount;
    }

    struct State {
        address from;
        address spender;
        address to;
        uint256 allowance;
        uint256 fromTotalVirtualBalance;
        uint256 toTotalVirtualBalance;
        uint256[NUM_TOKENS] fromSubBalances;
        uint256[NUM_TOKENS] toSubBalances;
        uint256[NUM_TOKENS] subTotalSupplies;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "MultiTokenTransferFrom");
        console.log("* from=%s", context.getLabel(params.from));
        console.log("* spender=%s", context.getLabel(params.spender));
        console.log("* to=%s", context.getLabel(params.to));
        console.log("* amount=%d", params.amount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.from = context.getRandomUser(fuzz.fromId);
        params.spender = context.getRandomUser(fuzz.spenderId);
        params.to = context.getRandomUser(fuzz.toId);

        uint256 balance = cyd.balanceOf(params.from);
        if (balance > 0) {
            params.amount = bound(fuzz.amount, 1, balance);
        }
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.amount == 0) {
            return true;
        }
        if (params.to == address(0) || params.spender == address(0)) {
            return true;
        }
        // Spender cannot transfer from their own account.
        if (params.from == params.spender) {
            return true;
        }
        return false;
    }

    function snapshot(Params memory params)
        internal
        view
        returns (State memory state)
    {
        state.from = params.from;
        state.spender = params.spender;
        state.to = params.to;

        state.allowance = cyd.allowance(params.from, params.spender);
        state.fromTotalVirtualBalance = cyd.balanceOf(params.from);
        state.toTotalVirtualBalance = cyd.balanceOf(params.to);

        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            // Note: We snapshot the VIRTUAL sub-balance here.
            state.fromSubBalances[i] = cyd.subBalanceOf(params.from, i);
            state.toSubBalances[i] = cyd.subBalanceOf(params.to, i);
            state.subTotalSupplies[i] = cyd.subTotalSupply(i);
        }
    }

    /// @notice Property: `transferFrom` must correctly update the spender's allowance.
    function property_updates_allowance(
        State memory pre,
        State memory post,
        uint256 amount
    )
        internal
    {
        if (pre.allowance == type(uint256).max) {
            expect.eq(
                "Infinite allowance should not change",
                pre.allowance,
                post.allowance
            );
        } else {
            expect.eq(
                "Allowance should be debited correctly",
                pre.allowance,
                post.allowance + amount
            );
        }
    }

    /// @notice Property: A transfer must preserve the total supply of each underlying virtual sub-token.
    function property_transferFrom_preserves_total_supply(
        State memory pre,
        State memory post
    )
        internal
    {
        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            expect.eq(
                "Virtual sub-token total supply must not change after a transfer",
                pre.subTotalSupplies[i],
                post.subTotalSupplies[i]
            );
        }
    }

    /// @notice Property: The total virtual value held by the sender and receiver should be conserved.
    function property_transferFrom_conserves_participant_balances(
        State memory pre,
        State memory post
    )
        internal
    {
        if (pre.from == pre.to) {
            return;
        }

        uint256 preTotalBalance =
            pre.fromTotalVirtualBalance + pre.toTotalVirtualBalance;
        uint256 postTotalBalance =
            post.fromTotalVirtualBalance + post.toTotalVirtualBalance;

        // A tolerance is needed because of rounding dust from proportional transfers
        // across multiple sub-tokens. Each sub-token transfer can have a small rounding error.
        expect.eq(
            "Sum of participant virtual balances must be conserved",
            preTotalBalance,
            postTotalBalance,
            NUM_TOKENS // Tolerance of 1 for each sub-token transfer
        );
    }

    /// @notice Property: A transfer to the sender themselves should be a no-op on all balances.
    function property_transferFrom_to_self_is_noop(
        State memory pre,
        State memory post
    )
        internal
    {
        if (pre.from != pre.to) {
            return;
        }

        expect.eq(
            "Virtual balance should be unchanged after a self-transfer",
            pre.fromTotalVirtualBalance,
            post.fromTotalVirtualBalance
        );
        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            expect.eq(
                "Virtual sub-balance should be unchanged after a self-transfer",
                pre.fromSubBalances[i],
                post.fromSubBalances[i]
            );
        }
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }
        debug(params);

        // Setup: `from` approves `spender` for the transfer amount.
        vm.prank(params.from);
        cyd.approve(params.spender, params.amount);

        State memory pre = snapshot(params);

        // Check if the allowance is sufficient before attempting the transfer.
        // This prevents reverts from insufficient allowance which we don't want to test here.
        if (pre.allowance < params.amount) {
            return;
        }

        vm.prank(params.spender);
        try cyd.transferFrom(params.from, params.to, params.amount) {
            State memory post = snapshot(params);

            property_updates_allowance(pre, post, params.amount);
            property_transferFrom_preserves_total_supply(pre, post);
            property_transferFrom_conserves_participant_balances(pre, post);
            property_transferFrom_to_self_is_noop(pre, post);
        } catch {
            assert(false);
        }
    }
}
