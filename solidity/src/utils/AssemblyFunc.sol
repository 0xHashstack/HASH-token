// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract AssemblyFunc {
    /// @dev Error thrown when address is zero
    error CallerZeroAddress();

    /**
     * @dev Modifier to check if an address is the zero address
     * @param admin The address to check
     */
    modifier zeroAddress(address admin) {
        assembly {
            if iszero(admin) {
                mstore(0x00, 0x94ab89ec) // `CallerZeroAddress()`
                revert(0x1c, 0x04)
            }
        }
        _;
    }
}
