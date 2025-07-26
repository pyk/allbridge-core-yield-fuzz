// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Pool as PoolMock } from "@allbridge-core/contracts/Pool.sol";

import { ContextProvider } from "./ContextProvider.sol";

import { AssetMock } from "./mocks/AssetMock.sol";
import { RouterMock } from "./mocks/RouterMock.sol";

import { PortfolioToken } from "../contracts/PortfolioToken.sol";
import { IPool } from "../contracts/interfaces/IPool.sol";

struct Pool {
    PoolMock pool;
    AssetMock asset;
    uint256 index;
    uint256 initialLiquidity;
    uint256 minDepositAmount;
    uint256 maxDepositAmount;
    uint256 minSwapAmount;
    uint256 maxSwapAmount;
}

contract CoreYieldContext is ContextProvider {
    Pool[1] pools;
    PortfolioToken public portfolioToken;
    RouterMock public router;

    constructor() {
        label(address(this), "CoreYieldContext");
        label(address(0), "ZeroAddress");

        addUsers();

        router = new RouterMock();

        // TODO: we add one pool first for testing
        pools[0] = deployPool(
            DeployPoolParams({
                name: "USDT",
                decimals: 6,
                index: 0,
                initialLiquidity: 1_000_000 * 1e6,
                minDepositAmount: 10 * 1e6,
                maxDepositAmount: 1_000_000 * 1e6,
                minSwapAmount: 100 * 1e6,
                maxSwapAmount: 1_000 * 1e6
            })
        );

        portfolioToken = new PortfolioToken("Portfolio", "CYD");
        label(address(portfolioToken), "PortfolioToken");

        for (uint256 i = 0; i < pools.length; i++) {
            Pool memory pool = pools[i];
            // Initial liquidity
            pool.asset.mint(address(this), pool.initialLiquidity);
            pool.asset.approve(address(pool.pool), pool.initialLiquidity);
            pool.pool.deposit(pool.initialLiquidity);

            // s
            portfolioToken.setPool(pool.index, IPool(address(pool.pool)));
        }
    }

    //************************************************************//
    //                            Pool                            //
    //************************************************************//

    struct DeployPoolParams {
        string name;
        uint8 decimals;
        uint256 index;
        uint256 initialLiquidity;
        uint256 minDepositAmount;
        uint256 maxDepositAmount;
        uint256 minSwapAmount;
        uint256 maxSwapAmount;
    }

    function deployPool(DeployPoolParams memory params)
        internal
        returns (Pool memory pool)
    {
        pool.asset = new AssetMock(params.name, params.name, params.decimals);
        pool.pool = new PoolMock({
            router_: address(router),
            a_: 20,
            token_: pool.asset,
            feeShareBP_: 500, // 5%
            balanceRatioMinBP_: 500,
            lpName: "Allbridge LP",
            lpSymbol: string.concat("LP-", params.name)
        });
        pool.index = params.index;
        pool.initialLiquidity = params.initialLiquidity;
        pool.minDepositAmount = params.minDepositAmount;
        pool.maxDepositAmount = params.maxDepositAmount;
        pool.minSwapAmount = params.minSwapAmount;
        pool.maxSwapAmount = params.maxSwapAmount;

        label(address(pool.asset), params.name);
        label(address(pool.pool), string.concat(params.name, "Pool"));
    }

    function getRandomPool(uint256 id)
        external
        view
        returns (Pool memory pool)
    {
        id = bound(id, 0, pools.length - 1);
        pool = pools[id];
    }
}
