// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "../Test.sol";

import { CoreYieldContext, PortfolioToken, Pool } from "../CoreYieldContext.sol";

contract PortfolioTokenWithdraw is Test {
    CoreYieldContext context;
    PortfolioToken cyd;

    constructor(CoreYieldContext _context) {
        context = _context;
        cyd = context.portfolioToken();
    }

    struct Fuzz {
        uint256 userId;
        uint256 virtualAmount;
    }

    struct Params {
        address user;
        uint256 userVirtualBalance;
        uint256 virtualAmount;
    }

    function debug(Params memory params) internal view {
        console.log("* ===== %s =====", "PortfolioTokenWithdraw");
        console.log("* user=%s", context.getLabel(params.user));
        console.log("* userVirtualBalance=%d", params.userVirtualBalance);
        console.log("* virtualAmount=%d", params.virtualAmount);
        console.log("* cyd.totalSupply=%d", cyd.totalSupply());
    }

    function bind(Fuzz memory fuzz)
        internal
        view
        returns (Params memory params)
    {
        params.user = context.getRandomUser(fuzz.userId);
        params.userVirtualBalance = cyd.balanceOf(params.user);
        uint256 minWithdraw = 1e3; // 1 CYD
        if (params.userVirtualBalance > minWithdraw) {
            params.virtualAmount = bound(
                fuzz.virtualAmount, minWithdraw, params.userVirtualBalance
            );
        }
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

        vm.prank(params.user);
        try cyd.withdraw(params.virtualAmount) { }
        catch {
            assert(false);
        }
    }
}
