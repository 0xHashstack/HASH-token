// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {SuperAdmin2Step} from "./helpers/superAdmin2Step.sol";
import {FallbackAdmin2Step} from "./helpers/fallbackAdmin2Step.sol";

/**
 * @title AccessRegistry
 * @dev Contract for managing signers in a multi-signature setup with hierarchical admin roles.
 * Inherits from Context for msg.sender abstraction and implements two-step admin control.
 *
 * Features:
 * - Super admin can add/remove signers
 * - Signers can renounce their role to another address
 * - Batch operations for adding/removing signers
 * - Protection against removing all signers
 */
abstract contract AccessRegistry is Context, SuperAdmin2Step, FallbackAdmin2Step {
    // Events for tracking signer management
    event SignerAdded(address indexed newSigner);
    event SignerRemoved(address indexed removedSigner);
    event SignerRenounced(address indexed from, address indexed to);

    // Custom errors for better gas efficiency and clearer error messages
    error CallerZeroAddress();
    error SuperAdminIsRestricted();
    error AlreadySigner(address signer);
    error SuperAdminCannotRemoved();
    error WalletCannotBeSignerLess();
    error NonExistingSigner(address signer);

    /// @dev Storage slot for total signer count using assembly optimization
    /// Value: `keccak256(bytes("totalSigner.hashstack.slot"))`
    bytes32 private constant _TOTAL_SIGNER_SLOT = 0xe1a63a0c68b86a7b1309b59f9e0b0e0004b936ab8a2d2478258aa16889f6e227;

    /// @dev Mapping to track valid signers
    mapping(address => bool) private signers;

    /**
     * @dev Returns the total number of active signers
     * @return _totalSigners The current count of signers
     */
    function totalSigners() public view returns (uint256 _totalSigners) {
        assembly {
            _totalSigners := sload(_TOTAL_SIGNER_SLOT)
        }
    }

    /**
     * @dev Modifier to validate non-zero address input
     * @param account Address to validate
     */
    modifier notZeroAddress(address account) {
        assembly {
            if iszero(account) {
                // Store custom error signature for CallerZeroAddress()
                mstore(0x00, 0x94ab89ecb5c4b38206098816f979455e455ef9f334ae4f5819388d393f70dcc2)
                revert(0x00, 0x04)
            }
        }
        _;
    }

    /**
     * @dev Initializes the contract with super admin and fallback admin
     * @param _superAdmin Address of the super admin
     * @param _fallbackAdmin Address of the fallback admin
     */
    function _initializeAccessRegistry(address _superAdmin, address _fallbackAdmin) internal virtual {
        // Initialize contract with first signer (super admin) and set admin roles
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, add(sload(_TOTAL_SIGNER_SLOT), 1))
            sstore(_FALLBACKADMIN_SLOT, _fallbackAdmin)
            sstore(_SUPERADMIN_SLOT, _superAdmin)
        }
        signers[_superAdmin] = true;
    }

    /**
     * @dev Adds a new signer to the registry
     * @param _newSigner Address of the new signer to add
     */
    function addSigner(address _newSigner) external virtual onlySuperAdmin {
        _addSigner(_newSigner);
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, add(sload(_TOTAL_SIGNER_SLOT), 1))
        }
    }

    /**
     * @dev Adds multiple signers in a single transaction
     * @param newSigners Array of addresses to add as signers
     */
    function addBatchSigners(address[] calldata newSigners) external virtual onlySuperAdmin {
        uint256 totalSigner = newSigners.length;

        for (uint256 i = 0; i < totalSigner;) {
            _addSigner(newSigners[i]);

            unchecked {
                ++i;
            }
        }
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, add(sload(_TOTAL_SIGNER_SLOT), totalSigner))
        }
    }

    /**
     * @dev Removes multiple signers in a single transaction
     * @param exisitingSigner Array of signer addresses to remove
     */
    function removeBatchSigners(address[] calldata exisitingSigner) external virtual onlySuperAdmin {
        uint256 totalSigner = exisitingSigner.length;

        for (uint256 i = 0; i < totalSigner;) {
            _removeSigner(exisitingSigner[i]);

            unchecked {
                ++i;
            }
        }
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, sub(sload(_TOTAL_SIGNER_SLOT), totalSigner))
        }
    }

    /**
     * @dev Removes a single signer from the registry
     * @param _signer Address of the signer to remove
     */
    function removeSigner(address _signer) external virtual onlySuperAdmin {
        _removeSigner(_signer);
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, sub(sload(_TOTAL_SIGNER_SLOT), 1))
        }
    }

    /**
     * @dev Allows a signer to transfer their role to another address
     * @param _newSigner Address that will receive the signer role
     */
    function renounceSignership(address _newSigner) public virtual onlySigner notZeroAddress(_newSigner) {
        // Super admin cannot renounce their role through this function
        if (_msgSender() == superAdmin()) revert SuperAdminIsRestricted();
        if (isSigner(_newSigner)) revert AlreadySigner(_newSigner);

        signers[_msgSender()] = false;
        signers[_newSigner] = true;

        // Emit event using assembly for gas optimization
        assembly {
            log3(
                0x00, // start of data
                0x00, // length of data (0 as no data needed)
                0x02f7bac28cd34b63fc761d9ef07b1ccea5c5b43efd912d06a91b999b202cd68e, // keccak256("SignerReounced(address,address)")
                caller(),
                _newSigner
            )
        }
    }

    /**
     * @dev Checks if an address is a registered signer
     * @param _check Address to check
     * @return result True if address is a signer, false otherwise
     */
    function isSigner(address _check) public view returns (bool result) {
        return signers[_check];
    }

    /**
     * @dev Modifier to restrict function access to registered signers
     */
    modifier onlySigner() {
        if (!isSigner(_msgSender())) {
            revert();
        }
        _;
    }

    /**
     * @dev Internal function to update super admin role
     * Updates signer mapping when super admin changes
     * @param _newSuperOwner Address of the new super admin
     */
    function _setSuperAdmin(address _newSuperOwner) internal virtual override {
        signers[superAdmin()] = false;
        signers[_newSuperOwner] = true;
        super._setSuperAdmin(_newSuperOwner);
    }

    /**
     * @dev Internal function to handle signer addition logic
     * Includes validation and event emission
     * @param signer Address to add as signer
     */
    function _addSigner(address signer) internal {
        if (signer == address(0)) revert CallerZeroAddress();
        if (isSigner(signer)) revert AlreadySigner(signer);

        signers[signer] = true;

        // Emit event using assembly for gas optimization
        assembly {
            log2(
                0x00,
                0x00,
                0x47d1c22a25bb3a5d4e481b9b1e6944c2eade3181a0a20b495ed61d35b5323f24, // keccak256("SignerAdded(address)")
                signer
            )
        }
    }

    /**
     * @dev Internal function to handle signer removal logic
     * Includes validation and event emission
     * @param _signer Address to remove from signers
     */
    function _removeSigner(address _signer) internal {
        if (!isSigner(_signer)) revert NonExistingSigner(_signer);
        if (_signer == _msgSender()) revert SuperAdminCannotRemoved();
        // if (totalSigners() == 1) revert WalletCannotBeSignerLess();

        signers[_signer] = false;

        // Emit event using assembly for gas optimization
        assembly {
            log2(
                0x00,
                0x00,
                0x3525e22824a8a7df2c9a6029941c824cf95b6447f1e13d5128fd3826d35afe8b, // keccak256("SignerRemoved(address)")
                _signer
            )
        }
    }
}
