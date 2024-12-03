// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {SuperAdmin2Step} from "../src/AccessRegistry/helpers/superAdmin2Step.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockSuperAdmin2Step is SuperAdmin2Step {
    constructor(address admin) {
        _setSuperAdmin(admin);
    }
}

contract SuperAdmin2StepTest is Test {
    event SuperAdminshipHandoverRequested(address indexed pendingSuperAdmin);
    event SuperAdminshipTransferred(address indexed oldSuperAdmin, address indexed newSuperAdmin);

    MockSuperAdmin2Step fallbackContract;

    address public superAdmin = makeAddr("superAdmin");

    function setUp() public {
        // Set up the mock contract and initialize it with oldAdmin as the initial super admin
        fallbackContract = new MockSuperAdmin2Step(superAdmin);
    }

    function test_superAdminTransfer() public {
        // Begin transaction with oldAdmin as the sender

        address claimer1 = makeAddr("claimer1");
        address claimer2 = makeAddr("claimer2");

        vm.expectEmit(true, false, false, false);
        emit SuperAdminshipHandoverRequested(claimer1);

        vm.prank(superAdmin);
        fallbackContract.requestSuperAdminTransfer(claimer1);

        vm.expectEmit(true, false, false, false);
        emit SuperAdminshipHandoverRequested(claimer2);

        vm.prank(superAdmin);
        fallbackContract.requestSuperAdminTransfer(claimer2);

        vm.expectRevert(SuperAdmin2Step.SuperAdmin2Step_Unauthorized.selector);
        // vm.expectRevert();
        vm.prank(claimer1);
        fallbackContract.acceptSuperAdminTransfer();

        vm.expectEmit(true, true, false, false);
        emit SuperAdminshipTransferred(superAdmin, claimer2);

        vm.prank(claimer2);
        fallbackContract.acceptSuperAdminTransfer();

        assertEq(fallbackContract.superAdmin(), claimer2, "Error");
    }

    function test_revokeSuperAdminOwnership() public {
        address random = makeAddr("random");
        address claimer = makeAddr("claimer");

        vm.expectRevert(SuperAdmin2Step.SuperAdmin2Step_Unauthorized.selector);
        vm.prank(random);
        fallbackContract.requestSuperAdminTransfer(random);

        vm.prank(superAdmin);
        fallbackContract.requestSuperAdminTransfer(claimer);

        vm.expectRevert(SuperAdmin2Step.SuperAdmin2Step_Unauthorized.selector);
        vm.prank(random);
        fallbackContract.acceptSuperAdminTransfer();

        // vm.warp(block.timestamp + 86400 + 1);

        // vm.expectRevert(SuperAdmin2Step.SuperAdmin2Step_NoHandoverRequest.selector);
        // vm.prank(claimer);
        // fallbackContract.completeSuperAdminshipHandover();

        vm.warp(block.timestamp + 86400 - 1);

        vm.prank(claimer);
        fallbackContract.acceptSuperAdminTransfer();

        assertEq(fallbackContract.superAdmin(), claimer, "Error");
    }

    function test_TransferRequest() public {
        // Start as oldAdmin
        address claimer = makeAddr("claimer");
        vm.prank(superAdmin);
        fallbackContract.requestSuperAdminTransfer(claimer);

        vm.prank(claimer);
        vm.expectRevert();
        fallbackContract.cancelSuperAdminTransfer();

        vm.prank(superAdmin);
        fallbackContract.cancelSuperAdminTransfer();
    }
}
