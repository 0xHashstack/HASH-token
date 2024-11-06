// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {HstkToken} from "../src/HSTK.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract MockToken is HstkToken {
    constructor(address _multiSig) HstkToken(_multiSig) {}
}

contract MultiSigContractTest is Test {
    enum TransactionState {
        Pending,
        Active,
        Queued,
        Expired,
        Executed
    }

    MultiSigWallet public multiSigImplementation;
    ERC1967Proxy public multiSig;
    MultiSigWallet public wrappedMultiSig;
    MockToken public token;

    address public superAdmin = makeAddr("superAdmin");
    address public signer1 = makeAddr("signer1");
    address public signer2 = makeAddr("signer2");
    address public signer3 = makeAddr("signer3");
    address public fallbackAdmin = makeAddr("fallbackAdmin");
    address public nonSigner = makeAddr("nonSigner");

    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SignerRenounced(address indexed from, address indexed to);
    event TransactionCreated(address from, uint256 indexed txId, uint8 txType, bytes data);
    event TransactionExecuted(address executor, uint256 indexed txId);
    event TransactionCanceled_InSufficientConformation(address executor, uint256 conformation);
    event InsufficientApprovals(uint256 txId, uint256 approvals);
    event SuperAdminshipTransferred(address indexed oldSuperAdmin, address indexed newSuperAdmin);
    event SuperAdminshipHandoverRequested(address indexed pendingSuperAdmin);
    event SuperAdminshipHandoverCanceled(address indexed pendingSuperAdmin);
    event FallbackAdminshipTransferred(address indexed oldFallbackAdmin, address indexed newFallbackAdmin);
    event FallbackAdminshipHandoverRequested(address indexed pendingFallbackAdmin);
    event FallbackAdminshipHandoverCanceled(address indexed pendingFallbackAdmin);

    error SuperAdmin2Step_NoHandoverRequest();

    // event TransactionStateChanged(uint txID )

    function setUp() public {
        vm.startPrank(superAdmin);

        // Deploy contracts
        multiSigImplementation = new MultiSigWallet();

        // bytes memory multisigCalldata =
        //     abi.encodeWithSelector(MultiSigContract.initialize.selector, superAdmin, fallbackAdmin);

        multiSig = new ERC1967Proxy(address(multiSigImplementation), "");

        wrappedMultiSig = MultiSigWallet(payable(address(multiSig)));

        token = new MockToken(address(wrappedMultiSig));

        wrappedMultiSig.initialize(superAdmin, fallbackAdmin, address(token));

        vm.stopPrank();
    }

    function test_Initialization() public view {
        unchecked {
            assertEq(wrappedMultiSig.superAdmin(), superAdmin, "Super admin not matched");
            assertEq(fallbackAdmin, wrappedMultiSig.fallbackAdmin(), "Value not matched");
            assertEq(wrappedMultiSig.totalSigners(), 1, "total Signers not matched");
            assertEq(wrappedMultiSig.tokenContract(), address(token));
        }
    }

    function test_AddSigner() public {
        vm.startPrank(superAdmin);

        vm.expectEmit(true, false, false, false);
        emit SignerAdded(signer3);

        wrappedMultiSig.addSigner(signer3);
        wrappedMultiSig.addSigner(signer2);
        wrappedMultiSig.addSigner(signer1);
        unchecked {
            assertTrue(wrappedMultiSig.isSigner(signer3));
            assertTrue(!wrappedMultiSig.isSigner(nonSigner));
            assertEq(wrappedMultiSig.totalSigners(), 4);
        }

        vm.stopPrank();
    }

    // function test_InvalidSigner() public {
    //     vm.startPrank(superAdmin);

    //     vm.expectEmit(true, false, false, false);
    //     emit SignerAdded(signer3);

    //     wrappedMultiSig.addSigner(signer3);
    //     // vm.expectRevert("ACL::guardian cannot be owner");
    //     vm.expectRevert(bytes4(keccak256("ACL::guardian cannot be owner")));

    //     wrappedMultiSig.addSigner(signer3);
    //     // wrappedMultiSig.addSigners(signer1);
    //     // assertTrue(wrappedMultiSig.isSigner(signer3));
    //     // assertTrue(!wrappedMultiSig.isSigner(nonSigner));
    //     // assertEq(wrappedMultiSig.totalSigners(), 3);

    //     vm.stopPrank();
    // }

    function test_RemoveSigner() public {
        test_AddSigner();
        vm.startPrank(superAdmin);

        vm.expectEmit(true, false, false, false);
        emit SignerRemoved(signer2);

        wrappedMultiSig.removeSigner(signer2);
        unchecked {
            assertFalse(wrappedMultiSig.isSigner(signer2));
            assertEq(wrappedMultiSig.totalSigners(), 3);
        }

        vm.stopPrank();
    }

    function test_RenounceSignership() public {
        //129705  129696
        test_AddSigner();
        vm.startPrank(signer2);

        vm.expectEmit(true, true, false, false);
        emit SignerRenounced(signer2, address(3));

        wrappedMultiSig.renounceSignership(address(3));
        unchecked {
            assertTrue(wrappedMultiSig.isSigner(address(3)));
            assertTrue(!wrappedMultiSig.isSigner(signer2));
            assertEq(wrappedMultiSig.totalSigners(), 4);
        }
        vm.stopPrank();
    }

    // Signers Transaction(pause,unpause,recoverTokens,partialPause,partialUnpause,BlackList,RemoveBlackList);

    function test_CreateAndExecuteTransaction() public {
        test_AddSigner();

        bytes4 selector_ = bytes4(keccak256("updateOperationalState(uint8)"));
        bytes memory param = bytes(abi.encode(2));

        // Signer1 creates transaction
        vm.startPrank(signer1);
        uint256 txId = wrappedMultiSig.createPauseStateTransaction(2);

        // Verify transaction created
        (
            address proposer,
            bytes4 selector,
            bytes memory params,
            uint256 proposedAt,
            uint256 firstSignAt,
            uint256 approvals,
            MultiSigWallet.TransactionState state,
            bool isFallbackAdmin
        ) = wrappedMultiSig.getTransaction(txId);
        unchecked {
            assertEq(proposer, signer1);
            assertEq(selector, selector_);
            assertEq(params, param);
            assertEq(proposedAt, block.timestamp);
            assertEq(approvals, 0);
            assertEq(uint8(state), 0);
        }

        // Both signers approve
        wrappedMultiSig.approveTransaction(txId);
        vm.stopPrank();

        vm.prank(signer2);
        wrappedMultiSig.approveTransaction(txId);

        // vm.expectRevert(MultiSigWallet.UnauthorizedCall.selector);
        // vm.prank(fallbackAdmin);
        // wrappedMultiSig.approveTransaction(txId);

        vm.prank(superAdmin);
        wrappedMultiSig.approveTransaction(txId);

        (,,,,, approvals,,) = wrappedMultiSig.getTransaction(txId);

        assertEq(approvals, 3);

        // Wait for activation period
        vm.warp(block.timestamp + 24 hours + 1);

        // Execute transaction
        vm.prank(fallbackAdmin);
        wrappedMultiSig.executeTransaction(txId);

        (,,,,,, state,) = wrappedMultiSig.getTransaction(txId);

        assertEq(uint8(state), 4);

        // Verify execution
        assertEq(uint8(token.getCurrentState()), 2);

        vm.stopPrank();
    }

    function test_RevertWhen_NonSignerCreatesTransaction() public {
        vm.startPrank(nonSigner);
        vm.expectRevert(MultiSigWallet.UnauthorizedCall.selector);
        wrappedMultiSig.createPauseStateTransaction(2);
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientConfirmations() public {
        test_AddSigner();
        // Signer1 creates and approves transaction
        vm.startPrank(signer1);
        uint256 txId = wrappedMultiSig.createPauseStateTransaction(2);
        wrappedMultiSig.approveTransaction(txId);

        (,,,,, uint256 approvals,,) = wrappedMultiSig.getTransaction(txId);

        // Wait for activation period
        vm.warp(block.timestamp + 24 hours + 1);

        // Try to execute with insufficient confirmations
        // vm.expectEmit(true, true, false, false);
        // emit InsufficientApprovals(txId, approvals);
        vm.expectRevert();
        wrappedMultiSig.executeTransaction(txId);
        vm.stopPrank();
    }

    function test_RevokeConfirmation() public {
        test_AddSigner();

        // Signer1 creates and approves transaction
        vm.startPrank(signer1);
        uint256 txId = wrappedMultiSig.createPauseStateTransaction(2);
        wrappedMultiSig.approveTransaction(txId);
        (,,,,, uint256 approvals, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId);

        assertEq(approvals, 1);

        // Revoke confirmation
        wrappedMultiSig.revokeTransaction(txId);

        (,,,,, approvals,,) = wrappedMultiSig.getTransaction(txId);
        assertEq(approvals, 0);
        vm.stopPrank();
    }

    function test_RevertInvalidSelectorCallTransaction() public {
        // Setup mint function call

        address to = makeAddr("to");

        test_AddSigner();
        // Fallback superAdmin creates transaction
        // vm.startPrank(fallbackAdmin);
        vm.expectRevert(MultiSigWallet.UnauthorizedCall.selector);
        vm.startPrank(signer1);

        uint256 txId = wrappedMultiSig.createMintTransaction(to, 1000);
    }

    function test_FallbackAdminMintTransaction() public {
        // Setup mint function call
        address to = makeAddr("to");

        test_AddSigner();
        // Fallback superAdmin creates transaction
        vm.startPrank(fallbackAdmin);
        uint256 txId = wrappedMultiSig.createMintTransaction(to, 1000);

        // Approve and wait for activation period
        // wrappedMultiSig.approveTransaction(txId);
        vm.stopPrank();

        vm.prank(signer1);
        wrappedMultiSig.approveTransaction(txId);

        vm.prank(signer2);
        wrappedMultiSig.approveTransaction(txId);

        vm.prank(signer3);
        wrappedMultiSig.approveTransaction(txId);

        (,,,,, uint256 approvals, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId);
        assertEq(approvals, 3);

        vm.warp(block.timestamp + 24 hours + 3);
        vm.expectRevert();
        vm.prank(superAdmin);
        wrappedMultiSig.approveTransaction(txId);
        // Execute transaction
        vm.prank(fallbackAdmin);
        wrappedMultiSig.executeTransaction(txId);

        // Verify mint
        assertEq(token.balanceOf(to), 1000);
    }

    function test_RevertFallbackAdminBurnTransaction() public {
        test_FallbackAdminMintTransaction();

        address to = makeAddr("to");

        vm.startPrank(fallbackAdmin);
        uint256 txId = wrappedMultiSig.createBurnTransaction(to, 500);

        // Approve and wait for activation period
        vm.stopPrank();

        vm.prank(signer1);
        wrappedMultiSig.approveTransaction(txId);

        vm.warp(block.timestamp + 72 hours + 1);

        vm.prank(signer2);
        vm.expectRevert(MultiSigWallet.InvalidState.selector);
        wrappedMultiSig.approveTransaction(txId);

        vm.prank(signer1);
        vm.expectRevert(MultiSigWallet.InvalidState.selector);
        wrappedMultiSig.executeTransaction(txId);

        vm.prank(signer1);
        vm.expectRevert(MultiSigWallet.InvalidState.selector);
        wrappedMultiSig.revokeTransaction(txId);

        MultiSigWallet.TransactionState currentState = wrappedMultiSig._updateTransactionState(txId);
        (,,,,, uint256 approvals, MultiSigWallet.TransactionState currentState2,) = wrappedMultiSig.getTransaction(txId);

        assertEq(approvals, 1);
        assertEq(uint8(currentState2), uint8(TransactionState.Expired));

        // vm.expectRevert(MultiSigWallet.InvalidState.selector);
        // vm.prank(signer2);
        // wrappedMultiSig.approveTransaction(txId);
    }

    function test_fallbackAdminBurnTransaction() public {
        test_FallbackAdminMintTransaction();

        address to = makeAddr("to");

        // Fallback superAdmin creates transaction
        vm.startPrank(fallbackAdmin);
        uint256 txId = wrappedMultiSig.createBurnTransaction(to, 100);

        // Approve and wait for activation period
        // wrappedMultiSig.approveTransaction(txId);
        vm.stopPrank();

        vm.prank(signer1);
        wrappedMultiSig.approveTransaction(txId);

        vm.prank(signer2);
        wrappedMultiSig.approveTransaction(txId);

        vm.prank(signer3);
        wrappedMultiSig.approveTransaction(txId);

        (,,,,, uint256 approvals, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId);
        assertEq(approvals, 3);

        vm.warp(block.timestamp + 24 hours + 3);
        vm.expectRevert();
        vm.prank(superAdmin);
        wrappedMultiSig.approveTransaction(txId);
        // Execute transaction
        vm.prank(fallbackAdmin);
        wrappedMultiSig.executeTransaction(txId);

        // Verify mint
        assertEq(token.balanceOf(to), 900);
    }

    function test_multipleFunctionsHighGas() public {
        uint256[100] memory _transactions;
        address[100] memory signers;
        for (uint256 i = 0; i < 100; i++) {
            signers[i] = address(uint160(i + 1));
            addSigner(signers[i]);
            vm.startPrank(fallbackAdmin);
            _transactions[i] = wrappedMultiSig.createMintTransaction(signers[i], block.timestamp);
            vm.stopPrank();
        }
        for (uint256 i = 0; i < 100; i++) {
            uint256 trnx = _transactions[i];
            for (uint256 j = 0; j < 100; j++) {
                vm.prank(signers[j]);
                wrappedMultiSig.approveTransaction(trnx);
            }
            (,,,,, uint256 approvals,,) = wrappedMultiSig.getTransaction(trnx);
            assertEq(approvals, 100);
        }

        vm.warp(block.timestamp + 24 hours + 5);

        for (uint256 i = 0; i < 100; i++) {
            uint256 trnx = _transactions[i];
            //Execute transaction;
            wrappedMultiSig.executeTransaction(trnx);
            (,,,,,, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(trnx);
            assertEq(uint8(state), 4);
        }
    }

    function createBlacklistTrnx(address account) public returns (uint256) {
        vm.assume(account != address(0));
        uint256 trnx = wrappedMultiSig.createBlacklistAccountTransaction(account);
        return trnx;
    }

    function createPauseTransaction() public returns (uint256) {
        uint256 trnx = wrappedMultiSig.createPauseStateTransaction(2);
        return trnx;
    }

    function addSigner(address _signer) public {
        vm.startPrank(superAdmin);
        wrappedMultiSig.addSigner(_signer);
        vm.stopPrank();
    }

    function removeSigner(address _signer) public {
        vm.startPrank(superAdmin);
        wrappedMultiSig.removeSigner(_signer);
        vm.stopPrank();
    }

    function test_checkTransactionStateLogic(address to, uint256 amount) public {
        test_AddSigner();
        vm.assume(to != address(0) && amount > 0 && amount < 9_000_000_000 * 10 ** 18 - 10 ** 18);
        vm.prank(fallbackAdmin);
        uint256 trnx = wrappedMultiSig.createMintTransaction(to, amount);

        (,,,,,, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(trnx);
        assertEq(uint8(state), 0, "Transaction need to be in Pending State");

        // vm.warp(block.timestamp + 72 hours - 1);

        // vm.prank(signer1);
        // wrappedMultiSig.approveTransaction(trnx);
        // (,,,,,,state,) = wrappedMultiSig.getTransaction(trnx);
        // assertEq(uint8(state),1,"Transaction need to be in Active State");

        // vm.prank(signer1);
        // wrappedMultiSig.revokeTransaction(trnx);
        // (,,,,,,state,) = wrappedMultiSig.getTransaction(trnx);
        // assertEq(uint8(state),1,"Transaction need to be in Active State");

        // vm.warp(block.timestamp + 2);

        // vm.expectRevert();
        // vm.prank(signer1);
        // wrappedMultiSig.approveTransaction(trnx);
        // assertEq(uint8(state),1,"Transaction need to be in Active State");

        vm.prank(signer1);
        wrappedMultiSig.approveTransaction(trnx);
        (,,,,,, state,) = wrappedMultiSig.getTransaction(trnx);
        assertEq(uint8(state), 1, "Transaction need to be in Active State");

        vm.warp(block.timestamp + 24 hours + 1);
        vm.expectRevert();
        vm.prank(signer1);
        wrappedMultiSig.revokeTransaction(trnx);
        MultiSigWallet.TransactionState state_ = wrappedMultiSig._updateTransactionState(trnx);
        assertEq(uint8(state_), 3, "Transaction should be expired");
    }

    function test_SuperAdminTransfership(address account) public {
        address pendingOwner = makeAddr("PendingOwner");
        vm.assume(account != address(0));
        assertEq(wrappedMultiSig.superAdmin(), superAdmin);
        vm.expectEmit(true, false, false, false);
        emit SuperAdminshipHandoverRequested(pendingOwner);
        vm.prank(pendingOwner);
        wrappedMultiSig.requestSuperAdminshipHandover();

        // vm.expectEmit(true,false,false,false);
        // emit SuperAdminshipHandoverCanceled(pendingOwner);

        // vm.prank(pendingOwner);
        // wrappedMultiSig.cancelSuperAdminshipHandover();

        // vm.warp(block.timestamp + 48 hours + 1);

        // vm.expectRevert(bytes4(keccak256("SuperAdmin2Step_NoHandoverRequest()")));

        vm.expectEmit(true, true, false, false);
        emit SuperAdminshipTransferred(superAdmin, pendingOwner);

        vm.prank(superAdmin);
        wrappedMultiSig.completeSuperAdminshipHandover(pendingOwner);

        assertEq(wrappedMultiSig.superAdmin(), pendingOwner);
        assertTrue(wrappedMultiSig.isSigner(pendingOwner));
        assertFalse(wrappedMultiSig.isSigner(superAdmin));
    }

    function test_fallbackAdminTransfership(address account) public {
        address pendingOwner = makeAddr("PendingOwner");
        vm.assume(account != address(0));
        assertEq(wrappedMultiSig.fallbackAdmin(), fallbackAdmin);

        vm.expectEmit(true, false, false, false);
        emit FallbackAdminshipHandoverRequested(pendingOwner);

        vm.prank(pendingOwner);
        wrappedMultiSig.requestFallbackAdminshipHandover();

        // vm.expectEmit(true,false,false,false);
        // emit SuperAdminshipHandoverCanceled(pendingOwner);

        // vm.prank(pendingOwner);
        // wrappedMultiSig.cancelSuperAdminshipHandover();
        // assertEq(wrappedMultiSig.fallbackAdmin(),fallbackAdmin);

        // vm.warp(block.timestamp + 48 hours + 1);

        // vm.expectRevert(bytes4(keccak256("FallbackAdmin2Step_NoHandoverRequest()")));

        vm.expectEmit(true, true, false, false);
        emit FallbackAdminshipTransferred(fallbackAdmin, pendingOwner);

        vm.prank(fallbackAdmin);
        wrappedMultiSig.completeFallbackAdminshipHandover(pendingOwner);

        assertEq(wrappedMultiSig.fallbackAdmin(), pendingOwner);
    }

   
}

//for signers[] array
// current state of transaction
// revert fallback
