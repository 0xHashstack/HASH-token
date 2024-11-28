// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {FallbackAdminMock} from "./Mock/FallbackAdminMock.t.sol";
import {Test, console} from "forge-std/Test.sol";

contract FallbackAdminTest is Test {
    FallbackAdminMock fallbackAdminMock;

    address public oldAdmin = makeAddr("oldAdmin");
    address public newAdmin = makeAddr("newAdmin");
    address public unauthorizedUser = makeAddr("unauthorizedUser");
    address public otherSigner = makeAddr("otherSigner");

    function setUp() public {
        // Set up the mock contract and initialize it with oldAdmin as the initial fallback admin
        fallbackAdminMock = new FallbackAdminMock();
        fallbackAdminMock.initializeAdmin(oldAdmin);
    }

    function test_initialFallbackAdmin() public view {
        // Check that the initial admin is correctly set
        assertEq(fallbackAdminMock.fallbackAdmin(), oldAdmin);
    }

    function test_fallbackAdminTransfer() public {
        // Begin transaction with oldAdmin as the sender
        vm.startPrank(oldAdmin);

        // Initiate ownership transfer to newAdmin
        fallbackAdminMock.sendFallbackAdminOwnership(newAdmin);
        assert(fallbackAdminMock.fallbackAdminshipHandoverExpiresAt(newAdmin) > 0);

        // Stop acting as oldAdmin
        vm.stopPrank();

        // Test: Unauthorized user should not be able to accept ownership handover
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        fallbackAdminMock.completeFallbackAdminshipHandover();

        // NewAdmin accepts ownership handover
        vm.startPrank(newAdmin);
        fallbackAdminMock.completeFallbackAdminshipHandover();

        // Verify newAdmin is now the fallback admin
        assertEq(fallbackAdminMock.fallbackAdmin(), newAdmin);

        // Test that newAdmin has fallback admin rights
        fallbackAdminMock.isFallbackAdmin();

        vm.stopPrank();
    }

    function test_revokeFallbackAdminOwnership() public {
        // New admin takes over first
        vm.startPrank(oldAdmin);
        fallbackAdminMock.sendFallbackAdminOwnership(newAdmin);
        vm.stopPrank();

        // Revoke fallback admin and check if it resets
        vm.prank(oldAdmin);
        fallbackAdminMock.cancelFallbackAdminshipHandover();

        vm.startPrank(newAdmin);
        //should fail as adminship is accepted

        vm.expectRevert();
        fallbackAdminMock.completeFallbackAdminshipHandover();

        vm.stopPrank();
    }

    function test_multipleAdminTransferAttempts() public {
        // Start as oldAdmin
        vm.startPrank(oldAdmin);

        // Initiate transfer to newAdmin
        fallbackAdminMock.sendFallbackAdminOwnership(newAdmin);
        assert(fallbackAdminMock.fallbackAdminshipHandoverExpiresAt(newAdmin) > 0);
        vm.stopPrank();

        // Another signer tries to accept admin without permission
        vm.expectRevert();
        vm.prank(otherSigner);
        fallbackAdminMock.completeFallbackAdminshipHandover();

        // Now newAdmin accepts ownership
        vm.startPrank(newAdmin);
        fallbackAdminMock.completeFallbackAdminshipHandover();
        assertEq(fallbackAdminMock.fallbackAdmin(), newAdmin);
        vm.stopPrank();

        // Ensure oldAdmin no longer has control
        vm.expectRevert();
        vm.prank(oldAdmin);
        fallbackAdminMock.cancelFallbackAdminshipHandover();
    }
}
