// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Vm {
    function label(address account, string calldata newLabel) external;

    // Sets the *next* call's msg.sender to be the input address
    function prank(address) external;

    // Computes address for a given private key
    function addr(uint256 privateKey) external returns (address);

    function toString(address) external view returns (string memory);
    function toString(bytes calldata) external view returns (string memory);
    function toString(bytes32) external view returns (string memory);
    function toString(bool) external view returns (string memory);
    function toString(uint256) external view returns (string memory);
    function toString(int256) external view returns (string memory);
}

contract Test {
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 private constant INT256_MIN_ABS =
        57896044618658097711785492504343953926634992332820282019728792003956564819968;

    mapping(address => string) labeledAddress;

    // creates a labeled address
    function makeAddr(string memory name)
        internal
        virtual
        returns (address addr)
    {
        (addr,) = makeAddrAndKey(name);
    }

    // creates a labeled address and the corresponding private key
    function makeAddrAndKey(string memory name)
        internal
        virtual
        returns (address addr, uint256 privateKey)
    {
        privateKey = uint256(keccak256(abi.encodePacked(name)));
        addr = vm.addr(privateKey);
        label(addr, name);
    }

    function label(address account, string memory name) internal {
        vm.label(account, name);
        labeledAddress[account] = name;
    }

    function getLabel(address account)
        public
        view
        returns (string memory name)
    {
        name = labeledAddress[account];
    }

    function _bound(
        uint256 x,
        uint256 min,
        uint256 max
    )
        internal
        pure
        virtual
        returns (uint256 result)
    {
        require(
            min <= max,
            "StdUtils bound(uint256,uint256,uint256): Max is less than min."
        );
        // If x is between min and max, return x directly. This is to ensure that
        // dictionary values
        // do not get shifted if the min is nonzero. More info:
        // https://github.com/foundry-rs/forge-std/issues/188
        if (x >= min && x <= max) {
            return x;
        }

        uint256 size = max - min + 1;

        // If the value is 0, 1, 2, 3, wrap that to min, min+1, min+2, min+3.
        // Similarly for the UINT256_MAX side.
        // This helps ensure coverage of the min/max values.
        if (x <= 3 && size > x) {
            return min + x;
        }
        if (x >= type(uint256).max - 3 && size > type(uint256).max - x) {
            return max - (type(uint256).max - x);
        }

        // Otherwise, wrap x into the range [min, max], i.e. the range is inclusive.
        if (x > max) {
            uint256 diff = x - max;
            uint256 rem = diff % size;
            if (rem == 0) {
                return max;
            }
            result = min + rem - 1;
        } else if (x < min) {
            uint256 diff = min - x;
            uint256 rem = diff % size;
            if (rem == 0) {
                return min;
            }
            result = max - rem + 1;
        }
    }

    function bound(
        uint256 x,
        uint256 min,
        uint256 max
    )
        internal
        pure
        virtual
        returns (uint256 result)
    {
        result = _bound(x, min, max);
    }

    function _bound(
        int256 x,
        int256 min,
        int256 max
    )
        internal
        pure
        virtual
        returns (int256 result)
    {
        require(
            min <= max,
            "StdUtils bound(int256,int256,int256): Max is less than min."
        );

        // Shifting all int256 values to uint256 to use _bound function. The range
        // of two types are:
        // int256 : -(2**255) ~ (2**255 - 1)
        // uint256:     0     ~ (2**256 - 1)
        // So, add 2**255, INT256_MIN_ABS to the integer values.
        //
        // If the given integer value is -2**255, we cannot use `-uint256(-x)`
        // because of the overflow.
        // So, use `~uint256(x) + 1` instead.
        uint256 _x = x < 0
            ? (INT256_MIN_ABS - ~uint256(x) - 1)
            : (uint256(x) + INT256_MIN_ABS);
        uint256 _min = min < 0
            ? (INT256_MIN_ABS - ~uint256(min) - 1)
            : (uint256(min) + INT256_MIN_ABS);
        uint256 _max = max < 0
            ? (INT256_MIN_ABS - ~uint256(max) - 1)
            : (uint256(max) + INT256_MIN_ABS);

        uint256 y = _bound(_x, _min, _max);

        // To move it back to int256 value, subtract INT256_MIN_ABS at here.
        result = y < INT256_MIN_ABS
            ? int256(~(INT256_MIN_ABS - y) + 1)
            : int256(y - INT256_MIN_ABS);
    }

    function bound(
        int256 x,
        int256 min,
        int256 max
    )
        internal
        pure
        virtual
        returns (int256 result)
    {
        result = _bound(x, min, max);
    }

    /**
     * @notice Checks if the difference between `a` and `b` is less than a
     * specified number of basis points.
     * @param a The first value to compare.
     * @param b The second value to compare.
     * @param allowedBps The maximum allowed difference in basis points (e.g., for
     * 0.5%, pass 50).
     * @return bool Returns true if the difference is within the allowed
     * tolerance, otherwise false.
     */
    function isDeltaLessThanBps(
        uint256 a,
        uint256 b,
        uint256 allowedBps
    )
        internal
        pure
        returns (bool)
    {
        // If the numbers are equal, the delta is 0, which is always less than the
        // allowed BPS.
        if (a == b) {
            return true;
        }

        uint256 delta = a > b ? a - b : b - a;
        uint256 maxVal = a > b ? a : b;

        // Return the result of the boolean comparison.
        // This is the rearranged formula: `delta / maxVal < allowedBps / 10000`
        return delta * 10000 < allowedBps * maxVal;
    }

    //*============================================================
    //* Assertions
    //*============================================================

    function halt(string memory reason) internal {
        console.log("%s", reason);
        assert(false);
    }

    function eq(uint256 a, uint256 b, string memory reason) internal {
        if (a != b) {
            string memory message = string.concat(
                "Invalid: ",
                vm.toString(a),
                "!=",
                vm.toString(b),
                ", reason: ",
                reason
            );
            console.log("%s", message);
            assert(false);
        }
    }

    function eqWithTolerance(
        uint256 a,
        uint256 b,
        uint256 tolerance,
        string memory reason
    )
        internal
    {
        uint256 delta = a > b ? a - b : b - a;

        if (delta > tolerance) {
            string memory message = string.concat(
                "Invalid: |",
                vm.toString(a),
                " - ",
                vm.toString(b),
                "| (",
                vm.toString(delta),
                ") > ",
                vm.toString(tolerance),
                ", reason: ",
                reason
            );
            console.log("%s", message);
            assert(false);
        }
    }
}

library console {
    address constant CONSOLE_ADDRESS =
        0x000000000000000000636F6e736F6c652e6c6f67;

    function _sendLogPayloadImplementation(bytes memory payload)
        internal
        view
    {
        address consoleAddress = CONSOLE_ADDRESS;
        /// @solidity memory-safe-assembly
        assembly {
            pop(
                staticcall(
                    gas(),
                    consoleAddress,
                    add(payload, 32),
                    mload(payload),
                    0,
                    0
                )
            )
        }
    }

    function _castToPure(function(bytes memory) internal view fnIn)
        internal
        pure
        returns (function(bytes memory) pure fnOut)
    {
        assembly {
            fnOut := fnIn
        }
    }

    function _sendLogPayload(bytes memory payload) internal pure {
        _castToPure(_sendLogPayloadImplementation)(payload);
    }

    function log(string memory p0, string memory p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
    }

    function log(string memory p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function log(string memory p0, uint256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
    }

    function log(string memory p0, int256 p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,int256)", p0, p1));
    }

    function log(string memory p0, bool p1) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
    }
}

library property {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function eq(
        string memory description,
        uint256 a,
        uint256 b
    )
        internal
        view
        returns (bool)
    {
        if (a != b) {
            string memory message = string.concat(
                "Property Failed: ",
                description,
                " | Assertion: ",
                vm.toString(a),
                " != ",
                vm.toString(b)
            );
            console.log("%s", message);
            return false;
        }
        return true;
    }

    function eq(
        string memory description,
        uint256 a,
        uint256 b,
        uint256 tolerance
    )
        internal
        view
        returns (bool)
    {
        uint256 delta = a > b ? a - b : b - a;
        if (delta > tolerance) {
            string memory message = string.concat(
                "Property Failed: ",
                description,
                " | Assertion: |",
                vm.toString(a),
                " - ",
                vm.toString(b),
                "| (",
                vm.toString(delta),
                ") > ",
                vm.toString(tolerance)
            );
            console.log("%s", message);
            return false;
        }
        return true;
    }
}

library expect {
    function eq(string memory description, uint256 a, uint256 b) internal {
        assert(property.eq(description, a, b));
    }

    function eq(
        string memory description,
        uint256 a,
        uint256 b,
        uint256 tolerance
    )
        internal
    {
        assert(property.eq(description, a, b, tolerance));
    }
}
