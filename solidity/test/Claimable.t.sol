// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Claimable} from "../src/Claimable2.sol";
import {HstkToken} from "../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract ClaimableTest is Test {
    Claimable public claimable;
    HstkToken public token;

    address public owner;
    address public beneficiary1;
    address public beneficiary2;
    address public claimer;

    function setUp() public {
        owner = makeAddr("owner");
        beneficiary1 = makeAddr("beneficiary1");
        beneficiary2 = makeAddr("beneficiary2");
        claimer = makeAddr("claimer");

        // Deploy mock ERC20 token
        token = new HstkToken(owner);

        // Deploy and initialize Claimable contract
        Claimable implementation = new Claimable();

        bytes memory callData = abi.encodeWithSelector(Claimable.initialize.selector, address(token), owner);

        ERC1967Proxy claimableContract_ = new ERC1967Proxy(address(implementation), callData);

        claimable = Claimable(address(claimableContract_));

        vm.prank(owner);
        token.transfer(address(claimable), 10_000_000 * 10 ** 18);
    }

    function testInitialization() public view {
        assertEq(address(claimable.token()), address(token), "Initialization failed");
        assertEq(claimable.owner(), owner, "Initialization Data failed");
        assertEq(token.balanceOf(address(claimable)), 10_000_000 * 10 ** 18);
    }

    // Ticket Creation Tests
    function test_CreateTicket() public {
        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, 20, false);

        // Verify ticket details
        Claimable.Ticket memory ticket = claimable.viewTicket(ticketId);
        assertEq(ticket.beneficiary, beneficiary1);
        assertEq(ticket.cliff, 30);
        assertEq(ticket.vesting, 90);
        assertEq(ticket.amount, 1000);
        assertEq(ticket.balance, 1000);
        assertFalse(ticket.irrevocable);
    }

    function test_CreateTicket_Reverts_ZeroBeneficiary() public {
        vm.prank(owner);
        vm.expectRevert(Claimable.InvalidBeneficiary.selector);
        claimable.create(address(0), 30, 90, 1000, 20, false);
    }

    function test_CreateTicket_Reverts_ZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(Claimable.InvalidAmount.selector);
        claimable.create(beneficiary1, 30, 90, 0, 20, false);
    }

    function test_CreateTicket_Reverts_InvalidVestingPeriod() public {
        vm.prank(owner);
        vm.expectRevert(Claimable.InvalidVestingPeriod.selector);
        claimable.create(beneficiary1, 90, 30, 1000, 20, false);
    }

    function test_BatchCreateSameAmount() public {
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        // Create batch tickets
        vm.prank(owner);
        claimable.batchCreateSameAmount(beneficiaries, 30, 90, 1000, 20, false);

        // Verify ticket creation
        vm.prank(beneficiary1);
        uint256[] memory ticket1Ids = claimable.myBeneficiaryTickets(beneficiary1);
        assertEq(ticket1Ids.length, 1);

        vm.prank(beneficiary2);
        uint256[] memory ticket2Ids = claimable.myBeneficiaryTickets(beneficiary1);
        assertEq(ticket2Ids.length, 1);
    }

    // Fuzz Tests for Claiming
    // 17, 3241, 124, false -fuzz fail
    // 2, 3139, 1037
    function testFuzz_Claim() public {
        uint256 cliff = 0;
        uint256 vesting = 1;
        uint256 amount = 1 *10**18;

        address claimer = makeAddr("Claimer");

        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, cliff, vesting, amount, 20, false);

        uint256 availableAmount = claimable.available(ticketId);
        // assertEq(availableAmount, 50000, "Incorrect Amount");
        console.log("availableAmount : ", availableAmount);

        vm.prank(beneficiary1);
        claimable.delegateClaim(ticketId, claimer);

        vm.prank(claimer);
        claimable.acceptClaim(ticketId);

        // vm.warp(block.timestamp + (cliff) * 86400);

        // availableAmount = claimable.available(ticketId);
        // assertEq(availableAmount, 0, "Incorrect Amount");

        // vm.warp(block.timestamp + 90 * 86400);

        // availableAmount = claimable.available(ticketId);
        // assertEq(availableAmount, 25000, "Incorrect Amount");

        // vm.prank(beneficiary1);
        // claimable.delegateClaim(ticketId, beneficiary1);

        // assertEq(token.balanceOf(beneficiary1), 25000, "InValid Amount");
        // assertEq(token.balanceOf(claimer), 50000, "InValid Amount");

        // vm.warp(block.timestamp + 90 * 86400);

        // availableAmount = claimable.available(ticketId);
        // assertEq(availableAmount, 25000, "Invalid Amount");

        // vm.warp(block.timestamp + 365 * 86400);
        // assertEq(availableAmount, 25000, "Invalid Amount");

        // vm.prank(beneficiary1);
        // claimable.delegateClaim(ticketId, beneficiary1);

        // assertEq(token.balanceOf(beneficiary1), 50000, "InValid Amount");

        // availableAmount = claimable.available(ticketId);
        // assertEq(availableAmount, 0, "Invalid Amount");
    }

    // function testFuzz_DelegateClaim(uint256 amount) public {
    //     // Constrain inputs
    //     amount = bound(amount, 1000, 1_000_000*10**18);
    //     address pendingClaimer = makeAddr("pendingClaimer");

    //     // Create ticket
    //     vm.prank(owner);
    //     uint256 ticketId = claimable.create(beneficiary1, 30, 90, amount, 20,false);

    //     // Fast forward past cliff
    //     vm.warp(block.timestamp + (60 * 86400) );

    //     uint256 availableAmount = claimable.available(ticketId);
    //     console.log("availableAmount: ",availableAmount);

    //     // Delegate claim
    //     vm.prank(beneficiary1);
    //     claimable.delegateClaim(ticketId, pendingClaimer);

    //     // Accept claim
    //     vm.prank(pendingClaimer);
    //     claimable.acceptClaim(ticketId);

    //     // Verify balance
    //     assertEq(token.balanceOf(pendingClaimer), availableAmount, "Claimed amount should match available");
    // }

    //     // Revocation Tests
    function test_Revoke_Ticket() public {
        // Approve tokens for transfer
        vm.prank(owner);
        token.approve(address(claimable), 1000);

        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, 10, false);

        // Track initial owner balance
        uint256 initialOwnerBalance = token.balanceOf(owner);

        // Revoke ticket
        vm.prank(owner);
        claimable.revoke(ticketId);

        // Verify owner received remaining balance
        assertEq(token.balanceOf(owner), initialOwnerBalance + 1000);

        // Verify ticket is revoked
        Claimable.Ticket memory ticket = claimable.viewTicket(ticketId);
        assertTrue(ticket.isRevoked);
        assertEq(ticket.balance, 0);
    }

    //     function test_Revoke_Reverts_IrrevocableTicket() public {
    //         // Approve tokens for transfer
    //         vm.prank(owner);
    //         token.approve(address(claimable), 1000);

    //         // Create irrevocable ticket
    //         vm.prank(owner);
    //         uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, true);

    //         // Attempt to revoke
    //         vm.prank(owner);
    //         vm.expectRevert(Claimable.IrrevocableTicket.selector);
    //         claimable.revoke(ticketId);
    //     }

    //     // Upgrade Tests
    //     function test_CanUpgrade() public {
    //         // Deploy new implementation
    //         Claimable newImplementation = new Claimable();

    //         // Prepare upgrade data
    //         bytes memory upgradeData = abi.encodeCall(Claimable.initialize, (address(token), owner));

    //         // Upgrade
    //         vm.prank(owner);
    //         UUPSUpgradeable(address(claimable)).upgradeToAndCall(address(newImplementation), upgradeData);

    //         // Verify contract still works
    //         vm.prank(owner);
    //         token.approve(address(claimable), 1000);

    //         vm.prank(owner);
    //         uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, false);

    //         Claimable.Ticket memory ticket = claimable.viewTicket(ticketId);
    //         assertEq(ticket.beneficiary, beneficiary1);
    //     }

    //     // Access Control Tests
    //     function test_Reverts_UnauthorizedClaim() public {
    //         // Approve tokens for transfer
    //         vm.prank(owner);
    //         token.approve(address(claimable), 1000);

    //         // Create ticket
    //         vm.prank(owner);
    //         uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, false);

    //         // Try to claim by unauthorized user
    //         vm.prank(claimer);
    //         vm.expectRevert(Claimable.UnauthorizedAccess.selector);
    //         claimable.available(ticketId);
    //     }

    //     // Helper to bound address to avoid zero address
    //     function _boundAddress(address addr) internal view returns (address) {
    //         return addr == address(0) ? makeAddr("defaultClaimer") : addr;
    //     }
    // }
}
