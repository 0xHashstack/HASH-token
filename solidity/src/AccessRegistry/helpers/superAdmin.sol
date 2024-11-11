// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single superAdmin authorization mixin.
/// @author Hashstack
/// @dev Note:
/// This implementation does NOT auto-initialize the superAdmin to `msg.sender`.
/// You MUST call the `_initializeSuperAdmin` in the constructor / initializer.
///
/// While the ownable portion follows
/// [EIP-173](https://eips.ethereum.org/EIPS/eip-173) for compatibility,
/// the nomenclature for the 2-step superAdminship handover may be unique to this codebase.
abstract contract SuperAdmin {
    /*                       CUSTOM ERRORS                        */

    /// @dev The caller is not authorized to call the function.
    error SuperAdmin2Step_Unauthorized();

    /// @dev The `pendingSuperAdmin` does not have a valid handover request.
    error SuperAdmin2Step_NoHandoverRequest();

    /// @dev Cannot double-initialize.
    error SuperAdmin2Step_AlreadyInitialized();
    /*                           EVENTS                           */

    /// @dev The superAdminship is transferred from `oldSuperAdmin` to `newSuperAdmin`.
    /// This event is intentionally kept the same as OpenZeppelin's Ownable to be
    /// compatible with indexers and [EIP-173](https://eips.ethereum.org/EIPS/eip-173),
    /// despite it not being as lightweight as a single argument event.
    event SuperAdminshipTransferred(address indexed oldSuperAdmin, address indexed newSuperAdmin);

    /// @dev An superAdminship handover to `pendingSuperAdmin` has been requested.
    event SuperAdminshipHandoverRequested(address indexed pendingSuperAdmin);

    /// @dev The superAdminship handover to `pendingSuperAdmin` has been canceled.
    event SuperAdminshipHandoverCanceled(address indexed pendingSuperAdmin);

    /// @dev `keccak256(bytes("SuperAdminshipTransferred(address,address)"))`.
    uint256 private constant _SUPERADMINSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0x04d129ae6ee1a7d168abd097a088e4f07a0292c23aefc0e49b5603d029b8543f;

    /// @dev `keccak256(bytes("SuperAdminshipHandoverRequested(address)"))`.
    uint256 private constant _SUPERADMINSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE =
        0xa391cf6317e44c1bf84ce787a20d5a7193fa44caff9e68b0597edf3cabd29fb7;

    /// @dev `keccak256(bytes("SuperAdminshipHandoverCanceled(address)"))`.
    uint256 private constant _SUPERADMINSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE =
        0x1570624318df302ecdd05ea20a0f8b0f8931a0cb8f4f1f8e07221e636988aa7b;

    /*                          STORAGE                           */

    /// @dev The superAdmin slot is given by:
    /// `bytes32(~uint256(uint32(bytes4(keccak256("_SUPERADMIN_SLOT_NOT")))))`.
    /// It is intentionally chosen to be a high value
    /// to avoid collision with lower slots.
    /// The choice of manual storage layout is to enable compatibility
    /// with both regular and upgradeable contracts.
    bytes32 internal constant _SUPERADMIN_SLOT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927;

    /// The superAdminship handover slot of `newSuperAdmin` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _HANDOVER_SLOT_SEED))
    ///     let handoverSlot := keccak256(0x00, 0x20)
    /// ```
    /// It stores the expiry timestamp of the two-step superAdminship handover.
    uint256 private constant _HANDOVER_SLOT_SEED = 0x389a75e1;

    /*                     INTERNAL FUNCTIONS                     */
    /// @dev Override to return true to make `_initializeSuperAdmin` prevent double-initialization.
    function _guardInitializeSuperAdmin() internal pure virtual returns (bool guard) {}

    /// @dev Initializes the superAdmin directly without authorization guard.
    /// This function must be called upon initialization,
    /// regardless of whether the contract is upgradeable or not.
    /// This is to enable generalization to both regular and upgradeable contracts,
    /// and to save gas in case the initial superAdmin is not the caller.
    /// For performance reasons, this function will not check if there
    /// is an existing superAdmin.
    function _initializeSuperAdmin(address newSuperAdmin) internal {
        if (_guardInitializeSuperAdmin()) {
            /// @solidity memory-safe-assembly
            assembly {
                let superAdminSlot := _SUPERADMIN_SLOT
                if sload(superAdminSlot) {
                    mstore(0x00, 0xc95d9267) // `AlreadyInitialized()`.
                    revert(0x1c, 0x04)
                }

                /// Clean the upper 96 bits.
                newSuperAdmin := shr(96, shl(96, newSuperAdmin)) // Store the new value.
                sstore(superAdminSlot, or(newSuperAdmin, shl(255, iszero(newSuperAdmin)))) // Emit the {SuperAdminshipTransferred} event.
                log3(0, 0, _SUPERADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newSuperAdmin)
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                // Clean the upper 96 bits.
                newSuperAdmin := shr(96, shl(96, newSuperAdmin))
                // Store the new value.
                sstore(_SUPERADMIN_SLOT, newSuperAdmin)
                // Emit the {SuperAdminshipTransferred} event.
                log3(0, 0, _SUPERADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newSuperAdmin)
            }
        }
    }

    /// @dev Sets the superAdmin directly without authorization guard.
    function _setSuperAdmin(address newSuperAdmin) internal {
        if (_guardInitializeSuperAdmin()) {
            /// @solidity memory-safe-assembly
            assembly {
                let superAdminSlot := _SUPERADMIN_SLOT
                // Clean the upper 96 bits.
                newSuperAdmin := shr(96, shl(96, newSuperAdmin))
                // Emit the {SuperAdminshipTransferred} event.
                log3(0, 0, _SUPERADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(superAdminSlot), newSuperAdmin)
                // Store the new value.
                sstore(superAdminSlot, or(newSuperAdmin, shl(255, iszero(newSuperAdmin))))
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                let superAdminSlot := _SUPERADMIN_SLOT
                // Clean the upper 96 bits.
                newSuperAdmin := shr(96, shl(96, newSuperAdmin))
                // Emit the {SuperAdminshipTransferred} event.
                log3(0, 0, _SUPERADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(superAdminSlot), newSuperAdmin)
                // Store the new value.
                sstore(superAdminSlot, newSuperAdmin)
            }
        }
    }

    /// @dev Throws if the sender is not the superAdmin.
    function _checkSuperAdmin() internal view virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // If the caller is not the stored superAdmin, revert.
            if iszero(eq(caller(), sload(_SUPERADMIN_SLOT))) {
                mstore(0x00, 0x591f9739) // `Unauthorized()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns how long a two-step superAdminship handover is valid for in seconds.
    /// Override to return a different value if needed.
    /// Made internal to conserve bytecode. Wrap it in a public function if needed.
    function _superAdminshipHandoverValidFor() internal view virtual returns (uint64) {
        return 24 * 3600;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  PUBLIC UPDATE FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Initiates the ownership handover process by setting an expiration time for the new super admin.
    /// @dev The function uses low-level assembly to store the expiration timestamp in a specific storage slot
    ///      calculated based on the `newSuperAdmin` address and a unique handover slot seed.
    /// @param newSuperAdmin The address designated as the new super admin.
    function sendSuperAdminOwnership(address newSuperAdmin) public virtual onlySuperAdmin {
        unchecked {
            uint256 expires = block.timestamp + _superAdminshipHandoverValidFor();
            /// @solidity memory-safe-assembly
            assembly {
                // Compute and set the handover slot to `expires`.
                mstore(0x0c, _HANDOVER_SLOT_SEED)
                mstore(0x00, newSuperAdmin)
                sstore(keccak256(0x0c, 0x20), expires)
                // Emit the {OwnershipHandoverRequested} event.
                log2(0, 0, _SUPERADMINSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE, caller())
            }
        }
    }

    /// @notice Cancels any pending ownership handover request for a specified new super admin.
    /// @dev This function uses inline assembly to reset the designated handover storage slot to zero,
    ///      effectively canceling the handover request.
    /// @param newSuperAdmin The address of the designated new super admin whose handover request is to be canceled.
    function cancelOwnershipHandover(address newSuperAdmin) public virtual onlySuperAdmin {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, newSuperAdmin)
            sstore(keccak256(0x0c, 0x20), 0)
            // Emit the {OwnershipHandoverCanceled} event.
            log2(0, 0, _SUPERADMINSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE, newSuperAdmin)
        }
    }

    /// @notice Accepts a pending ownership handover request for the caller, provided it is still valid.
    /// @dev This function checks if a handover request exists for the caller and that it has not expired.
    ///      If valid, it sets the handover slot to zero and assigns the caller as the new super admin.
    ///      Reverts if there is no valid handover request or if the request has expired.
    function acceptOwnershipHandover() public {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, caller())
            let handoverSlot := keccak256(0x0c, 0x20)
            // If the handover does not exist, or has expired.
            if gt(timestamp(), sload(handoverSlot)) {
                mstore(0x00, 0x6f5e8818) // `NoHandoverRequest()`.
                revert(0x1c, 0x04)
            }
            // Set the handover slot to 0.
            sstore(handoverSlot, 0)
            let newSuperAdmin := shr(96, shl(96, caller())) // Store the new value.
            log3(0, 0, _SUPERADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newSuperAdmin)
        }
        _setSuperAdmin(msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   PUBLIC READ FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the owner of the contract.
    function superAdmin() public view virtual returns (address result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(_SUPERADMIN_SLOT)
        }
    }

    /// @dev Returns the expiry timestamp for the two-step ownership handover to `pendingOwner`.
    function superAdminshipHandoverExpiresAt(address pendingOwner) public view virtual returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the handover slot.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            // Load the handover slot.
            result := sload(keccak256(0x0c, 0x20))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Marks a function as only callable by the owner.
    modifier onlySuperAdmin() virtual {
        _checkSuperAdmin();
        _;
    }
}
