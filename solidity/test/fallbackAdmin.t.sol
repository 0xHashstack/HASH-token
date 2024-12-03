// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {FallbackAdmin2Step} from "../src/AccessRegistry/helpers/fallbackAdmin2Step.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockFallbackAdmin2Step is FallbackAdmin2Step {
    constructor(address admin) {
        _setFallbackAdmin(admin);
    }
}

contract FallbackAdmin2StepTest is Test {
    event FallbackAdminshipHandoverRequested(address indexed pendingFallbackAdmin);
    event FallbackAdminshipTransferred(address indexed oldFallbackAdmin, address indexed newFallbackAdmin);

    MockFallbackAdmin2Step fallbackContract;

    address public fallbackAdmin = makeAddr("fallbackAdmin");
    address public newAdmin = makeAddr("newAdmin");
    address public unauthorizedUser = makeAddr("unauthorizedUser");
    address public otherSigner = makeAddr("otherSigner");

    function setUp() public {
        // Set up the mock contract and initialize it with oldAdmin as the initial super admin
        fallbackContract = new MockFallbackAdmin2Step(fallbackAdmin);
    }

    function test_fallbackAdminTransfer() public {
        // Begin transaction with oldAdmin as the sender

        address claimer1 = makeAddr("claimer1");
        address claimer2 = makeAddr("claimer2");

        vm.expectEmit(true, false, false, false);
        emit FallbackAdminshipHandoverRequested(claimer1);

        vm.prank(fallbackAdmin);
        fallbackContract.requestFallbackAdminTransfer(claimer1);

        vm.expectEmit(true, false, false, false);
        emit FallbackAdminshipHandoverRequested(claimer2);

        vm.prank(fallbackAdmin);
        fallbackContract.requestFallbackAdminTransfer(claimer2);

        vm.expectRevert(FallbackAdmin2Step.FallbackAdmin2Step_Unauthorized.selector);
        // vm.expectRevert();
        vm.prank(claimer1);
        fallbackContract.acceptFallbackAdminTransfer();

        vm.expectEmit(true, true, false, false);
        emit FallbackAdminshipTransferred(fallbackAdmin, claimer2);

        vm.prank(claimer2);
        fallbackContract.acceptFallbackAdminTransfer();

        assertEq(fallbackContract.fallbackAdmin(), claimer2, "Error");
    }

    function test_revokefallbackAdminOwnership() public {
        address random = makeAddr("random");
        address claimer = makeAddr("claimer");

        vm.expectRevert(FallbackAdmin2Step.FallbackAdmin2Step_Unauthorized.selector);
        vm.prank(random);
        fallbackContract.requestFallbackAdminTransfer(random);

        vm.prank(fallbackAdmin);
        fallbackContract.requestFallbackAdminTransfer(claimer);

        vm.expectRevert(FallbackAdmin2Step.FallbackAdmin2Step_Unauthorized.selector);
        vm.prank(random);
        fallbackContract.acceptFallbackAdminTransfer();

        // vm.warp(block.timestamp + 86400 + 1);

        // vm.expectRevert(FallbackAdmin2Step.FallbackAdmin2Step_NoHandoverRequest.selector);
        // vm.prank(claimer);
        // fallbackContract.completeFallbackAdminshipHandover();

        vm.warp(block.timestamp + 86400 - 1);

        vm.prank(claimer);
        fallbackContract.acceptFallbackAdminTransfer();

        assertEq(fallbackContract.fallbackAdmin(), claimer, "Error");
    }

    function test_cancelTransferRequest() public {
        // Start as oldAdmin
        address claimer = makeAddr("claimer");
        vm.prank(fallbackAdmin);
        fallbackContract.requestFallbackAdminTransfer(claimer);

        vm.prank(claimer);
        vm.expectRevert();
        fallbackContract.cancelFallbackAdminTransfer();

        vm.prank(fallbackAdmin);
        fallbackContract.cancelFallbackAdminTransfer();
    }
}
