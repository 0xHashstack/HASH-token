// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployWallet} from "../script/DeployWallet.s.sol";
import {HashWallet} from "../src/wallet.sol";
import {HashToken} from "../src/token/HashToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WalletTest is Test {
    DeployWallet walletScript;
    HashWallet wallet;
    HashToken token;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    uint256 amount = 10e18;
    address user = makeAddr("user");

    function setUp() public {
        walletScript = new DeployWallet();
        wallet = walletScript.run();
        token = new HashToken(address(wallet));
    }

    function testContractInitizization() public view {
        address[] memory addr = wallet.getOwners();

        assertEq(addr[0], alice);
        assertEq(addr[1], bob);
        assertEq(addr[2], charlie);

        assertEq(wallet.numConfirmationsRequired(), 2);
    }

    function testFailsIfTransactionIsNotSubmittedByOwner() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        vm.startPrank(user);

        wallet.submitTransaction(address(token), 0, data);
    }

    function testFailsWhenExecutingNonExistentTransaction() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(1);
    }

    function testMintThroughWallet() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(token.balanceOf(address(token)), amount);
    }

    function testFailsIfMintingToZeroAddress() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(0), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(token.balanceOf(address(token)), amount);
    }

    function testFailsIfThresholdDontMeet() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(token.balanceOf(address(token)), amount);
    }

    function testFailsIfConfirmsMultipleTimesBySameAddress() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);

        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(token.balanceOf(address(token)), amount);
    }

    function testRevokeConformation() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);

        wallet.revokeConfirmation(0);

        (,,,, uint256 conformations) = wallet.getTransaction(0);

        assertEq(conformations, 0);
    }

    function testTransactionCount() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(wallet.getTransactionCount(), 1);
    }

    function testGetOwners() public view {
        address[] memory addr = wallet.getOwners();

        assertEq(addr[0], alice);
        assertEq(addr[1], bob);
        assertEq(addr[2], charlie);
    }

    function testRescueTokenThroughWallet() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(token.balanceOf(address(token)), amount);

        address rescueAddress = makeAddr("rescueAddress");
        bytes memory data2 = abi.encodeWithSelector(token.rescueTokens.selector, token, rescueAddress);

        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data2);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(1);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(1);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(1);
        assertEq(token.balanceOf(address(rescueAddress)), amount);
    }

    function testFailsRescueTokenThroughWallet() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", address(token), amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);

        assertEq(token.balanceOf(address(token)), amount);

        address rescueAddress = address(0);
        bytes memory data2 = abi.encodeWithSelector(token.rescueTokens.selector, token, rescueAddress);

        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data2);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(1);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(1);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(1);
    }

    function testBurnThroughWallet() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", user, amount);
        // 1. submit the transaction with one of the users
        vm.startPrank(alice);
        wallet.submitTransaction(address(token), 0, data);

        // 2. confirm the trasaction to cross the multisig threshold
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(bob);
        wallet.confirmTransaction(0);

        // 3. Excecute the transaction as 2/3 of multisig confimed the transaction
        wallet.executeTransaction(0);
        vm.stopPrank();

        assertEq(token.balanceOf(user), amount);

        // Now burn the tokens from the user
        uint256 amountToBurn = 1e18;
        vm.startPrank(user);
        token.burn(amountToBurn);
        assertEq(token.balanceOf(user), amount - amountToBurn);
    }
}
