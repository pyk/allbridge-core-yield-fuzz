// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console, expect } from "../Test.sol";

import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract MultiTokenTransfer is Test {
    CoreYieldContext context;
    PortfolioToken cyd;
    uint256 constant NUM_TOKENS = 4;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    struct Fuzz {
        uint256 fromId;
        uint256 toId;
        uint256 amount;
    }

    struct Params {
        address from;
        address to;
        uint256 amount;
    }

    struct State {
        address from;
        address to;
        uint256 fromTotalVirtualBalance;
        uint256 toTotalVirtualBalance;
        uint256[4] fromSubBalances;
        uint256[4] toSubBalances;
        uint256[4] subTotalSupplies;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "MultiTokenTransfer");
        console.log("* from=%s", context.getLabel(params.from));
        console.log("* to=%s", context.getLabel(params.to));
        console.log("* amount=%d", params.amount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.from = context.getRandomUser(fuzz.fromId);
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
        if (params.to == address(0)) {
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
        state.to = params.to;
        state.fromTotalVirtualBalance = cyd.balanceOf(params.from);
        state.toTotalVirtualBalance = cyd.balanceOf(params.to);

        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            // Note: We snapshot the REAL underlying balance, not the virtual one.
            state.fromSubBalances[i] = cyd.subBalanceOf(params.from, i);
            state.toSubBalances[i] = cyd.subBalanceOf(params.to, i);
            state.subTotalSupplies[i] = cyd.subTotalSupply(i);
        }
    }

    /// @notice Property: A transfer must preserve the total supply of each underlying real sub-token.
    function property_transfer_preserves_total_supply(
        State memory pre,
        State memory post
    )
        internal
    {
        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            expect.eq(
                "Real sub-token total supply must not change after a transfer",
                pre.subTotalSupplies[i],
                post.subTotalSupplies[i]
            );
        }
    }

    /// @notice Property: The total real value held by the sender and receiver should be conserved.
    function property_transfer_conserves_participant_balances(
        State memory pre,
        State memory post
    )
        internal
    {
        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            uint256 preSum = pre.fromSubBalances[i] + pre.toSubBalances[i];
            uint256 postSum = post.fromSubBalances[i] + post.toSubBalances[i];
            // A tolerance of 1 is added because of the `_fromVirtual` calculation which can have rounding dust.
            expect.eq(
                "Sum of participant real sub-balances must be conserved",
                preSum,
                postSum,
                1
            );
        }
    }

    /// @notice Property: A transfer to the sender themselves should be a no-op on all balances.
    function property_transfer_to_self_is_noop(
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
                "Real sub-balance should be unchanged after a self-transfer",
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
        State memory pre = snapshot(params);

        vm.prank(params.from);
        try cyd.transfer(params.to, params.amount) {
            State memory post = snapshot(params);

            property_transfer_preserves_total_supply(pre, post);
            property_transfer_conserves_participant_balances(pre, post);
            property_transfer_to_self_is_noop(pre, post);
        } catch {
            assert(false);
        }
    }
}
