// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";

import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract PortfolioTokenDeposit is Test {
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

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "PortfolioTokenDeposit");
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
            fuzz.amount,
            params.pool.minDepositAmount,
            params.pool.maxDepositAmount
        );
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

        params.pool.asset.mint(params.user, params.amount);

        vm.prank(params.user);
        params.pool.asset.approve(address(cyd), params.amount);

        vm.prank(params.user);
        try cyd.deposit(params.amount, params.pool.index) { }
        catch {
            assert(false);
        }
    }
}
