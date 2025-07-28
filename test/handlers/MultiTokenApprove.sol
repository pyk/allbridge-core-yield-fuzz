// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console, expect } from "../Test.sol";

import { CoreYieldContext, PortfolioToken } from "../CoreYieldContext.sol";

contract MultiTokenApprove is Test {
    CoreYieldContext context;
    PortfolioToken cyd;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    struct Fuzz {
        uint256 ownerId;
        uint256 spenderId;
        uint256 amount;
        uint256 secondAmount;
    }

    struct Params {
        address owner;
        address spender;
        uint256 amount;
        uint256 secondAmount;
    }

    struct State {
        address owner;
        address spender;
        uint256 allowance;
        uint256 ownerBalance;
        uint256 spenderBalance;
        uint256 totalSupply;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "MultiTokenApprove");
        console.log("* owner=%s", context.getLabel(params.owner));
        console.log("* spender=%s", context.getLabel(params.spender));
        console.log("* amount=%d", params.amount);
        console.log("* secondAmount=%d", params.secondAmount);
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.owner = context.getRandomUser(fuzz.ownerId);
        params.spender = context.getRandomUser(fuzz.spenderId);
        // Unlike transfer, approve amount is not bounded by balance.
        params.amount = fuzz.amount;
        params.secondAmount = fuzz.secondAmount;
    }

    function skip(Params memory params) internal view returns (bool) {
        // Approving the zero address should be disallowed by the ERC20 standard.
        if (params.spender == address(0)) {
            return true;
        }
        return false;
    }

    function snapshot(Params memory params)
        internal
        view
        returns (State memory state)
    {
        state.owner = params.owner;
        state.spender = params.spender;
        state.allowance = cyd.allowance(params.owner, params.spender);
        state.ownerBalance = cyd.balanceOf(params.owner);
        state.spenderBalance = cyd.balanceOf(params.spender);
        state.totalSupply = cyd.totalSupply();
    }

    /// @notice Property: `approve` should not change token balances.
    function property_approve_does_not_change_balances(
        State memory pre,
        State memory post
    )
        internal
    {
        expect.eq(
            "Owner balance should not change after approve",
            pre.ownerBalance,
            post.ownerBalance
        );
        expect.eq(
            "Spender balance should not change after approve",
            pre.spenderBalance,
            post.spenderBalance
        );
    }

    /// @notice Property: `approve` should not change the token's total supply.
    function property_approve_does_not_change_total_supply(
        State memory pre,
        State memory post
    )
        internal
    {
        expect.eq(
            "Total supply should not change after approve",
            pre.totalSupply,
            post.totalSupply
        );
    }

    /// @notice Property: A subsequent `approve` call must overwrite the previous allowance.
    function property_subsequent_approve_overwrites_allowance(
        address owner,
        address spender,
        uint256 finalAmount
    )
        internal
    {
        uint256 finalAllowance = cyd.allowance(owner, spender);
        expect.eq(
            "Subsequent approve must overwrite the previous allowance",
            finalAllowance,
            finalAmount
        );
    }

    function call(Fuzz memory fuzz) external {
        Params memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }

        debug(params);

        State memory pre = snapshot(params);

        vm.prank(params.owner);
        cyd.approve(params.spender, params.amount);

        State memory post = snapshot(params);

        property_approve_does_not_change_balances(pre, post);
        property_approve_does_not_change_total_supply(pre, post);
        expect.eq(
            "Approve should set the allowance correctly",
            post.allowance,
            params.amount
        );

        vm.prank(params.owner);
        cyd.approve(params.spender, params.secondAmount);

        property_subsequent_approve_overwrites_allowance(
            params.owner, params.spender, params.secondAmount
        );
    }
}
