// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContextProvider } from "./ContextProvider.sol";

import { AssetMock } from "./mocks/AssetMock.sol";
import { PoolMock } from "./mocks/PoolMock.sol";

import { PortfolioToken } from "../contracts/PortfolioToken.sol";

struct Pool {
    PoolMock pool;
    AssetMock asset;
    uint256 index;
}

contract CoreYieldContext is ContextProvider {
    Pool[1] pools;
    PortfolioToken public portfolioToken;

    constructor() {
        addUsers();

        // TODO: we add one pool first for testing
        pools[0] = deployPool(
            DeployPoolParams({ name: "USDT", decimals: 6, index: 0 })
        );
        // pools[1] = deployPool(
        //     DeployPoolParams({ name: "USDT", decimals: 18, index: 0 })
        // );
        // pools[2] = deployPool(
        //     DeployPoolParams({ name: "USDT", decimals: 18, index: 0 })
        // );

        portfolioToken = new PortfolioToken("Portfolio", "CYD");
        label(address(portfolioToken), "PortfolioToken");

        for (uint256 i = 0; i < pools.length; i++) {
            Pool memory pool = pools[i];
            portfolioToken.setPool(pool.index, pool.pool);
        }
    }

    struct DeployPoolParams {
        string name;
        uint8 decimals;
        uint256 index;
    }

    function deployPool(DeployPoolParams memory params)
        internal
        returns (Pool memory pool)
    {
        pool.asset = new AssetMock(params.name, params.name, params.decimals);
        pool.pool = new PoolMock(pool.asset);
        pool.index = params.index;

        label(address(pool.asset), string.concat(params.name, "Asset"));
        label(address(pool.pool), string.concat(params.name, "Pool"));
    }
}
