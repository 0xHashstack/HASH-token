// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {DeployToken} from "../script/DeployToken.s.sol";
import {HashToken} from "../src/token/HashToken.sol";

contract HashTokenTest is Test {
    HashToken token;
    DeployToken tokenScript;

    // address user = vm.envAddress("WALLET_ADDRESS");
    address user = makeAddr("user"); // actual owner of the token

    function setUp() public {
        tokenScript = new DeployToken();
        token = tokenScript.run();
    }

    function testMint() public {
        uint256 amount = 1e18;
        vm.startPrank(user);
        token.mint(user, amount);
        assertEq(token.balanceOf(user), amount);
    }

    function testFailsIfUserIsNotOwner() public {
        uint256 amount = 1e18;
        address alice = makeAddr("alice");
        vm.startPrank(alice);
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function testFailsIfUserIsZeroAddress() public {
        uint256 amount = 1e18;
        address zeroAddress = address(0);
        vm.startPrank(user);
        token.mint(zeroAddress, amount);
    }

    function testFailsWhenBurningWithZeroAddress() public {
        uint256 zeroAmount = 0;
        vm.startPrank(address(0));
        token.burn(zeroAmount);
    }

    function testRescueTokens() public {
        address rescueAddress = makeAddr("rescueAddress");
        // 1. First Mint the tokens to the user
        uint256 amount = 10e18;
        vm.startPrank(user);
        token.mint(user,amount);

        // check token balances before sending
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));

        // 2. transfer the tokens to the hashtoken contract
        token.transfer(address(token),amount);

        // check token balances after sending tokens to contract 
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));


        token.rescueTokens(token,rescueAddress);

        // checking final balance of users
        console.log("rescueAddress balance:",token.balanceOf(rescueAddress));
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));
    }

    function testFailsWhenRescuingToZeroAddress() public {
        address rescueAddress = address(0);
        // 1. First Mint the tokens to the user
        uint256 amount = 10e18;
        vm.startPrank(user);
        token.mint(user,amount);

        // check token balances before sending
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));

        // 2. transfer the tokens to the hashtoken contract
        token.transfer(address(token),amount);

        // check token balances after sending tokens to contract 
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));


        token.rescueTokens(token,rescueAddress);

        // checking final balance of users
        console.log("rescueAddress balance:",token.balanceOf(rescueAddress));
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));
    }

    function testFailsWhenRescuingByUnauthorizedUser() public {
        // 1. First Mint the tokens to the user
        uint256 amount = 10e18;
        address alice = makeAddr("alice"); // random user(not owner)
        vm.startPrank(user);
        token.mint(user,amount);

        // check token balances before sending
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));

        // 2. transfer the tokens to the hashtoken contract
        token.transfer(address(token),amount);

        // check token balances after sending tokens to contract 
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));
        vm.stopPrank();

        vm.startPrank(alice);
        token.rescueTokens(token,alice);

        // checking final balance of users
        console.log("rescueAddress balance:",token.balanceOf(alice));
        console.log("user balance:",token.balanceOf(user));
        console.log("contract balance:",token.balanceOf(address(token)));
    }
}
