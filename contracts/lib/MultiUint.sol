// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library MultiUint {
    uint256 private constant NUM_VALUES = 4;
    // 256 / NUM_VALUES
    uint256 private constant VALUE_BITS = 64;
    //  (1 << VALUE_BITS) - 1
    uint256 private constant VALUE_MASK = 0xFFFFFFFFFFFFFFFF; // Mask for a value

    /**
     * @dev Gets the value at the provided index from a packed uint.
     *      This function includes an index check to ensure the index provided is within the range of accepted values.
     *      It retrieves a value from the packed uint at the specified index.
     * @param packed The packed uint from which to retrieve a value.
     * @param index The index of the value to retrieve from the packed uint.
     * @return The value at the specified index in the packed uint.
     */
    function getValue(
        uint256 packed,
        uint256 index
    )
        internal
        pure
        returns (uint256)
    {
        require(index < NUM_VALUES, "Index out of range");

        return getValueUnchecked(packed, index);
    }

    /**
     * @dev This function allows us to get a value with a specific index from a packed uint,
     *      without checking if the index is within a valid range.
     * @param packed The packed uint from which we want to retrieve the value
     * @param index The index of the value we want to get
     * @return outValue The value at the given index in the packed uint
     */
    function getValueUnchecked(
        uint256 packed,
        uint256 index
    )
        internal
        pure
        returns (uint256 outValue)
    {
        assembly {
            let shiftAmount := mul(index, VALUE_BITS)
            let shifted := shr(shiftAmount, packed)

            outValue := and(shifted, VALUE_MASK)
        }
    }

    /**
     * @dev Sets a value at a given index inside a packed uint.
     *      This function includes an index check to ensure the index provided is within the range of accepted values and a value check to ensure the value to be set doesn't overflow allowable size.
     * @param packed The packed uint in which to set a value.
     * @param index The index at which to set the value.
     * @param value The value to set.
     * @return Returns the modified packed uint.
     */
    function setValue(
        uint256 packed,
        uint256 index,
        uint256 value
    )
        internal
        pure
        returns (uint256)
    {
        require(index < NUM_VALUES, "Index out of range");
        require(value <= VALUE_MASK, "Value overflow");
        return setValueUnchecked(packed, index, value);
    }

    /**
     * @dev This function allows us to set a value with a specific index inside a packed uint,
     *      without checking if the index is within a valid range and value doesn't exceed allowable size.
     * @param packed The packed uint in which we want to set the value
     * @param index The index at which we want to set the value
     * @param value The value we want to set
     * @return outValue The updated packed uint with the value set at the given index
     */
    function setValueUnchecked(
        uint256 packed,
        uint256 index,
        uint256 value
    )
        internal
        pure
        returns (uint256 outValue)
    {
        assembly {
            let shift := mul(index, VALUE_BITS)
            let mask := shl(shift, VALUE_MASK)
            let cleared := and(packed, not(mask))
            let shiftedValue := shl(shift, value)
            outValue := or(cleared, shiftedValue)
        }
    }

    /**
     * @dev This function calculates the total sum of all values in a packed uint.
     * @param packed The packed uint whose total value is to be calculated.
     * @return outValue The total sum of all values present in the packed uint.
     */
    function totalValue(uint256 packed)
        internal
        pure
        returns (uint256 outValue)
    {
        assembly {
            outValue := and(packed, VALUE_MASK)
            packed := shr(VALUE_BITS, packed)
            outValue := add(outValue, and(packed, VALUE_MASK))
            packed := shr(VALUE_BITS, packed)
            outValue := add(outValue, and(packed, VALUE_MASK))
            packed := shr(VALUE_BITS, packed)
            outValue := add(outValue, packed)
        }
    }

    /**
     * @dev Adds a given value to the value at a specific index in a packed uint,
     *      and returns the updated packed uint. This function includes a value check to ensure
     *      the added value doesn't cause an overflow of the allowable size of a value.
     * @param packed The packed uint in which to add the value.
     * @param index The index of the value to which the provided value will be added.
     * @param value The value to add.
     * @return Returns the updated packed uint with the added value at the given index.
     */
    function addValue(
        uint256 packed,
        uint256 index,
        uint256 value
    )
        internal
        pure
        returns (uint256)
    {
        uint256 newValue;
        unchecked {
            newValue = getValue(packed, index) + value;
        }
        require(newValue <= VALUE_MASK, "Value overflow");

        return addValueUnchecked(packed, index, value);
    }

    /**
     * @dev Adds a given value to the value at a specific index in a packed uint,
     *      without checking if it causes an overflow of the allowable size of a value.
     *
     * @param packed The packed uint to which the value will be added
     * @param index The index at which the value is to be added
     * @param value The value to be added
     * @return outValue Returns the updated packed uint with the added value at the given index.
     */
    function addValueUnchecked(
        uint256 packed,
        uint256 index,
        uint256 value
    )
        internal
        pure
        returns (uint256 outValue)
    {
        assembly {
            let shift := mul(index, VALUE_BITS)
            outValue := add(packed, shl(shift, value))
        }
    }

    /**
     * @dev Subtracts a given value from the value at a specific index in a packed uint,
     *      and returns the updated packed uint. This function includes a value check to ensure
     *      the subtracted value doesn't cause an underflow.
     * @param packed The packed uint from which to subtract the value.
     * @param index The index of the value from which the provided value will be subtracted.
     * @param value The value to subtract.
     * @return Returns the updated packed uint with the subtracted value at the given index.
     */
    function subValue(
        uint256 packed,
        uint256 index,
        uint256 value
    )
        internal
        pure
        returns (uint256)
    {
        uint256 oldValue = getValue(packed, index);
        require(oldValue >= value, "Value overflow");

        return subValueUnchecked(packed, index, value);
    }

    /**
     * @dev Subtracts a given value from the value at a specific index in a packed uint,
     *      without checking if it causes an underflow of the allowable size of a value.
     *
     * @param packed The packed uint from which the value will be subtracted
     * @param index The index at which the value is to be subtracted
     * @param value The value to be subtracted
     * @return outValue Returns the updated packed uint with the subtracted value at the given index.
     */
    function subValueUnchecked(
        uint256 packed,
        uint256 index,
        uint256 value
    )
        internal
        pure
        returns (uint256 outValue)
    {
        assembly {
            let shift := mul(index, VALUE_BITS)
            outValue := sub(packed, shl(shift, value))
        }
    }
}
