// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {FallbackAdmin} from "../../src/AccessRegistry/helpers/FallbackAdmin.sol";

contract FallbackAdminMock is FallbackAdmin {
    error WrongFallbackAdmin();

    function _guardInitializeFallbackAdmin() internal pure virtual override returns (bool) {
        return true;
    }

    function initializeAdmin(address admin) public {
        _initializeFallbackAdmin(admin);
    }

    function isFallbackAdmin() public view {
        if (fallbackAdmin() != msg.sender) {
            revert WrongFallbackAdmin();
        }
    }
}
