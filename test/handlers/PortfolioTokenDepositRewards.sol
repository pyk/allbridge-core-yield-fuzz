// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";

import { CoreYieldContext, PortfolioToken } from "../CoreYieldContext.sol";

contract PortfolioTokenDepositRewards is Test {
    CoreYieldContext context;
    PortfolioToken cyd;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    function debug() internal view {
        console.log("* ===== %s =====", "PortfolioTokenDepositRewards");
        console.log("* cyd.totalSupply=%d", cyd.totalSupply());
    }

    function call() external {
        try cyd.depositRewards() { }
        catch {
            assert(false);
        }
    }
}
