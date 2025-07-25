// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPool } from "./interfaces/IPool.sol";
import { MultiToken } from "./MultiToken.sol";

abstract contract VirtualMultiToken is MultiToken {
    using SafeERC20 for ERC20;

    constructor(
        string memory tokenName_,
        string memory tokenSymbol_
    )
        MultiToken(tokenName_, tokenSymbol_)
    { }

    /**
     * @dev Abstract function to get total virtual amount for sub-token
     * @param index The index of the value we want to get
     * @return A uint value representing the virtual balance of the specified sub-token
     */
    function _totalVirtualAmount(uint256 index)
        internal
        view
        virtual
        returns (uint256);

    /**
     * @dev This internal function transfers an amount of tokens from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param virtualAmount The total amount of virtual tokens to be transferred.
     */
    function _transfer(
        address from,
        address to,
        uint256 virtualAmount
    )
        internal
        virtual
        override
    {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(virtualAmount > 0, "ERC20: transfer zero amount");

        uint256 totalVirtualBalance = balanceOf(from);

        require(
            totalVirtualBalance >= virtualAmount,
            "ERC20: transfer amount exceeds balance"
        );

        uint256[NUM_TOKENS] memory virtualAmounts = [
            _transferIndex(from, to, virtualAmount, totalVirtualBalance, 0),
            _transferIndex(from, to, virtualAmount, totalVirtualBalance, 1),
            _transferIndex(from, to, virtualAmount, totalVirtualBalance, 2),
            _transferIndex(from, to, virtualAmount, totalVirtualBalance, 3)
        ];

        emit Transfer(from, to, virtualAmount);
        emit MultiTransfer(from, to, virtualAmounts);
    }

    /**
     * @dev This internal function to transform virtual amount to real and execute transfer
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param virtualAmount The total amount of virtual tokens to be transferred.
     * @param totalVirtualBalance The total balance of the `from` address.
     * @param index The index of the sub-token to transfer.
     * @return A uint representing the amount of sub-tokens transferred.
     *
     */
    function _transferIndex(
        address from,
        address to,
        uint256 virtualAmount,
        uint256 totalVirtualBalance,
        uint256 index
    )
        internal
        returns (uint256)
    {
        uint256 subVirtualBalance = subBalanceOf(from, index);
        uint256 subVirtualAmount =
            Math.ceilDiv(virtualAmount * subVirtualBalance, totalVirtualBalance);
        MultiToken._singleTransfer(
            from, to, _fromVirtual(subVirtualAmount, index), index
        );

        return subVirtualAmount;
    }

    /**
     * @dev Function to mint virtual tokens
     * @param account The address to mint tokens to.
     * @param virtualAmount The total amount of virtual tokens to be minted.
     * @param index The index of the sub-token to mint.
     */
    function _mintAfterTotalChanged(
        address account,
        uint256 virtualAmount,
        uint256 index
    )
        internal
        virtual
    {
        uint256 realAmount =
            _fromVirtualAfterTotalChangedForMint(virtualAmount, index);
        if (realAmount == 0) {
            return;
        }
        return MultiToken._mint(account, realAmount, index);
    }

    /**
     * @dev Overridden function to burn virtual tokens
     * @param account The address to burn tokens from.
     * @param virtualAmount The total amount of virtual tokens to be burnt.
     * @param index The index of the sub-token to burn.
     */
    function _burn(
        address account,
        uint256 virtualAmount,
        uint256 index
    )
        internal
        virtual
        override
    {
        uint256 realAmount = _fromVirtual(virtualAmount, index);
        return MultiToken._burn(account, realAmount, index);
    }

    /**
     * @dev This internal function handles the transfer of a virtual sub-token from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param virtualAmount The total amount of virtual tokens to be transferred.
     * @param index The index of the sub-token to transfer.
     */
    function _subTransfer(
        address from,
        address to,
        uint256 virtualAmount,
        uint256 index
    )
        internal
        virtual
        override
    {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(virtualAmount > 0, "ERC20: transfer zero amount");

        MultiToken._singleTransfer(
            from, to, _fromVirtual(virtualAmount, index), index
        );

        uint256[NUM_TOKENS] memory virtualAmounts;
        virtualAmounts[index] = virtualAmount;

        emit Transfer(from, to, virtualAmount);
        emit MultiTransfer(from, to, virtualAmounts);
    }

    /**
     * @dev Override function of ERC20. Calculates and returns the current total supply for the Token.
     * Returns the sum of virtual amounts for all the sub-tokens.
     * @return The uint value representing the current total virtual supply of the token.
     */
    function totalSupply() public view virtual override returns (uint256) {
        unchecked {
            uint256 result = _totalVirtualAmount(0);
            result += _totalVirtualAmount(1);
            result += _totalVirtualAmount(2);
            return result + _totalVirtualAmount(3);
        }
    }

    /**
     * @dev Function to get total virtual balance for account
     * @param account The address of the account
     * @return A uint value representing the virtual balance of the specified account
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        unchecked {
            uint256 totalVirtualAmount =
                _toVirtual(MultiToken.subBalanceOfUnchecked(account, 0), 0);
            totalVirtualAmount +=
                _toVirtual(MultiToken.subBalanceOfUnchecked(account, 1), 1);
            totalVirtualAmount +=
                _toVirtual(MultiToken.subBalanceOfUnchecked(account, 2), 2);
            return totalVirtualAmount
                + _toVirtual(MultiToken.subBalanceOfUnchecked(account, 3), 3);
        }
    }

    /**
     * @dev Get the balance of the specified address for the sub-token at the given index.
     * @param account The address of the account to check.
     * @param index The index of the sub-token.
     * @return The virtual balance of the specified account for the sub-token at the given index.
     */
    function subBalanceOf(
        address account,
        uint256 index
    )
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _toVirtual(MultiToken.subBalanceOf(account, index), index);
    }

    /**
     * @dev Returns total virtual amount for the sub-token at the specified index
     * @param index The index of the sub-token whose virtual total amount to fetch
     * @return total virtual amount of the sub-token at the given index
     */
    function subTotalSupply(uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _totalVirtualAmount(index);
    }

    // Amount is always come from subValue, so it is impossible to get an overflow on the multiplication
    function _toVirtual(
        uint256 realAmount,
        uint256 index
    )
        internal
        view
        returns (uint256 out)
    {
        uint256 realTotal = MultiToken.subTotalSupply(index);
        uint256 totalVirtual = _totalVirtualAmount(index);
        if (realTotal == 0 || totalVirtual == 0) {
            return 0;
        }

        // totalVirtual * amount / realTotal
        assembly {
            out := div(mul(totalVirtual, realAmount), realTotal)
        }
    }

    function _fromVirtual(
        uint256 virtualAmount,
        uint256 index
    )
        private
        view
        returns (uint256 out)
    {
        uint256 realTotal = MultiToken.subTotalSupply(index);
        uint256 totalVirtual = _totalVirtualAmount(index);
        if (realTotal == 0 || totalVirtual == 0) {
            return 0;
        }

        require(totalVirtual >= virtualAmount, "Amount more than total");

        // realTotal - ((totalVirtual - amount) * realTotal / totalVirtual)
        assembly {
            out :=
                sub(
                    realTotal,
                    div(
                        mul(sub(totalVirtual, virtualAmount), realTotal),
                        totalVirtual
                    )
                )
        }
    }

    function _fromVirtualAfterTotalChangedForMint(
        uint256 virtualAmount,
        uint256 index
    )
        private
        view
        returns (uint256 out)
    {
        uint256 realTotal = MultiToken.subTotalSupply(index);
        if (realTotal == 0) {
            return virtualAmount;
        }
        uint256 totalVirtualAmount = _totalVirtualAmount(index);
        require(
            totalVirtualAmount >= virtualAmount, "Virtual amount exceeds total"
        );
        uint256 totalVirtual = totalVirtualAmount - virtualAmount;
        if (totalVirtual == 0) {
            return 0;
        }

        // amount * realTotal / totalVirtual
        // amount could be grater than totalVirtual
        assembly {
            out := div(mul(virtualAmount, realTotal), totalVirtual)
        }
    }
}
