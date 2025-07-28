// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console, expect } from "../Test.sol";

import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract PortfolioTokenNoUnbackedTokens is Test {
    CoreYieldContext context;
    PortfolioToken cyd;
    uint256 constant NUM_TOKENS = 4;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    function property_no_unbacked_tokens() external returns (bool) {
        uint256 sum = 0;
        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            sum += cyd.subTotalSupply(i);
        }
        return sum <= cyd.totalSupply();
    }
}
