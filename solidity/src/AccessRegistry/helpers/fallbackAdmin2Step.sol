// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single fallbackAdmin authorization mixin.
/// @author Hashstack
abstract contract FallbackAdmin2Step {
    /*                       CUSTOM ERRORS                        */
    /// @dev The caller is not authorized to call the function.

    error FallbackAdmin2Step_Unauthorized();

    /// @dev The `newFallbackAdmin` cannot be the zero address.
    error NewFallbackAdminIsZeroAddress();

    /// @dev The `pendingFallbackAdmin` does not have a valid handover request.
    error FallbackAdmin2Step_NoHandoverRequest();

    // /// @dev The `pendingFallbackAdmin` does not have a valid handover request.
    // error FallbackAdmin2Step_UnauthorizedCaller();

    /*                           EVENTS                           */

    /// @dev The fallbackAdminship is transferred from `oldFallbackAdmin` to `newFallbackAdmin`.
    event FallbackAdminshipTransferred(address indexed oldFallbackAdmin, address indexed newFallbackAdmin);

    /// @dev An fallbackAdminship handover to `pendingFallbackAdmin` has been requested.
    event FallbackAdminshipHandoverRequested(address indexed pendingFallbackAdmin);

    /// @dev The fallbackAdminship handover to `pendingFallbackAdmin` has been canceled.
    event FallbackAdminshipHandoverCanceled(address indexed pendingFallbackAdmin);

    // /*                          STORAGE                           */

    /// @dev The fallbackAdmin slot is given by:

    /// @dev keccak256("Hashstack._FALLBACKADMIN_SLOT")
    bytes32 internal constant _FALLBACKADMIN_SLOT = 0x1f154708c9ba3c972c7dc39a4a6057be59687879c824cbe6885cce5cb0690173;
    /// @dev keccak256("Hashstack.fallbackAdmin._PENDINGADMIN_SLOT")
    bytes32 internal constant _PENDINGADMIN_SLOT = 0x395ea32af69dd556bbe76d9a27a2afe1f30ad35ee40c08e39d4666cbe11d2968;
    /// @dev keccak256("Hashstack.fallbackAdmin._HANDOVERTIME_SLOT_SEED")
    bytes32 internal constant _HANDOVERTIME_SLOT_SEED =
        0xb68db56c216d94fd58fbccf93d4d61cc735c0033b18392e5b676895a446bd87f;

    /*                     INTERNAL FUNCTIONS                     */

    /// @dev Sets the fallbackAdmin directly without authorization guard.
    function _setFallbackAdmin(address _newFallbackAdmin) internal virtual {
        assembly {
            if eq(_newFallbackAdmin, 0) {
                // Load pre-defined error selector for zero address
                mstore(0x00, 0xf6c0e670) // NewFallbackAdminIsZeroAddress error
                revert(0x1c, 0x04)
            }
            /// @dev `keccak256(bytes("FallbackAdminshipTransferred(address,address)"))
            log3(
                0,
                0,
                0xb3b235ec28c0c439d776d6b08d1186ca9e254ab0a45799e7c012c767fd388ab4,
                sload(_FALLBACKADMIN_SLOT),
                _newFallbackAdmin
            )
            sstore(_FALLBACKADMIN_SLOT, _newFallbackAdmin)
        }
    }

    /*                     PUBLIC FUNCTIONS                     */

    /// @dev Throws if the sender is not the fallbackAdmin.
    function _checkFallbackAdmin() internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller is not the stored fallbackAdmin, revert.
            if iszero(eq(caller(), sload(_FALLBACKADMIN_SLOT))) {
                mstore(0x00, 0xf6c0e670) // `FallbackAdmin2Step_Unauthorized()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns how long a two-step fallbackAdminship handover is valid for in seconds.
    /// Override to return a different value if needed.
    /// Made internal to conserve bytecode. Wrap it in a public function if needed.
    function _fallbackAdminHandoverValidFor() internal view virtual returns (uint64) {
        return 86400;
    }
    /*                  PUBLIC UPDATE FUNCTIONS                   */

    /// @dev Request a two-step fallbackAdminship handover to the caller.
    /// The request will automatically expire in 48 hours (172800 seconds) by default.
    function requestFallbackAdminTransfer(address _pendingOwner) public virtual onlyFallbackAdmin {
        unchecked {
            uint256 expires = block.timestamp + _fallbackAdminHandoverValidFor();
            /// @solidity memory-safe-assembly
            assembly {
                sstore(_PENDINGADMIN_SLOT, _pendingOwner)
                sstore(_HANDOVERTIME_SLOT_SEED, expires)
                // Emit the {FallbackAdminshipHandoverRequested} event.
                log2(0, 0, 0x28dbfd0a9abc89d42b4958ac24ccb5370d4381d6d9780ec9495d9f865294ec73, _pendingOwner)
            }
        }
    }

    /// @dev Cancels the two-step fallbackAdminship handover to the caller, if any.
    function cancelFallbackAdminTransfer() public virtual onlyFallbackAdmin {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            sstore(_PENDINGADMIN_SLOT, 0x0)
            sstore(_HANDOVERTIME_SLOT_SEED, 0x0)
            // Emit the {FallbackAdminshipHandoverCanceled} event.
            log2(0, 0, 0xfff645f1f5f25235a50da3b568627809458a7da704bb0700eb960289b102bb52, caller())
        }
    }

    /// @dev Allows the fallbackAdmin to complete the two-step fallbackAdminship handover to `pendingFallbackAdmin`.
    /// Reverts if there is no existing fallbackAdminship handover requested by `pendingFallbackAdmin`.
    function acceptFallbackAdminTransfer() public virtual {
        /// @solidity memory-safe-assembly

        address pendingAdmin;
        assembly {
            pendingAdmin := sload(_PENDINGADMIN_SLOT)

            // Check that the sender is the pending admin
            if iszero(eq(caller(), pendingAdmin)) {
                mstore(0x00, 0xf6c0e670) // Unauthorized error
                revert(0x1c, 0x04)
            }
            // If the handover does not exist, or has expired.
            if gt(timestamp(), sload(_HANDOVERTIME_SLOT_SEED)) {
                mstore(0x00, 0x292ff959) // `FallbackAdmin2Step_NoHandoverRequest()`.
                revert(0x1c, 0x04)
            }
            // Set the handover slot to 0.
            sstore(_HANDOVERTIME_SLOT_SEED, 0)
            sstore(_PENDINGADMIN_SLOT, 0)
        }
        _setFallbackAdmin(pendingAdmin);
    }
    /*                   PUBLIC READ FUNCTIONS                    */

    /// @dev Returns the fallbackAdmin of the contract.
    function fallbackAdmin() public view virtual returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(_FALLBACKADMIN_SLOT)
        }
    }

    /// @dev Returns the expiry timestamp for the two-step fallbackAdminship handover to `pendingFallbackAdmin`.
    function fallbackAdminHandoverExpiresAt() public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Load the handover slot.
            result := sload(keccak256(0x0c, 0x20))
        }
    }
    /*                         MODIFIERS                          */

    /// @dev Marks a function as only callable by the fallbackAdmin.
    modifier onlyFallbackAdmin() virtual {
        _checkFallbackAdmin();
        _;
    }
}
