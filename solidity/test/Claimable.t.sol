// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Claimable} from "../src/Claimable.sol";
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
        token.mint(address(claimable), 10_000_000 * 10 ** 18);
    }

    function testInitialization() public view {
        assertEq(address(claimable.token()), address(token), "Initialization failed");
        assertEq(claimable.owner(), owner, "Initialization Data failed");
        assertEq(token.balanceOf(address(claimable)), 10_000_000 * 10 ** 18);
    }

    // Ticket Creation Tests
    function test_CreateTicket() public returns (uint256) {
        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, 20, 0);

        // Verify ticket details
        Claimable.Ticket memory ticket = claimable.viewTicket(ticketId);
        assertEq(ticket.beneficiary, beneficiary1);
        assertEq(ticket.cliff, 30);
        assertEq(ticket.vesting, 90);
        assertEq(ticket.amount, 1000);
        assertEq(ticket.balance, 1000);
        return ticketId;
    }

    function test_CreateTicket_Reverts_ZeroBeneficiary() public {
        vm.prank(owner);
        vm.expectRevert(Claimable.InvalidBeneficiary.selector);
        claimable.create(address(0), 30, 90, 1000, 20, 0);
    }

    function test_CreateTicket_Reverts_ZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(Claimable.InvalidAmount.selector);
        claimable.create(beneficiary1, 30, 90, 0, 20, 0);
    }

    function test_CreateTicket_Reverts_InvalidVestingPeriod() public {
        vm.prank(owner);
        vm.expectRevert(Claimable.InvalidVestingPeriod.selector);
        claimable.create(beneficiary1, 90, 30, 1000, 20, 0);
    }

    function test_BatchCreateSameAmount() public {
        address[] memory beneficiaries = new address[](4);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;
        beneficiaries[2] = makeAddr("beneficiary3");
        beneficiaries[3] = makeAddr("beneficiary4");

        // Create batch tickets
        vm.prank(owner);
        claimable.batchCreateSameAmount(beneficiaries, 30, 90, 1000, 20, 0);

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
        uint256 cliff = 90;
        uint256 vesting = 180;
        uint256 amount = 100_000;

        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, cliff, vesting, amount, 50, 0);

        uint256 availableAmount = claimable.available(ticketId);
        assertEq(availableAmount, 50000, "Incorrect Amount");
        console.log("availableAmount : ", availableAmount);

        vm.prank(beneficiary1);
        claimable.claimTicket(ticketId, claimer);

        vm.warp(block.timestamp + (cliff) * 86400);

        availableAmount = claimable.available(ticketId);
        assertEq(availableAmount, 0, "Incorrect Amount");

        vm.warp(block.timestamp + 90 * 86400);

        availableAmount = claimable.available(ticketId);
        assertEq(availableAmount, 25000, "Incorrect Amount");

        vm.prank(beneficiary1);
        claimable.claimTicket(ticketId, beneficiary1);

        assertEq(token.balanceOf(beneficiary1), 25000, "InValid Amount");
        assertEq(token.balanceOf(claimer), 50000, "InValid Amount");

        vm.warp(block.timestamp + 90 * 86400);

        availableAmount = claimable.available(ticketId);
        assertEq(availableAmount, 25000, "Invalid Amount");

        vm.warp(block.timestamp + 365 * 86400);
        assertEq(availableAmount, 25000, "Invalid Amount");

        vm.prank(beneficiary1);
        claimable.claimTicket(ticketId, beneficiary1);

        assertEq(token.balanceOf(beneficiary1), 50000, "InValid Amount");

        availableAmount = claimable.available(ticketId);
        assertEq(availableAmount, 0, "Invalid Amount");
    }

    function test_BatchCreateGasCheck() public {
        // Create batch tickets
        vm.startPrank(owner);
        for (uint256 i = 0; i < 100; i++) {
            claimable.create(beneficiary1, 30, 90, 1000, 20, 0);
        }
        uint256[] memory ticket1Ids = claimable.myBeneficiaryTickets(beneficiary1);
        for (uint256 i = 0; i < 100; i++) {
            console.log("Tickets : ", ticket1Ids[i]);
        }
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

    function test_Claim_AfterRevoke() public {
        // Approve tokens for transfer
        vm.prank(owner);
        token.approve(address(claimable), 1000);

        // Create irrevocable ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, 50, 0);

        // Attempt to revoke
        vm.prank(owner);
        claimable.revoke(ticketId);
        vm.prank(beneficiary1);
        vm.expectRevert();
        claimable.claimTicket(ticketId, beneficiary1);
    }

    // Ticket Creation Tests
    function test_ticketAfterVesting() public returns (uint256) {
        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, 20, 0);
        // vm.prank(beneficiary1);
        vm.warp(block.timestamp + 15 * 86400);
        console.log(claimable.unlocked(ticketId));
        console.log(claimable.available(ticketId));
        vm.prank(beneficiary1);
        claimable.claimTicket(ticketId, beneficiary1);
        console.log(claimable.unlocked(ticketId));
        console.log(claimable.available(ticketId));
        // Claimable.Ticket memory ticket = claimable.viewTicket(ticketId);
        // console.log(ticket.cliff, 30);
        // console.log(ticket.vesting, 90);
        // console.log(ticket.amount, 1000);
        // console.log(ticket.balance, 1000);
        vm.warp(block.timestamp + 120 * 86400);
        // Verify ticket details
        console.log(claimable.unlocked(ticketId));
        console.log(claimable.available(ticketId));
        vm.prank(beneficiary1);
        claimable.claimTicket(ticketId, beneficiary1);
        console.log(claimable.unlocked(ticketId));
        console.log(claimable.available(ticketId));
        return ticketId;
    }

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
