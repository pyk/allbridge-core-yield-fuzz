// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pool } from "../CoreYieldContext.sol";

contract RouterMock {
    function swapFromVUsd(Pool memory pool, uint256 amount) external {
        pool.pool.swapFromVUsd(msg.sender, amount, 0, false);
    }

    function swapToVUsd(
        Pool memory pool,
        address user,
        uint256 amount
    )
        external
    {
        pool.asset.transferFrom(user, address(pool.pool), amount);
        pool.pool.swapToVUsd(user, amount, false);
    }
}
