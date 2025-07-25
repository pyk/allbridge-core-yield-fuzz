// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library PoolUtils {
    uint256 internal constant P = 52;
    uint256 internal constant A = 20;

    function getD(
        uint256 x,
        uint256 y,
        uint256 a
    )
        internal
        pure
        returns (uint256 d)
    {
        // a = 8 * Axy(x+y)
        // b = 4 * xy(4A - 1) / 3
        // c = sqrt(a² + b³)
        // D = cbrt(a + c) + cbrt(a - c)
        uint256 xy = x * y;
        uint256 a_ = a;
        // Axy(x+y)
        uint256 p1 = a_ * xy * (x + y);
        // xy(4A - 1) / 3
        uint256 p2 = (xy * ((a_ << 2) - 1)) / 3;
        // p1² + p2³
        uint256 p3 = _sqrt((p1 * p1) + (p2 * p2 * p2));
        unchecked {
            uint256 d_ = _cbrt(p1 + p3);
            if (p3 > p1) {
                d_ -= _cbrt(p3 - p1);
            } else {
                d_ += _cbrt(p1 - p3);
            }
            d = (d_ << 1);
        }
    }

    function _sqrt(uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n > 0) {
                uint256 x = (n >> 1) + 1;
                uint256 y = (x + n / x) >> 1;
                while (x > y) {
                    x = y;
                    y = (x + n / x) >> 1;
                }
                return x;
            }
            return 0;
        }
    }

    function _cbrt(uint256 n) internal pure returns (uint256) {
        unchecked {
            uint256 x = 0;
            for (uint256 y = 1 << 255; y > 0; y >>= 3) {
                x <<= 1;
                uint256 z = 3 * x * (x + 1) + 1;
                if (n / y >= z) {
                    n -= y * z;
                    x += 1;
                }
            }
            return x;
        }
    }

    function changeStateOnDeposit(
        uint256 tokenBalance,
        uint256 vUsdBalance,
        uint256 oldD,
        uint256 amountSP
    )
        internal
        pure
        returns (uint256, uint256, uint256)
    {
        uint256 oldBalance = (tokenBalance + vUsdBalance);
        if (oldD == 0 || oldBalance == 0) {
            // Split balance equally on the first deposit
            uint256 halfAmount = amountSP >> 1;
            tokenBalance += halfAmount;
            vUsdBalance += halfAmount;
        } else {
            // Add amount proportionally to each pool
            tokenBalance += (amountSP * tokenBalance) / oldBalance;
            vUsdBalance += (amountSP * vUsdBalance) / oldBalance;
        }

        oldD = PoolUtils.getD(tokenBalance, vUsdBalance, PoolUtils.A);
        return (tokenBalance, vUsdBalance, oldD);
    }
}
