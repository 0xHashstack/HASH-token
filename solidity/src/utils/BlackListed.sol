// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Context } from '@openzeppelin/contracts/utils/Context.sol';

/**
 * @title BlackListed
 * @dev Implements blacklisting functionality for addresses
 * This contract allows an admin to blacklist and unblacklist addresses
 */
abstract contract BlackListed is Context {
    // Errors
    error CallerZeroAddress();
    error AccountBlackListed(address account);
    error AdminRestricted();

    // Events
    event NewAccountBlackListed(address indexed account);
    event RemovedAccountBlackListed(address indexed account);

    // State variables
    mapping(address => bool) private blackListedAccounts;
    address public admin;

    /**
     * @dev Constructor that sets the admin address
     * @param _admin The address of the admin
     */
    constructor(address _admin) {
        admin = _admin;
    }

    /**
     * @dev Modifier to check if an address is the zero address
     * @param _check The address to check
     */
    modifier zeroAddress(address _check) {
        if (_check == address(0)) {
            revert CallerZeroAddress();
        }
        _;
    }

    /**
     * @dev Modifier to check if an address is not blacklisted
     * @param _check The address to check
     */
    modifier notBlackListed(address _check) {
        if (isBlackListed(_check)) {
            revert AccountBlackListed(_check);
        }
        _;
    }

    /**
     * @dev Modifier to restrict access to admin only
     */
    modifier onlyAdmin() {
        if (_msgSender() != admin) {
            revert AdminRestricted();
        }
        _;
    }

    /**
     * @dev Blacklists an account
     * @param account The address to blacklist
     * Requirements:
     * - Can only be called by the admin
     * - `account` cannot be the zero address
     */
    function blackListAccount(address account) external zeroAddress(account) onlyAdmin {
        blackListedAccounts[account] = true;
        emit NewAccountBlackListed(account);
    }

    /**
     * @dev Removes an account from the blacklist
     * @param account The address to remove from the blacklist
     * Requirements:
     * - Can only be called by the admin
     */
    function removeFromBlackListAccount(address account) external onlyAdmin {
        blackListedAccounts[account] = false;
        emit RemovedAccountBlackListed(account);
    }

    /**
     * @dev Transfers the admin role to a new address
     * @param account The address of the new admin
     * Requirements:
     * - Can only be called by the current admin
     * - `account` cannot be the zero address
     */
    function transferAdminRole(address account) external onlyAdmin zeroAddress(account) {
        admin = account;
    }

    /**
     * @dev Checks if an account is blacklisted
     * @param account The address to check
     * @return bool True if the account is blacklisted, false otherwise
     */
    function isBlackListed(address account) public view returns (bool) {
        return blackListedAccounts[account];
    }
}
