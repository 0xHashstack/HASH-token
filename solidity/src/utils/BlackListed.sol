// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title BlackListed
 * @dev Implements blacklisting functionality for addresses
 * This contract allows an admin to blacklist and unblacklist addresses
 */
abstract contract BlackListed is Context {
    // Errors
    error AccountBlackListed(address account);
    error RestrictedToMultiSig();
    error InvalidOperation();

    // Events
    event NewAccountBlackListed(address indexed account);
    event RemovedAccountBlackListed(address indexed account);

    // State variables
    mapping(address => bool) private blackListedAccounts;
    address public immutable multiSig;

    /**
     * @dev Constructor that sets the admin address
     * @param _multiSig The address of the admin
     */
    constructor(address _multiSig) {
        multiSig = _multiSig;
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
    modifier onlyMultiSig() {
        if (_msgSender() != multiSig) {
            revert RestrictedToMultiSig();
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
    function blackListAccount(address account) external onlyMultiSig {
        blackListedAccounts[account] = true;
        emit NewAccountBlackListed(account);
    }

    /**
     * @dev Removes an account from the blacklist
     * @param account The address to remove from the blacklist
     * Requirements:
     * - Can only be called by the admin
     */
    function removeBlackListedAccount(address account) external onlyMultiSig {
        blackListedAccounts[account] = false;
        emit RemovedAccountBlackListed(account);
    }

    /**
     * @dev Checks if an account is blacklisted
     * @param account The address to check
     * @return bool True if the account is blacklisted, false otherwise
     */
    function isBlackListed(address account) public view returns (bool) {
        return blackListedAccounts[account];
    }

    receive() external payable {
        revert InvalidOperation();
    }

    fallback() external payable {
        revert InvalidOperation();
    }
}
