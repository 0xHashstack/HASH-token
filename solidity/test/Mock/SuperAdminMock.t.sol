// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {SuperAdmin} from "../../src/AccessRegistry/helpers/superAdmin.sol";

contract SuperAdminMock is SuperAdmin {
    error WrongSuperAdmin();

    function _guardInitializeSuperAdmin() internal pure virtual override returns (bool) {
        return true;
    }

    function initializeAdmin(address admin) public {
        _initializeSuperAdmin(admin);
    }

    function isSuperAdmin() public view {
        if (superAdmin() != msg.sender) {
            revert WrongSuperAdmin();
        }
    }
}
