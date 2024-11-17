// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {SuperAdminMock} from "./Mock/SuperAdminMock.t.sol";
import {Test, console} from "forge-std/Test.sol";

contract SuperAdminTest is Test {
    SuperAdminMock superAdminMock;

    address public oldAdmin = makeAddr("oldAdmin");
    address public newAdmin = makeAddr("newAdmin");
    address public unauthorizedUser = makeAddr("unauthorizedUser");
    address public otherSigner = makeAddr("otherSigner");

    function setUp() public {
        // Set up the mock contract and initialize it with oldAdmin as the initial super admin
        superAdminMock = new SuperAdminMock();
        superAdminMock.initializeAdmin(oldAdmin);
    }

    function test_initialSuperAdmin() public view {
        // Check that the initial admin is correctly set
        assertEq(superAdminMock.superAdmin(), oldAdmin);
    }

    function test_superAdminTransfer() public {
        // Begin transaction with oldAdmin as the sender
        vm.startPrank(oldAdmin);

        // Initiate ownership transfer to newAdmin
        superAdminMock.sendSuperAdminOwnership(newAdmin);
        assert(superAdminMock.superAdminshipHandoverExpiresAt(newAdmin) > 0);

        // Stop acting as oldAdmin
        vm.stopPrank();

        // Test: Unauthorized user should not be able to accept ownership handover
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        superAdminMock.acceptOwnershipHandover();

        // NewAdmin accepts ownership handover
        vm.startPrank(newAdmin);
        superAdminMock.acceptOwnershipHandover();

        // Verify newAdmin is now the super admin
        assertEq(superAdminMock.superAdmin(), newAdmin);

        // Test that newAdmin has super admin rights
        superAdminMock.isSuperAdmin();

        vm.stopPrank();
    }

    function test_revokeSuperAdminOwnership() public {
        // New admin takes over first
        vm.startPrank(oldAdmin);
        superAdminMock.sendSuperAdminOwnership(newAdmin);
        vm.stopPrank();

        // Revoke super admin and check if it resets
        vm.prank(oldAdmin);
        superAdminMock.cancelOwnershipHandover(newAdmin);

        vm.startPrank(newAdmin);
        //should fail as adminship is accepted

        vm.expectRevert();
        superAdminMock.acceptOwnershipHandover();

        vm.stopPrank();
    }

    function test_multipleAdminTransferAttempts() public {
        // Start as oldAdmin
        vm.startPrank(oldAdmin);

        // Initiate transfer to newAdmin
        superAdminMock.sendSuperAdminOwnership(newAdmin);
        assert(superAdminMock.superAdminshipHandoverExpiresAt(newAdmin) > 0);
        vm.stopPrank();

        // Another signer tries to accept admin without permission
        vm.expectRevert();
        vm.prank(otherSigner);
        superAdminMock.acceptOwnershipHandover();

        // Now newAdmin accepts ownership
        vm.startPrank(newAdmin);
        superAdminMock.acceptOwnershipHandover();
        assertEq(superAdminMock.superAdmin(), newAdmin);
        vm.stopPrank();

        // Ensure oldAdmin no longer has control
        vm.expectRevert();
        vm.prank(oldAdmin);
        superAdminMock.cancelOwnershipHandover(newAdmin);
    }
}
