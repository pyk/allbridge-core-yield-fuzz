// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { MultiUint } from "./lib/MultiUint.sol";

abstract contract MultiToken is Context, IERC20, IERC20Metadata {
    using MultiUint for uint256;

    uint256 public constant NUM_TOKENS = 4;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    event MultiTransfer(
        address indexed from, address indexed to, uint256[NUM_TOKENS] values
    );

    /**
     * @dev Function stub for _transfer functionality. Needs to be implemented in child contracts.
     * _transfer needs to perform the necessary logic to transfer tokens from one
     * account to another.
     * @param from Account to transfer tokens from.
     * @param to Account to transfer tokens to.
     * @param amount Amount of tokens to be transferred.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual;

    /**
     * @notice SubTransfer functionality for internal transfers. Needs to be implemented in child contracts.
     * @dev The `_subTransfer` is a function stub for handling functionality related to transferring sub-tokens. It is meant to be overridden by child contracts to provide specific sub-token transfer implementations.
     * @param from The address from which the sub-tokens will be transferred.
     * @param to The address to which the sub-tokens will be transferred.
     * @param amount The amount of sub-tokens to be transferred.
     * @param index The index identifying the specific sub-token to be transferred.
     */
    function _subTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 index
    )
        internal
        virtual;

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure override returns (uint8) {
        return 3;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply.totalValue();
    }

    /**
     * @dev Get the total supply of a specific sub-token
     * @param index The index of the sub-token
     * @return Returns the total supply of the specified sub-token
     */
    function subTotalSupply(uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        return _totalSupply.getValue(index);
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account].totalValue();
    }

    /**
     * @dev Returns the balance of a specific sub-token for the given account.
     * @param account The address of the account to query
     * @param index The index of the sub-token to query
     * @return Returns the balance of the specified sub-token for the given account
     */
    function subBalanceOf(
        address account,
        uint256 index
    )
        public
        view
        virtual
        returns (uint256)
    {
        return _balances[account].getValue(index);
    }

    /**
     * @dev Returns the balance of a specific sub-token for the given account without checking if the index is within a valid range.
     * @param account The address of the account to query
     * @param index The index of the sub-token to query
     * @return Returns the unchecked balance of the specified sub-token for the given account
     */
    function subBalanceOfUnchecked(
        address account,
        uint256 index
    )
        internal
        view
        virtual
        returns (uint256)
    {
        return _balances[account].getValueUnchecked(index);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address to,
        uint256 amount
    )
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @notice SubToken transfer. Transfers the specified amount of a sub-token from the caller to the specified address.
     * @dev This reduces the caller's balance of the specified sub-token by the specified amount and increases the receiver's balance of the specified sub-token by the same amount.
     * @param to The address of the recipient of the tokens.
     * @param amount The amount of specific sub-token to be transferred.
     * @param index The index of the specific sub-token to be transferred.
     * @return Returns a boolean value indicating whether the operation succeeded or not.
     */
    function subTransfer(
        address to,
        uint256 amount,
        uint256 index
    )
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _subTransfer(owner, to, amount, index);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    )
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(
        address spender,
        uint256 amount
    )
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @notice SubToken transfer from one address to another. This is an extended functionality from ERC20's `transferFrom()`, but for a specific `sub-token`.
     * @dev This method is used to transfer a certain amount of a specific sub-token from `from` to `to` address. This requires the caller to have enough allowance to do so.
     * @param from The address of the sender, from whom the tokens will be transferred.
     * @param to The address of the recipient, who will receive the transferred tokens.
     * @param amount The amount of sub-tokens to be transferred.
     * @param index The index of the sub-token to be transferred.
     * @return Returns a boolean value indicating whether the operation succeeded or not.
     */
    function subTransferFrom(
        address from,
        address to,
        uint256 amount,
        uint256 index
    )
        public
        virtual
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _subTransfer(from, to, amount, index);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(
        address spender,
        uint256 addedValue
    )
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    )
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev This function is used to facilitate a transfer from one account to another.
     * This particular function supports transfers of a single sub-token type only.
     * The caller must emit the Transfer event itself.
     * @param from - The account from which the tokens will be subtracted
     * @param to - The account to which the tokens will be added
     * @param amount - The amount of tokens to be transferred
     * @param index - The index of the sub-token type to be transferred
     */
    function _singleTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 index
    )
        internal
        virtual
    {
        _balances[from] = _balances[from].subValue(index, amount);
        _balances[to] = _balances[to].addValue(index, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     * The caller must emit the Transfer event itself.
     * Emits a {MintedReal} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(
        address account,
        uint256 amount,
        uint256 index
    )
        internal
        virtual
    {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.addValue(index, amount);

        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] =
                _balances[account].addValueUnchecked(index, amount);
        }
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {BurnedReal} event.
     * The caller must emit the Transfer event itself.
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(
        address account,
        uint256 amount,
        uint256 index
    )
        internal
        virtual
    {
        require(account != address(0), "ERC20: burn from the zero address");
        // Do nothing if the amount is zero
        if (amount == 0) {
            return;
        }

        uint256 rawBalance = _balances[account];

        uint256 accountBalance = rawBalance.getValue(index);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = rawBalance.subValueUnchecked(index, amount);
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply = _totalSupply.subValueUnchecked(index, amount);
        }
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    )
        internal
        virtual
    {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    )
        internal
        virtual
    {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
