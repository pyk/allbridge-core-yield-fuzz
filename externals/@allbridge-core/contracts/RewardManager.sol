// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardManager is Ownable, ERC20 {
    using SafeERC20 for ERC20;

    uint256 private constant P = 52;
    uint256 internal constant BP = 1e4;

    // Accumulated rewards per share, shifted left by P bits
    uint256 public accRewardPerShareP;

    // Reward token
    ERC20 public immutable token;
    // Info of each user reward debt
    mapping(address user => uint256 amount) public userRewardDebt;

    // Admin fee share (in basis points)
    uint256 public adminFeeShareBP;
    // Unclaimed admin fee amount
    uint256 public adminFeeAmount;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(
        ERC20 token_,
        string memory lpName,
        string memory lpSymbol
    )
        ERC20(lpName, lpSymbol)
    {
        token = token_;
        // Default admin fee is 20%
        adminFeeShareBP = BP / 5;
    }

    /**
     * @notice Claims pending rewards for the current staker without updating the stake balance.
     */
    function claimRewards() external {
        uint256 userLpAmount = balanceOf(msg.sender);
        if (userLpAmount > 0) {
            uint256 rewards = (userLpAmount * accRewardPerShareP) >> P;
            uint256 pending = rewards - userRewardDebt[msg.sender];
            if (pending > 0) {
                userRewardDebt[msg.sender] = rewards;
                token.safeTransfer(msg.sender, pending);
                emit RewardsClaimed(msg.sender, pending);
            }
        }
    }

    /**
     * @notice Sets the basis points of the admin fee share from rewards.
     */
    function setAdminFeeShare(uint256 adminFeeShareBP_) external onlyOwner {
        require(adminFeeShareBP_ <= BP, "RewardManager: too high");
        adminFeeShareBP = adminFeeShareBP_;
    }

    /**
     * @notice Allows the admin to claim the collected admin fee.
     */
    function claimAdminFee() external onlyOwner {
        if (adminFeeAmount > 0) {
            token.safeTransfer(msg.sender, adminFeeAmount);
            adminFeeAmount = 0;
        }
    }

    /**
     * @notice Returns pending rewards for the staker.
     * @param user The address of the staker.
     */
    function pendingReward(address user) external view returns (uint256) {
        return
            ((balanceOf(user) * accRewardPerShareP) >> P) - userRewardDebt[user];
    }

    /**
     * @dev Returns the number of decimals used to get user representation of LP tokens.
     */
    function decimals() public pure override returns (uint8) {
        return 3;
    }

    /**
     * @dev Adds reward to the pool, splits admin fee share and updates the accumulated rewards per share.
     */
    function _addRewards(uint256 rewardAmount) internal {
        if (totalSupply() > 0) {
            uint256 adminFeeRewards = (rewardAmount * adminFeeShareBP) / BP;
            unchecked {
                rewardAmount -= adminFeeRewards;
            }
            accRewardPerShareP += (rewardAmount << P) / totalSupply();
            adminFeeAmount += adminFeeRewards;
        }
    }

    /**
     * @dev Deposits LP amount for the user, updates user reward debt and pays pending rewards.
     */
    function _depositLp(address to, uint256 lpAmount) internal {
        uint256 pending;
        uint256 userLpAmount = balanceOf(to); // Gas optimization
        if (userLpAmount > 0) {
            pending =
                ((userLpAmount * accRewardPerShareP) >> P) - userRewardDebt[to];
        }
        userLpAmount += lpAmount;
        _mint(to, lpAmount);
        userRewardDebt[to] = (userLpAmount * accRewardPerShareP) >> P;
        if (pending > 0) {
            token.safeTransfer(to, pending);
            emit RewardsClaimed(to, pending);
        }
        emit Deposit(to, lpAmount);
    }

    /**
     * @dev Withdraws LP amount for the user, updates user reward debt and pays out pending rewards.
     */
    function _withdrawLp(address from, uint256 lpAmount) internal {
        uint256 userLpAmount = balanceOf(from); // Gas optimization
        require(userLpAmount >= lpAmount, "RewardManager: not enough amount");
        uint256 pending;
        if (userLpAmount > 0) {
            pending = ((userLpAmount * accRewardPerShareP) >> P)
                - userRewardDebt[from];
        }
        userLpAmount -= lpAmount;
        _burn(from, lpAmount);
        userRewardDebt[from] = (userLpAmount * accRewardPerShareP) >> P;
        if (pending > 0) {
            token.safeTransfer(from, pending);
            emit RewardsClaimed(from, pending);
        }
        emit Withdraw(from, lpAmount);
    }

    function _transfer(address, address, uint256) internal pure override {
        revert("Unsupported");
    }

    function _approve(address, address, uint256) internal pure override {
        revert("Unsupported");
    }
}
