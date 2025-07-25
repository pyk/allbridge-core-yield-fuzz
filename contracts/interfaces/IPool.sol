// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPool {
    function tokenBalance() external view returns (uint256);
    function vUsdBalance() external view returns (uint256);
    function d() external view returns (uint256);
    function getY(uint256 x) external view returns (uint256);
    function accRewardPerShareP() external view returns (uint256);
    function userRewardDebt(address user) external view returns (uint256);
    function token() external view returns (ERC20);
    function balanceOf(address user) external view returns (uint256);
    function decimals() external pure returns (uint8);
    function pendingReward(address user) external view returns (uint256);
    function deposit(uint256 amount) external;
    function claimRewards() external;
    function withdraw(uint256 amountLp) external;
}
