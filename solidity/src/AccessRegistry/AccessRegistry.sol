// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {SuperAdmin} from "./helpers/superAdmin.sol";
import {FallbackAdmin} from "./helpers/fallbackAdmin.sol";

abstract contract AccessRegistry is Context, SuperAdmin, FallbackAdmin {
    event SignerAdded(address indexed newSigner);
    event SignerRemoved(address indexed removedSigner);
    event SignerRenounced(address indexed from, address indexed to);

    error CallerZeroAddress();
    error SuperAdminIsRestricted();
    error AlreadySigner();
    error SuperAdminCannotRemoved();
    error WalletCannotBeSignerLess();
    error NonExistingSigner();

    /// @dev `keccak256(bytes("totalSigner.hashstack.slot"))`.
    bytes32 private constant _TOTAL_SIGNER_SLOT = 0xe1a63a0c68b86a7b1309b59f9e0b0e0004b936ab8a2d2478258aa16889f6e227;

    mapping(address => bool) private signers;

    function totalSigners() public view returns (uint256 _totalSigners) {
        assembly {
            _totalSigners := sload(_TOTAL_SIGNER_SLOT)
        }
    }

    modifier notZeroAddress(address account) {
        assembly {
            if iszero(account) {
                mstore(0x00, 0x94ab89ecb5c4b38206098816f979455e455ef9f334ae4f5819388d393f70dcc2) //hash for CallerZeroAddress()
                revert(0x00, 0x04)
            }
        }
        _;
    }

    function _guardInitializeSuperAdmin() internal pure virtual override returns (bool) {
        return true;
    }

    function _guardInitializeFallbackAdmin() internal pure virtual override returns (bool) {
        return true;
    }

    function _initializeAccessRegistry(address _superAdmin, address _fallbackAdmin) internal virtual {
        _initializeSuperAdmin(_superAdmin);
        _initializeFallbackAdmin(_fallbackAdmin);
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, add(sload(_TOTAL_SIGNER_SLOT), 1))
        }
        signers[_superAdmin] = true;
    }

    function addSigner(address _newSigner) external virtual onlySuperAdmin {
        _addSigner(_newSigner);
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, add(sload(_TOTAL_SIGNER_SLOT), 1))
        }
    }

    function addBatchSigners(address[] calldata newSigners) external virtual onlySuperAdmin {
        uint256 totalSigners = newSigners.length;

        for (uint256 i = 0; i < totalSigners; i++) {
            _addSigner(newSigners[i]);
        }
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, add(sload(_TOTAL_SIGNER_SLOT), totalSigners))
        }
    }

    function removeBatchSigners(address[] calldata exisitingSigner) external virtual onlySuperAdmin {
        uint256 totalSigners = exisitingSigner.length;

        for (uint256 i = 0; i < totalSigners; i++) {
            _removeSigner(exisitingSigner[i]);
        }
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, sub(sload(_TOTAL_SIGNER_SLOT), totalSigners))
        }
    }

    function removeSigner(address _signer) external virtual onlySuperAdmin {
        _removeSigner(_signer);
        assembly {
            sstore(_TOTAL_SIGNER_SLOT, sub(sload(_TOTAL_SIGNER_SLOT), 1))
        }
    }

    function renounceSignership(address _newSigner) public virtual onlySigner notZeroAddress(_newSigner) {
        if (_msgSender() == superAdmin()) revert SuperAdminIsRestricted();
        if (isSigner(_newSigner)) revert AlreadySigner();

        signers[_msgSender()] = false;
        signers[_newSigner] = true;
        assembly {
            // Emit SignerRenounced event
            log3(
                0x00, // start of data
                0x00, // length of data (0 as no data needed)
                0x02f7bac28cd34b63fc761d9ef07b1ccea5c5b43efd912d06a91b999b202cd68e, // keccak256("SignerReounced(address,address)")
                caller(),
                _newSigner // indexed parameter
            )
        }
    }

    function isSigner(address _check) public view returns (bool result) {
        return signers[_check];
    }

    modifier onlySigner() {
        if (!isSigner(_msgSender())) {
            revert();
        }
        _;
    }

    function _setSuperAdmin(address _newSuperOwner) internal virtual override {
        signers[_msgSender()] = false;
        signers[_newSuperOwner] = true;
        super._setSuperAdmin(_newSuperOwner);
    }

    function _addSigner(address signer) internal {
        if (signer == address(0)) revert CallerZeroAddress();
        if (isSigner(signer)) revert AlreadySigner();
        signers[signer] = true;
        assembly {
            // Emit SignerAdded event
            log2(
                0x00, // start of data
                0x00, // length of data (0 as no data needed)
                0x47d1c22a25bb3a5d4e481b9b1e6944c2eade3181a0a20b495ed61d35b5323f24, // keccak256("SignerAdded(address)")
                signer // indexed parameter
            )
        }
    }

    function _removeSigner(address _signer) internal {
        if (!isSigner(_signer)) revert NonExistingSigner();
        if (_signer == _msgSender()) revert SuperAdminCannotRemoved();
        if (totalSigners() == 1) revert WalletCannotBeSignerLess();
        signers[_signer] = false;
        assembly {
            // Emit SignerAdded event
            log2(
                0x00, // start of data
                0x00, // length of data (0 as no data needed)
                0x3525e22824a8a7df2c9a6029941c824cf95b6447f1e13d5128fd3826d35afe8b, // keccak256("SignerRemoved(address)")
                _signer // indexed parameter
            )
        }
    }
}
