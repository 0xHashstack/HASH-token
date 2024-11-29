// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `pausedOff` and `pausedOn`, which can be applied to
 * the functions of your contract.
 */
abstract contract Pausable is Context {
    enum PauseState {
        ACTIVE, // Normal operation state
        PARTIAL_PAUSE, // Partially paused state
        FULL_PAUSE // Fully paused state

    }

    PauseState private _currentState;

    /**
     * @dev Emitted when the pause state is changed by `account`.
     */
    event PauseStateChanged(address account, PauseState newState);

    /**
     * @dev The operation failed because the contract is fully paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is partially paused.
     */
    error EnforcedPartialPause();

    /**
     * @dev The operation failed because the current state is partially paused.
     */
    error InvalidStateChange();

    /**
     * @dev Initializes the contract in ACTIVE state.
     */
    constructor() {
        _currentState = PauseState.ACTIVE;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is active.
     */
    modifier whenActive() {
        _requireActive();
        _;
    }

    modifier allowedInActiveOrPartialPause() {
        if (_currentState == PauseState.ACTIVE || _currentState == PauseState.PARTIAL_PAUSE) {
            _;
        } else {
            revert InvalidStateChange();
        }
    }

    /**
     * @dev Returns the current pause state of the contract.
     */
    function getCurrentState() external view returns (PauseState) {
        return _currentState;
    }

    /**
     * @dev Throws if the contract is not active.
     */
    function _requireActive() internal view {
        if (_currentState != PauseState.ACTIVE) {
            if (_currentState == PauseState.FULL_PAUSE) {
                revert EnforcedPause();
            } else {
                revert EnforcedPartialPause();
            }
        }
    }

    /**
     * @dev Update the Contract Pause State.
    */

    function _updateOperationalState(uint8 _state) internal {
        if (_state > 2) revert InvalidStateChange();
        _currentState = PauseState(_state);

        emit PauseStateChanged(_msgSender(), _currentState);
    }
}
