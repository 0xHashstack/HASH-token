// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.20;

// import {Context} from "@openzeppelin/contracts/utils/Context.sol";

// /**
//  * @dev Contract module which allows children to implement an emergency stop
//  * mechanism that can be triggered by an authorized account.
//  *
//  * This module is used through inheritance. It will make available the
//  * modifiers `pausedOff` and `pausedOn`, which can be applied to
//  * the functions of your contract.
//  */
// abstract contract Pausable is Context {
//     enum PauseState {
//         ACTIVE,         // Normal operation state (unpaused)
//         PARTIAL_PAUSE,  // Partially paused state
//         FULL_PAUSE     // Fully paused state
//     }

//     PauseState private _currentState;

//     /**
//      * @dev Emitted when the pause state is changed by `account`.
//      */
//     event PauseStateChanged(address account, PauseState newState);

//     /**
//      * @dev The operation failed because the contract is fully paused.
//      */
//     error EnforcedPause();

//     /**
//      * @dev The operation failed because the contract is partially paused.
//      */
//     error EnforcedPartialPause();

//     /**
//      * @dev The operation failed because the contract is not in the expected state.
//      */
//     error InvalidPauseState();

//     /**
//      * @dev Initializes the contract in ACTIVE state.
//      */
//     constructor() {
//         _currentState = PauseState.ACTIVE;
//     }

//     /**
//      * @dev Modifier to make a function callable only when the contract is active.
//      */
//     modifier whenActive() {
//         _requireActive();
//         _;
//     }

//     /**
//      * @dev Modifier to make a function callable only when the contract is not fully paused.
//      */
//     modifier notFullyPaused() {
//         _requireNotFullyPaused();
//         _;
//     }
    

//     /**
//      * @dev Modifier to make a function callable only when the contract is in a specific state.
//      */
//     modifier inState(PauseState requiredState) {
//         _requireState(requiredState);
//         _;
//     }

//     /**
//      * @dev Returns the current pause state of the contract.
//      */
//     function getCurrentState() public view virtual returns (PauseState) {
//         return _currentState;
//     }

//     /**
//      * @dev Returns true if the contract is fully paused, and false otherwise.
//      */
//     function isFullyPaused() public view virtual returns (bool) {
//         return _currentState == PauseState.FULL_PAUSE;
//     }

//     /**
//      * @dev Returns true if the contract is partially paused, and false otherwise.
//      */
//     function isPartiallyPaused() public view virtual returns (bool) {
//         return _currentState == PauseState.PARTIAL_PAUSE;
//     }

//     /**
//      * @dev Throws if the contract is not active.
//      */
//     function _requireActive() internal view virtual {
//         if (_currentState != PauseState.ACTIVE) {
//             if (_currentState == PauseState.FULL_PAUSE) {
//                 revert EnforcedPause();
//             } else {
//                 revert EnforcedPartialPause();
//             }
//         }
//     }

//     /**
//      * @dev Throws if the contract is fully paused.
//      */
//     function _requireNotFullyPaused() internal view virtual {
//         if (_currentState == PauseState.FULL_PAUSE) {
//             revert EnforcedPause();
//         }
//     }

//     /**
//      * @dev Throws if the contract is not in the required state.
//      */
//     function _requireState(PauseState requiredState) internal view virtual {
//         if (_currentState != requiredState) {
//             revert InvalidPauseState();
//         }
//     }

//     /**
//      * @dev Triggers fully paused state.
//      *
//      * Requirements:
//      *
//      * - The contract must be active or partially paused.
//      */
//     function _pause() internal virtual notFullyPaused {
//         _currentState = PauseState.FULL_PAUSE;
//         emit PauseStateChanged(_msgSender(), PauseState.FULL_PAUSE);
//     }

//     /**
//      * @dev Triggers partially paused state.
//      *
//      * Requirements:
//      *
//      * - The contract must be active.
//      */
//     function _partialPause() internal virtual whenActive {
//         _currentState = PauseState.PARTIAL_PAUSE;
//         emit PauseStateChanged(_msgSender(), PauseState.PARTIAL_PAUSE);
//     }

//     /**
//      * @dev Returns to normal state.
//      *
//      * Requirements:
//      *
//      * - The contract must be in a paused state.
//      */
//     function _unpause() internal virtual {
//         require(_currentState != PauseState.ACTIVE, "Pausable: already active");
//         _currentState = PauseState.ACTIVE;
//         emit PauseStateChanged(_msgSender(), PauseState.ACTIVE);
//     }
// }
