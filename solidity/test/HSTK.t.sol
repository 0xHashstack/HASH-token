// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {HstkToken} from "../src/HSTK.sol";

contract TestHSTK is Test {
    // Constants
    uint256 private constant TOTAL_SUPPLY = 9_000_000_000e18;

    error InvalidOperation();
    error InvalidStateChange();
    error RestrictedToMultiSig();
    error EnforcedPause();
    error AccountBlackListed(address account);

    // Test accounts
    address admin = address(1);
    address user1 = address(2);
    address user2 = address(3);

    // Contract instance
    HstkToken hstkToken;

    function setUp() public {
        hstkToken = new HstkToken(admin);
        targetContract(address(hstkToken));
    }

    function testInitialization() public view {
        // Test token name
        bytes memory tokenName1 = abi.encode(hstkToken.name());
        bytes memory tokenName2 = abi.encode("MOCK");
        assertEq(tokenName1, tokenName2, "Token name mismatch");

        // Test token symbol
        bytes memory tokenSymbol = abi.encode(hstkToken.symbol());
        bytes memory tokenSymbol2 = abi.encode("HSTK");
        assertEq(tokenSymbol, tokenSymbol2, "Token symbol mismatch");

        // Test other initial values
        assertEq(hstkToken.decimals(), 18, "Token decimal mismatch");
        // assertEq(hstkToken.balanceOf(admin), 10 ** hstkToken.decimals(), "Initial admin balance mismatch");
        // assertEq(hstkToken.totalSupply(), 1 * 10 ** hstkToken.decimals(), "Initial total supply mismatch");
    }

    function testFuzzMintWithAdmin(uint256 amount) public {
        vm.assume(amount < TOTAL_SUPPLY - 10 ** 18 && amount > 0);

        vm.startPrank(admin);
        hstkToken.updateOperationalState(2);
        hstkToken.updateOperationalState(0);
        hstkToken.mint(user1, amount);
        vm.stopPrank();

        assertEq(hstkToken.balanceOf(user1), amount, "Minted amount mismatch");
    }

    function testFuzzMintWithAdminWhenPaused(uint256 amount) public {
        vm.assume(amount < TOTAL_SUPPLY - 10 ** 18 && amount > 0);

        vm.startPrank(admin);
        hstkToken.updateOperationalState(2);
        // hstkToken.updateOperationalState(1);

        vm.expectRevert(InvalidStateChange.selector);
        hstkToken.mint(user1, amount);

        vm.stopPrank();
    }

    function testFuzzMintWithNonAdmin(uint256 amount) public {
        vm.assume(amount < TOTAL_SUPPLY - 10 ** 18 && amount > 0);

        vm.prank(user1);
        vm.expectRevert(RestrictedToMultiSig.selector);
        hstkToken.mint(user1, amount);
    }

    function testFuzzMintMaxSupply() public {
        uint256 amount = TOTAL_SUPPLY - 1 * 10 ** 18;

        vm.prank(admin);
        hstkToken.mint(user1, amount);
    }

    function testFuzzTransferToken(uint256 amount) public {
        vm.assume(amount < TOTAL_SUPPLY - 10 ** 18 && amount > 0);

        vm.prank(admin);
        hstkToken.mint(user1, amount);

        vm.prank(user1);
        hstkToken.transfer(user2, amount);
    }

    function testFuzzTransferWhenPaused(uint256 amount) public {
        vm.assume(amount < TOTAL_SUPPLY - 10 ** 18 && amount > 0);

        vm.startPrank(admin);
        hstkToken.mint(user1, amount);
        hstkToken.updateOperationalState(2);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(EnforcedPause.selector);
        hstkToken.transfer(user2, amount);
    }

    function testFuzzTransferWhenPartialPaused(uint256 amount) public {
        vm.assume(amount < TOTAL_SUPPLY - 1 * 10 ** 18 && amount > 0);

        vm.startPrank(admin);
        hstkToken.mint(user1, amount);
        hstkToken.updateOperationalState(1);
        assertEq(uint8(hstkToken.getCurrentState()), 1);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        hstkToken.transfer(user2, amount);
    }

    function testFuzzTransferToBlackListed(uint256 amount, address blacklistedAccount) public {
        vm.assume(amount > 0 && amount < TOTAL_SUPPLY - 10 ** 18 && blacklistedAccount != address(0));

        vm.startPrank(admin);
        hstkToken.mint(user1, amount);
        hstkToken.blackListAccount(blacklistedAccount);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        hstkToken.approve(blacklistedAccount, amount);
        vm.stopPrank();
    }

    function testFuzzApproveToBlackListed(uint256 amount, address blacklistedAccount) public {
        vm.assume(amount > 0 && amount < TOTAL_SUPPLY - 10 ** 18 && blacklistedAccount != address(0));

        vm.prank(admin);
        hstkToken.mint(user1, amount);

        vm.prank(user1);
        hstkToken.approve(blacklistedAccount, amount);

        vm.prank(admin);
        hstkToken.blackListAccount(blacklistedAccount);

        vm.prank(blacklistedAccount);
        vm.expectRevert();
        hstkToken.transferFrom(user1, blacklistedAccount, amount);
    }

    function testFuzzSendEthToContract(uint256 amount) public {
        vm.deal(user1, amount);
        assertEq(address(user1).balance, amount);
        vm.prank(user1);
        vm.expectRevert();
        (bool success,) = address(hstkToken).call{value: amount}("");
        assertEq(address(user1).balance, amount);
        assertEq(address(hstkToken).balance, 0);
    }
}
