// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";

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
        params.amount = bound(fuzz.amount, 1, cyd.balanceOf(params.from));
    }

    function skip(Params memory params) internal view returns (bool) {
        if (params.to == address(0)) {
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

        vm.prank(params.from);
        try cyd.subTransfer(params.to, params.amount, params.pool.index) { }
        catch {
            assert(false);
        }
    }
}
