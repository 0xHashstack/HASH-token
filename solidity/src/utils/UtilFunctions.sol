// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract UtilFunctions {
    /// @dev Error thrown when address is zero
    error CallerZeroAddress();

    /**
     * @dev Modifier to check if an address is the zero address
     * @param user The address to check
     */
    modifier zeroAddress(address user) {
        if(user == address(0)) revert CallerZeroAddress();
        _;
    }
}
