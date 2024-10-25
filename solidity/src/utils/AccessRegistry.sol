// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract AccessRegistry is Context{
    event SignerAdded(address indexed newSigner);
    event SignerRemoved(address indexed removedSigner);
    event SignerRenounced(address indexed from, address indexed to);
    event SuperAdminRenounced(address indexed newSuperAdmin);

    error CallerZeroAddress();

    uint256 public totalSigner;
    mapping(address => bool) private signers;
    address public superAdmin;
    address public fallbackAdmin;

    modifier notZeroAddress(address account){
        if(account==address(0)){
            revert CallerZeroAddress();
        }
        _;
    }

    function init(address _superAdmin, address _fallbackAdmin) internal virtual {
        // require(_admin != address(0), "ACL:: Address cannot be Zero");
        superAdmin = _superAdmin;
        fallbackAdmin = _fallbackAdmin;
        signers[superAdmin] = true;
        totalSigner = totalSigner + 1;
    }

    function addSigner(address _newSigner) external virtual onlySuperAdmin notZeroAddress(_newSigner){
        // require(_newSigner != address(0), "ACL:: zero address");
        require(!isSigner(_newSigner), "ACL:: guardian cannot be owner");
        signers[_newSigner] = true;
        emit SignerAdded(_newSigner);
        totalSigner = totalSigner + 1;
    }

    function removeSigner(address _signer) public virtual onlySuperAdmin notZeroAddress(_signer) {
        require(signers[_signer], "ACL::non-existant owner");
        require(totalSigner > 1, "ACL::wallet cannot be ownerless");
        emit SignerRemoved(_signer);
        signers[_signer] = false;
        totalSigner = totalSigner - 1;
    }

    function renounceSignership(address _newSigner) public virtual onlySigner notZeroAddress(_newSigner) {
        require(_msgSender() != superAdmin, "ACL:: Admin is restricted");
        require(!isSigner(_newSigner), "ACL::New Address is Existing owner");

        signers[_msgSender()] = false;
        signers[_newSigner] = true;
        emit SignerRenounced(_msgSender(), _newSigner);
    }

    function isSigner(address _check) public view virtual returns (bool) {
        return signers[_check];
    }

    function transferAdminRole(address _newSuperAdmin) external virtual onlySuperAdmin notZeroAddress(_newSuperAdmin){
        require(!isSigner(_newSuperAdmin), "ACL:: Existing owner cannot be the Admin");
        superAdmin = _newSuperAdmin;
        signers[_newSuperAdmin] = true;

        emit SuperAdminRenounced(_newSuperAdmin);
    }

    function isFallbackAdmin(address account) public view returns (bool) {
        if (account == fallbackAdmin) {
            return true;
        }
        return false;
    }

    function transferFallbackAdminRole(address _newFallbackAdmin) external onlySuperAdmin  notZeroAddress(_newFallbackAdmin){
        require(_newFallbackAdmin != fallbackAdmin, "ACR::Inputed Account already fallbackAdmin");
        require(_newFallbackAdmin != superAdmin, "ACR::fallback Admin cannot be SuperAdmin");
        fallbackAdmin = _newFallbackAdmin;
    }

    modifier onlySuperAdmin() {
        if (_msgSender() != superAdmin) {
            revert();
        }
        _;
    }

    modifier onlySigner() {
        if (!isSigner(_msgSender())) {
            revert();
        }
        _;
    }

    modifier onlyFallbackAdmin() {
        if (!isFallbackAdmin(_msgSender())) {
            revert();
        }
        _;
    }
}
