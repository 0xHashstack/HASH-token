// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `pausedOff` and `pausedOn`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;
    bool private _partialPaused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the Partial pause is triggered by `account`.
     */
    event PartialPaused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev Emitted when the Partial pause is lifted by `account`.
     */
    event PartialUnpaused(address account);

    /**
     * @dev The operation failed because the contract is isPaused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is isPaused.
     */
    error EnforcedPartialPause();

    /**
     * @dev The operation failed because the contract is not isPaused.
     */
    error ExpectedPause();

    /**
     * @dev The operation failed because the contract is not isPaused.
     */
    error ExpectedPartialPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
        _partialPaused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not isPaused.
     *
     * Requirements:
     *
     * - The contract must not be isPaused.
     */
    modifier pausedOff() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not isPaused.
     *
     * Requirements:
     *
     * - The contract must not be isPaused.
     */
    modifier partialPausedOff() {
        _requireNotPartialPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is isPaused.
     *
     * Requirements:
     *
     * - The contract must be isPaused.
     */
    modifier pausedOn() {
        _requirePaused();
        _;
    }
    /**
     * @dev Modifier to make a function callable only when the contract is isPaused.
     *
     * Requirements:
     *
     * - The contract must be isPaused.
     */

    modifier partialPausedOn() {
        _requireNotPartialPaused();
        _;
    }

    /**
     * @dev Returns true if the contract is isPaused, and false otherwise.
     */
    function isPaused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Returns true if the contract is isPaused, and false otherwise.
     */
    function partialPaused() public view virtual returns (bool) {
        return _partialPaused;
    }

    /**
     * @dev Throws if the contract is isPaused.
     */
    function _requireNotPaused() internal view virtual {
        if (isPaused()) {
            revert EnforcedPause();
        }
    }
    /**
     * @dev Throws if the contract is isPaused.
     */

    function _requireNotPartialPaused() internal view virtual {
        if (partialPaused()) {
            revert EnforcedPartialPause();
        }
    }

    /**
     * @dev Throws if the contract is not isPaused.
     */
    function _requirePaused() internal view virtual {
        if (!isPaused()) {
            revert ExpectedPause();
        }
    }
    /**
     * @dev Throws if the contract is not isPaused.
     */

    function _requirePartialPaused() internal view virtual {
        if (!partialPaused()) {
            revert ExpectedPartialPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be isPaused.
     */
    function _pause() internal virtual pausedOff {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be isPaused and partial isPaused.
     */
    function _partialPause() internal virtual pausedOff partialPausedOff {
        _partialPaused = true;
        emit PartialPaused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be isPaused.
     */
    function _unpause() internal virtual pausedOn {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be isPaused.
     */

    function _partialUnpause() internal virtual pausedOff partialPausedOn {
        _partialPaused = false;
        emit PartialUnpaused(_msgSender());
    }
}