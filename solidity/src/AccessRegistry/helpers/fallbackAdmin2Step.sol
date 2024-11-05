// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single fallbackAdmin authorization mixin.
/// @author Hashstack
/// @dev Note:
/// This implementation does NOT auto-initialize the fallbackAdmin to `msg.sender`.
/// You MUST call the `_initializeFallbackAdmin` in the constructor / initializer.
///
/// While the ownable portion follows
/// [EIP-173](https://eips.ethereum.org/EIPS/eip-173) for compatibility,
/// the nomenclature for the 2-step fallbackAdminship handover may be unique to this codebase.
abstract contract FallbackAdmin2Step {
    /*                       CUSTOM ERRORS                        */
    /// @dev The caller is not authorized to call the function.

    error FallbackAdmin2Step_Unauthorized();

    /// @dev The `newFallbackAdmin` cannot be the zero address.
    error NewFallbackAdminIsZeroAddress();

    /// @dev The `pendingFallbackAdmin` does not have a valid handover request.
    error FallbackAdmin2Step_NoHandoverRequest();

    /// @dev Cannot double-initialize.
    error FallbackAdmin2Step_AlreadyInitialized();

    /*                           EVENTS                           */

    /// @dev The fallbackAdminship is transferred from `oldFallbackAdmin` to `newFallbackAdmin`.
    /// This event is intentionally kept the same as OpenZeppelin's Ownable to be
    /// compatible with indexers and [EIP-173](https://eips.ethereum.org/EIPS/eip-173),
    /// despite it not being as lightweight as a single argument event.
    event FallbackAdminshipTransferred(address indexed oldFallbackAdmin, address indexed newFallbackAdmin);

    /// @dev An fallbackAdminship handover to `pendingFallbackAdmin` has been requested.
    event FallbackAdminshipHandoverRequested(address indexed pendingFallbackAdmin);

    /// @dev The fallbackAdminship handover to `pendingFallbackAdmin` has been canceled.
    event FallbackAdminshipHandoverCanceled(address indexed pendingFallbackAdmin);

    /// @dev `keccak256(bytes("FallbackAdminshipTransferred(address,address)"))`.
    uint256 private constant _FALLBACKADMINSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0xb3b235ec28c0c439d776d6b08d1186ca9e254ab0a45799e7c012c767fd388ab4;

    /// @dev `keccak256(bytes("FallbackAdminshipHandoverRequested(address)"))`.
    uint256 private constant _FALLBACKADMINSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE =
        0x28dbfd0a9abc89d42b4958ac24ccb5370d4381d6d9780ec9495d9f865294ec73;

    /// @dev `keccak256(bytes("FallbackAdminshipHandoverCanceled(address)"))`.
    uint256 private constant _FALLBACKADMINSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE =
        0xfff645f1f5f25235a50da3b568627809458a7da704bb0700eb960289b102bb52;

    /*                          STORAGE                           */

    /// @dev The fallbackAdmin slot is given by:
    /// `bytes32(~uint256(uint32(bytes4(keccak256("_FALLBACKADMIN_SLOT_NOT")))))`.
    /// It is intentionally chosen to be a high value
    /// to avoid collision with lower slots.
    /// The choice of manual storage layout is to enable compatibility
    /// with both regular and upgradeable contracts.
    bytes32 internal constant _FALLBACKADMIN_SLOT = 0x0c5cbdbffd46dcbe9fc21989b921bb5428cb1a1f406b6975b85f43539eb5bba3;

    /// The fallbackAdminship handover slot of `newFallbackAdmin` is given by:
    /// ```
    ///     mstore(0x00, or(shl(96, user), _HANDOVER_SLOT_SEED))
    ///     let handoverSlot := keccak256(0x00, 0x20)
    /// ```
    /// It stores the expiry timestamp of the two-step fallbackAdminship handover.
    uint256 private constant _HANDOVER_SLOT_SEED = 0x389a75e1;

    /*                     INTERNAL FUNCTIONS                     */

    /// @dev Override to return true to make `_initializeFallbackAdmin` prevent double-initialization.
    function _guardInitializeFallbackAdmin() internal pure virtual returns (bool guard) {}

    /// @dev Initializes the fallbackAdmin directly without authorization guard.
    /// This function must be called upon initialization,
    /// regardless of whether the contract is upgradeable or not.
    /// This is to enable generalization to both regular and upgradeable contracts,
    /// and to save gas in case the initial fallbackAdmin is not the caller.
    /// For performance reasons, this function will not check if there
    /// is an existing fallbackAdmin.
    function _initializeFallbackAdmin(address newFallbackAdmin) internal virtual {
        if (_guardInitializeFallbackAdmin()) {
            /// @solidity memory-safe-assembly
            assembly {
                let fallbackAdminSlot := _FALLBACKADMIN_SLOT
                if sload(fallbackAdminSlot) {
                    mstore(0x00, 0xb8abd9e1) // `FallbackAdmin2Step_AlreadyInitialized()`.
                    revert(0x1c, 0x04)
                }

                /// Clean the upper 96 bits.
                newFallbackAdmin := shr(96, shl(96, newFallbackAdmin)) // Store the new value.
                sstore(fallbackAdminSlot, or(newFallbackAdmin, shl(255, iszero(newFallbackAdmin)))) // Emit the {FallbackAdminshipTransferred} event.
                log3(0, 0, _FALLBACKADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newFallbackAdmin)
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                // Clean the upper 96 bits.
                newFallbackAdmin := shr(96, shl(96, newFallbackAdmin))
                // Store the new value.
                sstore(_FALLBACKADMIN_SLOT, newFallbackAdmin)
                // Emit the {FallbackAdminshipTransferred} event.
                log3(0, 0, _FALLBACKADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newFallbackAdmin)
            }
        }
    }

    /// @dev Sets the fallbackAdmin directly without authorization guard.
    function _setFallbackAdmin(address newFallbackAdmin) internal virtual {
        if (_guardInitializeFallbackAdmin()) {
            /// @solidity memory-safe-assembly
            assembly {
                let fallbackAdminSlot := _FALLBACKADMIN_SLOT
                // Clean the upper 96 bits.
                newFallbackAdmin := shr(96, shl(96, newFallbackAdmin))
                // Emit the {FallbackAdminshipTransferred} event.
                log3(0, 0, _FALLBACKADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(fallbackAdminSlot), newFallbackAdmin)
                // Store the new value.
                sstore(fallbackAdminSlot, or(newFallbackAdmin, shl(255, iszero(newFallbackAdmin))))
            }
        } else {
            /// @solidity memory-safe-assembly
            assembly {
                let fallbackAdminSlot := _FALLBACKADMIN_SLOT
                // Clean the upper 96 bits.
                newFallbackAdmin := shr(96, shl(96, newFallbackAdmin))
                // Emit the {FallbackAdminshipTransferred} event.
                log3(0, 0, _FALLBACKADMINSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(fallbackAdminSlot), newFallbackAdmin)
                // Store the new value.
                sstore(fallbackAdminSlot, newFallbackAdmin)
            }
        }
    }

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
    function _fallbackAdminshipHandoverValidFor() internal view virtual returns (uint64) {
        return 48 * 3600;
    }
    /*                  PUBLIC UPDATE FUNCTIONS                   */

    // Check: is this function correct/required?
    /// @dev Allows the fallbackAdmin to renounce their fallbackAdminship.
    function renounceFallbackAdminship() public virtual onlyFallbackAdmin {
        _setFallbackAdmin(address(0));
    }

    /// @dev Request a two-step fallbackAdminship handover to the caller.
    /// The request will automatically expire in 48 hours (172800 seconds) by default.
    function requestFallbackAdminshipHandover() public virtual {
        unchecked {
            uint256 expires = block.timestamp + _fallbackAdminshipHandoverValidFor();
            /// @solidity memory-safe-assembly
            assembly {
                // Compute and set the handover slot to `expires`.
                mstore(0x0c, _HANDOVER_SLOT_SEED)
                mstore(0x00, caller())
                sstore(keccak256(0x0c, 0x20), expires)
                // Emit the {FallbackAdminshipHandoverRequested} event.
                log2(0, 0, _FALLBACKADMINSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE, caller())
            }
        }
    }

    /// @dev Cancels the two-step fallbackAdminship handover to the caller, if any.
    function cancelFallbackAdminshipHandover() public virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, caller())
            sstore(keccak256(0x0c, 0x20), 0)
            // Emit the {FallbackAdminshipHandoverCanceled} event.
            log2(0, 0, _FALLBACKADMINSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE, caller())
        }
    }

    /// @dev Allows the fallbackAdmin to complete the two-step fallbackAdminship handover to `pendingFallbackAdmin`.
    /// Reverts if there is no existing fallbackAdminship handover requested by `pendingFallbackAdmin`.
    function completeFallbackAdminshipHandover(address pendingFallbackAdmin) public virtual onlyFallbackAdmin {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and set the handover slot to 0.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingFallbackAdmin)
            let handoverSlot := keccak256(0x0c, 0x20)
            // If the handover does not exist, or has expired.
            if gt(timestamp(), sload(handoverSlot)) {
                mstore(0x00, 0x292ff959) // `FallbackAdmin2Step_NoHandoverRequest()`.
                revert(0x1c, 0x04)
            }
            // Set the handover slot to 0.
            sstore(handoverSlot, 0)
        }
        _setFallbackAdmin(pendingFallbackAdmin);
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
    function fallbackAdminshipHandoverExpiresAt(address pendingFallbackAdmin)
        public
        view
        virtual
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the handover slot.
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingFallbackAdmin)
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
