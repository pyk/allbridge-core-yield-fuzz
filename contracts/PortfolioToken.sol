// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPool } from "./interfaces/IPool.sol";
import { VirtualMultiToken } from "./VirtualMultiToken.sol";
import { MultiToken } from "./MultiToken.sol";
import "./lib/PoolUtils.sol";

import { console } from "../test/Test.sol";

contract PortfolioToken is Ownable, VirtualMultiToken {
    using SafeERC20 for IERC20;

    uint256 private constant SYSTEM_PRECISION = 3;
    uint256[NUM_TOKENS] private tokensPerSystem;

    IPool[NUM_TOKENS] public pools;
    IERC20[NUM_TOKENS] public tokens;

    event Deposited(
        address user, address token, uint256 amount, uint256 lpAmount
    );
    event Withdrawn(address user, address token, uint256 amount);
    event DepositedRewards(uint256 amount, address token);

    constructor(
        string memory tokenName_,
        string memory tokenSymbol_
    )
        VirtualMultiToken(tokenName_, tokenSymbol_)
    { }

    /**
     * @dev Deposit tokens into the pool.
     * @param amount The amount of tokens to deposit.
     * @param index The index of the pool to deposit to.
     */
    function deposit(uint256 amount, uint256 index) external {
        require(index < NUM_TOKENS, "Index out of range");
        IERC20 token = tokens[index];
        IPool pool = pools[index];
        require(address(pool) != address(0), "No pool");
        _subDepositRewardsPoolCheck(pool, index);

        // @audit EXTERNAL CALL
        // Transfer tokens from the user to the contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        // lp amount is the same as virtual token amount
        uint256 virtualAmountBefore = pool.balanceOf(address(this));

        // @audit EXTERNAL CALL
        // calculate sum of mint amount
        pool.deposit(amount);

        uint256 virtualAmountAfter = pool.balanceOf(address(this));
        uint256 virtualAmountDiff = virtualAmountAfter - virtualAmountBefore;
        _mintAfterTotalChanged(msg.sender, virtualAmountDiff, index);
        uint256[NUM_TOKENS] memory virtualAmounts;
        virtualAmounts[index] = virtualAmountDiff;

        emit Transfer(address(0), msg.sender, virtualAmountDiff);
        emit MultiTransfer(address(0), msg.sender, virtualAmounts);
        emit Deposited(msg.sender, address(token), amount, virtualAmountDiff);
    }

    /**
     * @dev This method allows for withdrawing a certain amount from all pools in proportion
     * @param virtualAmount The amount of virtual tokens to withdraw.
     */
    function withdraw(uint256 virtualAmount) external {
        console.log("* PortfolioToken.withdraw virtualAmount=%d", virtualAmount);

        // @audit EXTERNAL CALL
        depositRewards();

        uint256 totalVirtualBalance = balanceOf(msg.sender);
        console.log(
            "* PortfolioToken.withdraw totalVirtualBalance=%d",
            totalVirtualBalance
        );

        if (totalVirtualBalance == 0 || virtualAmount == 0) {
            return;
        }
        uint256[NUM_TOKENS] memory virtualAmounts = [
            _withdrawIndex(virtualAmount, totalVirtualBalance, 0),
            _withdrawIndex(virtualAmount, totalVirtualBalance, 1),
            _withdrawIndex(virtualAmount, totalVirtualBalance, 2),
            _withdrawIndex(virtualAmount, totalVirtualBalance, 3)
        ];
        emit Transfer(msg.sender, address(0), virtualAmount);
        emit MultiTransfer(msg.sender, address(0), virtualAmounts);
    }

    function _withdrawIndex(
        uint256 virtualAmount,
        uint256 totalVirtualBalance,
        uint256 index
    )
        internal
        returns (uint256 subVirtualAmount)
    {
        console.log(
            "* PortfolioToken._withdrawIndex virtualAmount=%d", virtualAmount
        );
        console.log(
            "* PortfolioToken._withdrawIndex totalVirtualBalance=%d",
            totalVirtualBalance
        );
        console.log("* PortfolioToken._withdrawIndex index=%d", index);

        IPool pool = pools[index];
        if (address(pool) == address(0)) {
            return 0;
        }

        uint256 subVirtualBalance =
            VirtualMultiToken.subBalanceOf(msg.sender, index);

        subVirtualAmount =
            (virtualAmount * subVirtualBalance) / totalVirtualBalance;

        console.log(
            "* PortfolioToken._withdrawIndex subVirtualBalance=%d",
            subVirtualBalance
        );
        console.log(
            "* PortfolioToken._withdrawIndex subVirtualAmount=%d",
            subVirtualAmount
        );

        if (subVirtualAmount == 0) {
            return 0;
        }
        _subWithdraw(subVirtualAmount, pool, index);
    }

    /**
     * @dev This method allows for withdrawing a certain amount from a specific pool.
     * @param virtualAmount the number of virtual tokens to be withdrawn.
     * @param index the index identifier of the pool where the action will occur.
     */
    function subWithdraw(uint256 virtualAmount, uint256 index) external {
        subDepositRewards(index);
        if (virtualAmount == 0) {
            return;
        }
        IPool pool = pools[index];
        require(address(pool) != address(0), "No pool");
        _subWithdraw(virtualAmount, pool, index);
        uint256[NUM_TOKENS] memory virtualAmounts;
        virtualAmounts[index] = virtualAmount;
        emit Transfer(msg.sender, address(0), virtualAmount);
        emit MultiTransfer(msg.sender, address(0), virtualAmounts);
    }

    function _subWithdraw(
        uint256 virtualAmount,
        IPool pool,
        uint256 index
    )
        private
    {
        console.log(
            "* PortfolioToken._subWithdraw virtualAmount=%d", virtualAmount
        );
        console.log("* PortfolioToken._subWithdraw index=%d", index);

        // Zero amount should be checked before
        IERC20 token = tokens[index];

        VirtualMultiToken._burn(msg.sender, virtualAmount, index);
        // should withdraw equal amount to virtualAmount (lpTokenAmount)
        pool.withdraw(virtualAmount);
        uint256 contractBalance = token.balanceOf(address(this));
        uint256 amountToWithdraw = virtualAmount * tokensPerSystem[index];
        amountToWithdraw = amountToWithdraw > contractBalance
            ? contractBalance
            : amountToWithdraw;
        token.safeTransfer(msg.sender, amountToWithdraw);

        console.log(
            "* PortfolioToken._subWithdraw contractBalance=%d", contractBalance
        );
        console.log(
            "* PortfolioToken._subWithdraw amountToWithdraw=%d",
            amountToWithdraw
        );

        emit Withdrawn(msg.sender, address(token), amountToWithdraw);
    }

    /**
     * @dev Claim and deposit rewards form all pools
     */
    function depositRewards() public {
        subDepositRewards(0);
        subDepositRewards(1);
        subDepositRewards(2);
        subDepositRewards(3);
    }

    /**
     * @dev Claim and deposit rewards of a specified pool
     * @param index The index of the pool for which rewards are to be deposited.
     */
    function subDepositRewards(uint256 index) public {
        console.log("* PortfolioToken.subDepositRewards index=%d", index);

        require(index < NUM_TOKENS, "Index out of range");
        IPool pool = pools[index];
        if (address(pool) == address(0)) {
            return;
        }

        _subDepositRewardsPoolCheck(pool, index);
    }

    function _subDepositRewardsPoolCheck(IPool pool, uint256 index) private {
        IERC20 token = tokens[index];

        // @audit EXTERNAL CALL
        pool.claimRewards();

        // @audit EXTERNAL CALL
        // deposit all contract token balance
        uint256 balance = token.balanceOf(address(this));

        console.log(
            "* PortfolioToken._subDepositRewardsPoolCheck balance=%d", balance
        );
        console.log(
            "* PortfolioToken._subDepositRewardsPoolCheck tokensPerSystem[index]=%d",
            tokensPerSystem[index]
        );

        if ((balance / tokensPerSystem[index]) > 0) {
            // @audit EXTERNAL CALL
            pool.deposit(balance);
            emit DepositedRewards(balance, address(token));
        }
    }

    /**
     * @dev This function sets up a pool for a specific index. Reverted if an existing pool is already set up at this index.
     * Only the owner of the contract can call this function.
     * @param index The index to set the pool.
     * @param pool The new pool to be set.
     */
    function setPool(uint256 index, IPool pool) external onlyOwner {
        require(address(pool) != address(0), "Zero pool address");
        require(index < NUM_TOKENS, "Index out of range");
        require(address(pools[index]) == address(0), "Already exists");
        require(pool.decimals() == SYSTEM_PRECISION, "Wrong pool decimals");
        pools[index] = pool;

        IERC20Metadata token = pool.token();
        require(address(token) != address(0), "Zero token address");
        tokens[index] = token;
        IERC20(token).forceApprove(address(pool), type(uint256).max);

        uint256 tokenDecimals = token.decimals();
        require(tokenDecimals >= SYSTEM_PRECISION, "Token precision too low");
        tokensPerSystem[index] = 10 ** (tokenDecimals - SYSTEM_PRECISION);
    }

    function getWithdrawProportionAmount(
        address user,
        uint256 virtualAmount
    )
        public
        view
        returns (uint256[NUM_TOKENS] memory)
    {
        uint256 totalVirtualBalance = balanceOf(user);
        uint256[NUM_TOKENS] memory amounts;
        if (totalVirtualBalance == 0 || virtualAmount == 0) {
            return amounts;
        }

        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            uint256 virtualBalance = VirtualMultiToken.subBalanceOf(user, i);
            amounts[i] = (
                (virtualAmount * virtualBalance) / totalVirtualBalance
            ) * tokensPerSystem[i];
        }

        return amounts;
    }

    function getEstimatedAmountOnDeposit(
        uint256 amount,
        uint256 index
    )
        public
        view
        returns (uint256)
    {
        require(index < NUM_TOKENS, "Index out of range");
        IPool pool = pools[index];
        if (address(pool) == address(0)) {
            return 0;
        }

        uint256 rewardsAmountSP =
            getRewardsAmount(index) / tokensPerSystem[index];
        uint256 amountSP = amount / tokensPerSystem[index];
        require(amountSP > 0, "Amount is too small");
        uint256 oldD = pool.d();
        uint256 tokenBalance = pool.tokenBalance();
        uint256 vUsdBalance = pool.vUsdBalance();

        if (rewardsAmountSP > 0) {
            (tokenBalance, vUsdBalance, oldD) = PoolUtils.changeStateOnDeposit(
                tokenBalance, vUsdBalance, oldD, rewardsAmountSP
            );
        }
        uint256 newD;
        (tokenBalance, vUsdBalance, newD) = PoolUtils.changeStateOnDeposit(
            tokenBalance, vUsdBalance, oldD, amountSP
        );

        return newD > oldD ? newD - oldD : 0;
    }

    function getRewardsAmount(uint256 index) public view returns (uint256) {
        require(index < NUM_TOKENS, "Index out of range");
        IPool pool = pools[index];
        if (address(pool) == address(0)) {
            return 0;
        }
        uint256 lpAmount = pool.balanceOf(address(this));
        uint256 rewardDebt = pool.userRewardDebt(address(this));
        return
            ((lpAmount * pool.accRewardPerShareP()) >> PoolUtils.P) - rewardDebt;
    }

    /**
     * @dev Override parent class's function. This function returns the total amount of virtual tokens for a specific pool.
     * @param index The index identifying the specific pool.
     * @return The total amount of virtual tokens in the specified pool.
     */
    function _totalVirtualAmount(uint256 index)
        internal
        view
        override
        returns (uint256)
    {
        require(index < NUM_TOKENS, "Index out of range");
        IPool pool = pools[index];
        if (address(pool) == address(0)) {
            return 0;
        }
        return pool.balanceOf(address(this));
    }

    fallback() external payable {
        revert("Unsupported");
    }

    receive() external payable { }
}
