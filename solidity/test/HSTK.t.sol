// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from 'forge-std/Test.sol';
import { HstkToken } from '../src/HSTK.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
    constructor() ERC20('MYToken', 'MTK') { }
}

contract TestHSTK is Test {
    uint private constant TOTAL_SUPPLY = 9_000_000_000;

    address admin = address(1);
    HstkToken hstkToken;

    function setUp() public {
        hstkToken = new HstkToken(admin);
    }

    function testInitialization() public view {
        bytes memory tokenName1 = abi.encode(hstkToken.name());
        bytes memory tokenName2 = abi.encode('Hstk Token');
        // console.log("rokenName2: ",tokenName2);
        bytes memory tokenSymbol = abi.encode(hstkToken.symbol());
        bytes memory tokenSymbol2 = abi.encode('HSTK');
        assertEq(tokenName1, tokenName2, "Token name didn't matched");
        assertEq(tokenSymbol, tokenSymbol2, "Token Symbol didn't matched");
        assertEq(hstkToken.decimals(), 18, "Token decimal didn't matched");
        assertEq(hstkToken.balanceOf(admin), 1, "balance didn't mached");
        assertEq(hstkToken.totalSupply(),1,"total supply didn't matched");
    }

    function testFuzzMintWithAdmin(uint amount) public {
        address to = address(2);
        vm.startPrank(admin);
        vm.assume(amount < TOTAL_SUPPLY && amount > 0);
        hstkToken.pause();
        hstkToken.unpause();
        hstkToken.mint(to, amount);
        assertEq(hstkToken.balanceOf(to), amount);
        vm.stopPrank();
    }

    function testFuzzMintWithAdminWhenPaused(uint amount) public {
        address to = address(2);
        vm.prank(admin);
        vm.assume(amount < TOTAL_SUPPLY && amount > 0);
        hstkToken.pause();
        vm.expectRevert();
        hstkToken.mint(to, amount);
        // assertEq(hstkToken.balanceOf(to),amount);
    }

    function testFuzzMintWithNonAdmin(uint amount) public {
        address to = address(2);
        vm.startPrank(to);
        vm.assume(amount < TOTAL_SUPPLY && amount > 0);
        vm.expectRevert();
        hstkToken.mint(to, amount);
    }

    function testFuzzMintMaxSupply() public {
        vm.startPrank(admin);
        uint amount = TOTAL_SUPPLY - 1;
        // vm.expectRevert();
        hstkToken.mint(address(2), amount);
    }

    function testFuzzTransferToken(uint amount) public {
        address to = address(2);
        address too = address(3);
        vm.assume(amount<TOTAL_SUPPLY && amount>0);
        vm.prank(admin);
        hstkToken.mint(to,amount);
        vm.prank(to);
        hstkToken.transfer(too,amount);
    }
    function testFuzzTransferWhenPaused(uint amount) public {
        address to = address(2);
        address too = address(3);
        vm.assume(amount<TOTAL_SUPPLY && amount>0);
        vm.startPrank(admin);
        hstkToken.mint(to,amount);
        hstkToken.pause();
        vm.stopPrank();
        vm.prank(to);
        vm.expectRevert();
        hstkToken.transfer(too,amount);
    }
     function testFuzzTransferWhenPartialPaused(uint amount) public {
        address to = address(2);
        address too = address(3);
        vm.assume(amount<TOTAL_SUPPLY && amount>0);
        vm.startPrank(admin);
        hstkToken.mint(to,amount);
        hstkToken.partialPause();
        vm.stopPrank();
        vm.prank(to);
        vm.expectRevert();
        hstkToken.transfer(too,amount);
    }



    
}
