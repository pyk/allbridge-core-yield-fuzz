# Allbridge Core Yield contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?

Celo

---

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?

Tokens are whitelisted, only USDT token (https://celoscan.io/address/0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e) is added.

---

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?

Owner is trusted

---

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?

No

---

### Q: Is the codebase expected to comply with any specific EIPs?

No

---

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.

No

---

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?

No

---

### Q: Please discuss any design choices you made.

There is a small loss of precision in some cases, the goal is to keep it to the minimum and to the advantage of the contract. Precision loss to the advantage of the contract is acceptable risk. However, if there’s a precision loss to the advantage of the user and its higher than the gas cost, it may be viewed as a Medium severity issue.

---

### Q: Please list any relevant protocol resources.

https://core.allbridge.io/yield
There is no separate resources for documentation or the whitepaper

# Audit scope

[core-auto-evm-contracts @ d79882a8a7f2793cb3f7fcb21a9b317a7639846a](https://github.com/allbridge-public/core-auto-evm-contracts/tree/d79882a8a7f2793cb3f7fcb21a9b317a7639846a)

- [core-auto-evm-contracts/contracts/lib/MultiUint.sol](core-auto-evm-contracts/contracts/lib/MultiUint.sol)
- [core-auto-evm-contracts/contracts/lib/PoolUtils.sol](core-auto-evm-contracts/contracts/lib/PoolUtils.sol)
- [core-auto-evm-contracts/contracts/MultiToken.sol](core-auto-evm-contracts/contracts/MultiToken.sol)
- [core-auto-evm-contracts/contracts/PortfolioToken.sol](core-auto-evm-contracts/contracts/PortfolioToken.sol)
- [core-auto-evm-contracts/contracts/VirtualMultiToken.sol](core-auto-evm-contracts/contracts/VirtualMultiToken.sol)
