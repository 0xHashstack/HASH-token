// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, StdInvariant} from "forge-std/Test.sol";
import {HstkToken} from "../src/HSTK.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract MockToken is HstkToken {
    constructor(address _multiSig) HstkToken(_multiSig) {}
}

contract MultiSigContractTest is StdInvariant, Test {
    enum TransactionState {
        Pending,
        Active,
        Queued,
        Expired,
        Executed
    }

    bytes4[] selectors;
    bytes[] params;
    address[] signers;
    uint256[] txId;

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

    ///@dev bytes4(keccak256("mint(address,uint256)"))
    bytes4 public constant MINT_SELECTOR = 0x40c10f19;

    ///@dev bytes4(keccak256("burn(address,uint256)"))
    bytes4 public constant BURN_SELECTOR = 0x9dc29fac;

    ///@dev bytes4(keccak256("updateOperationalState(uint8)"))
    bytes4 public constant PAUSE_STATE_SELECTOR = 0x50f20190;

    ///@dev bytes4(keccak256("blackListAccount(address)"))
    bytes4 public constant BLACKLIST_ACCOUNT_SELECTOR = 0xe0644962;

    ///@dev bytes4(keccak256("removeBlackListedAccount(address)"))
    bytes4 public constant REMOVE_BLACKLIST_ACCOUNT_SELECTOR = 0xc460f1be;

    ///@dev bytes4(keccak256("recoverToken(address,address)"))
    bytes4 public constant RECOVER_TOKENS_SELECTOR = 0xfeaea586;

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
        targetContract(address(wrappedMultiSig));
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
        uint256 gasBefore = gasleft();
        wrappedMultiSig.addSigner(signer3);
        wrappedMultiSig.addSigner(signer2);
        wrappedMultiSig.addSigner(signer1);
        uint256 gasAfter = gasleft();

        console.log("gas used Add signer: ", gasBefore - gasAfter);
        vm.stopPrank();
    }

    function test_AddSignerBatch() public {
        vm.startPrank(superAdmin);
        vm.expectEmit(true, false, false, false);
        emit SignerAdded(signer3);
        signers = [signer3, signer1, signer2];
        uint256 gasBefore = gasleft();
        wrappedMultiSig.addBatchSigners(signers);
        uint256 gasAfter = gasleft();
        console.log("gas used Add signer batch: ", gasBefore - gasAfter);
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

        selectors = [PAUSE_STATE_SELECTOR];
        params = [abi.encode(2)];

        // Signer1 creates transaction
        vm.startPrank(signer1);
        txId = wrappedMultiSig.createBatchTransaction(selectors, params);

        // Verify transaction created
        (
            address proposer,
            bytes4 selector,
            bytes memory _params,
            uint256 proposedAt,
            uint256 firstSignAt,
            uint256 approvals,
            MultiSigWallet.TransactionState state,
            bool isFallbackAdmin
        ) = wrappedMultiSig.getTransaction(txId[0]);
        unchecked {
            assertEq(proposer, signer1);
            assertEq(selector, PAUSE_STATE_SELECTOR);
            assertEq(_params, params[0]);
            assertEq(proposedAt, block.timestamp);
            assertEq(approvals, 0);
            assertEq(uint8(state), 0);
        }

        // Both signers approve
        wrappedMultiSig.approveBatchTransaction(txId);
        vm.stopPrank();

        vm.prank(signer2);
        wrappedMultiSig.approveBatchTransaction(txId);

        // vm.expectRevert(MultiSigWallet.UnauthorizedCall.selector);
        // vm.prank(fallbackAdmin);

        vm.prank(superAdmin);
        wrappedMultiSig.approveBatchTransaction(txId);

        (,,,,, approvals,,) = wrappedMultiSig.getTransaction(txId[0]);

        assertEq(approvals, 3);

        // Wait for activation period
        vm.warp(block.timestamp + 24 hours + 1);

        // Execute transaction
        vm.prank(fallbackAdmin);
        wrappedMultiSig.executeBatchTransaction(txId);

        (,,,,,, state,) = wrappedMultiSig.getTransaction(txId[0]);

        assertEq(uint8(state), 4);

        // Verify execution
        assertEq(uint8(token.getCurrentState()), 2);

        vm.stopPrank();
    }

    function test_RevertWhen_NonSignerCreatesTransaction() public {
        selectors = [PAUSE_STATE_SELECTOR];
        params = [abi.encode(2)];
        vm.startPrank(nonSigner);
        vm.expectRevert(MultiSigWallet.UnauthorizedCall.selector);
        wrappedMultiSig.createBatchTransaction(selectors, params);
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientConfirmations() public {
        test_AddSigner();
        // Signer1 creates and approves transaction
        selectors = [PAUSE_STATE_SELECTOR];
        params = [abi.encode(2)];
        vm.startPrank(signer1);
        txId = wrappedMultiSig.createBatchTransaction(selectors, params);
        wrappedMultiSig.approveBatchTransaction(txId);

        (,,,,, uint256 approvals,,) = wrappedMultiSig.getTransaction(txId[0]);

        // Wait for activation period
        vm.warp(block.timestamp + 24 hours + 1);

        // Try to execute with insufficient confirmations
        // vm.expectEmit(true, true, false, false);
        // emit InsufficientApprovals(txId, approvals);
        vm.expectRevert();
        wrappedMultiSig.executeBatchTransaction(txId);
        vm.stopPrank();
    }

    function test_RevokeConfirmation() public {
        test_AddSigner();

        // Signer1 creates and approves transaction
        selectors = [PAUSE_STATE_SELECTOR];
        params = [abi.encode(2)];
        vm.startPrank(signer1);
        txId = wrappedMultiSig.createBatchTransaction(selectors, params);
        wrappedMultiSig.approveBatchTransaction(txId);
        (,,,,, uint256 approvals, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId[0]);

        assertEq(approvals, 1);

        // Revoke confirmation
        wrappedMultiSig.revokeBatchConfirmation(txId);

        (,,,,, approvals,,) = wrappedMultiSig.getTransaction(txId[0]);
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

        selectors = [MINT_SELECTOR];
        params = [abi.encode(to, 1000)];

        txId = wrappedMultiSig.createBatchTransaction(selectors, params);
    }

    function test_FallbackAdminMintTransaction() public {
        // Setup mint function call
        // vm.assume(to!=address(0));
        address to = makeAddr("to");

        test_AddSigner();
        // Fallback superAdmin creates transaction
        vm.startPrank(fallbackAdmin);
        selectors = [MINT_SELECTOR];
        params = [abi.encode(to, 1000 * 10 ** 18)];

        txId = wrappedMultiSig.createBatchTransaction(selectors, params);

        // Approve and wait for activation period
        vm.stopPrank();

        vm.prank(signer1);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(signer2);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(signer3);
        wrappedMultiSig.approveBatchTransaction(txId);

        (,,,,, uint256 approvals, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId[0]);
        assertEq(approvals, 3);

        vm.warp(block.timestamp + 24 hours + 3);
        vm.expectRevert();
        vm.prank(superAdmin);
        wrappedMultiSig.approveBatchTransaction(txId);
        // Execute transaction
        vm.prank(fallbackAdmin);
        wrappedMultiSig.executeBatchTransaction(txId);

        // Verify mint
        assertEq(token.balanceOf(to), 1000 * 10 ** 18);
    }

    function test_RevertFallbackAdminBurnTransaction() public {
        test_FallbackAdminMintTransaction();

        address to = makeAddr("to");

        vm.prank(to);
        token.burn(500 * 10 ** 18);

        assertEq(token.balanceOf(to), 500 * 10 ** 18, "Incorrect amount");
    }

    // function test_fallbackAdminBurnTransaction() public {
    //     test_FallbackAdminMintTransaction();

    //     address to = makeAddr("to");

    //     // Fallback superAdmin creates transaction

    //     selectors = [BURN_SELECTOR];
    //     params = [abi.encode(to, 500 * 10 ** 18)];
    //     vm.startPrank(fallbackAdmin);
    //     txId = wrappedMultiSig.createBatchTransaction(selectors, params);

    //     // Approve and wait for activation period
    //     vm.stopPrank();

    //     vm.prank(signer1);
    //     wrappedMultiSig.approveBatchTransaction(txId);

    //     vm.prank(signer2);
    //     wrappedMultiSig.approveBatchTransaction(txId);

    //     vm.prank(signer3);
    //     wrappedMultiSig.approveBatchTransaction(txId);

    //     (,,,,, uint256 approvals, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId[0]);
    //     assertEq(approvals, 3);

    //     vm.warp(block.timestamp + 24 hours + 3);
    //     vm.expectRevert();
    //     vm.prank(superAdmin);
    //     wrappedMultiSig.approveBatchTransaction(txId);
    //     // Execute transaction
    //     vm.prank(fallbackAdmin);
    //     wrappedMultiSig.executeBatchTransaction(txId);

    //     // Verify mint
    //     assertEq(token.balanceOf(to), 500 * 10 ** 18);
    // }

    // function test_multipleFunctionsHighGas() public {
    //     uint256[100] memory _transactions;
    //     address[100] memory signers;
    //     for (uint256 i = 0; i < 100; i++) {
    //         signers[i] = address(uint160(i + 1));
    //         addSigner(signers[i]);
    //         vm.startPrank(fallbackAdmin);
    //         _transactions[i] = wrappedMultiSig.createMintTransaction(signers[i], block.timestamp);
    //         vm.stopPrank();
    //     }
    //     for (uint256 i = 0; i < 100; i++) {
    //         uint256 trnx = _transactions[i];
    //         for (uint256 j = 0; j < 100; j++) {
    //             vm.prank(signers[j]);
    //             wrappedMultiSig.approveTransaction(trnx);
    //         }
    //         (,,,,, uint256 approvals,,) = wrappedMultiSig.getTransaction(trnx);
    //         assertEq(approvals, 100);
    //     }

    //     vm.warp(block.timestamp + 24 hours + 5);

    //     for (uint256 i = 0; i < 100; i++) {
    //         uint256 trnx = _transactions[i];
    //         //Execute transaction;
    //         wrappedMultiSig.executeTransaction(trnx);
    //         (,,,,,, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(trnx);
    //         assertEq(uint8(state), 4);
    //     }
    // }

    function createBlacklistTrnx(address account) public returns (uint256[] memory trnx) {
        vm.assume(account != address(0));
        selectors = [BLACKLIST_ACCOUNT_SELECTOR];
        params = [abi.encode(account)];
        trnx = wrappedMultiSig.createBatchTransaction(selectors, params);
        return trnx;
    }

    // function createPauseTransaction() public returns (uint256) {
    //     uint256 trnx = wrappedMultiSig.createPauseStateTransaction(2);
    //     return trnx;
    // }

    // function addSigner(address _signer) public {
    //     vm.startPrank(superAdmin);
    //     wrappedMultiSig.addSigner(_signer);
    //     vm.stopPrank();
    // }

    // function removeSigner(address _signer) public {
    //     vm.startPrank(superAdmin);
    //     wrappedMultiSig.removeSigner(_signer);
    //     vm.stopPrank();
    // }

    function test_checkTransactionStateLogic(address to, uint256 amount) public {
        test_AddSigner();
        vm.assume(to != address(0) && amount > 0 && amount < 9_000_000_000 * 10 ** 18 - 10 ** 18);

        selectors = [MINT_SELECTOR];
        params = [abi.encode(to, amount)];
        vm.prank(fallbackAdmin);
        txId = wrappedMultiSig.createBatchTransaction(selectors, params);

        (,,,,,, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId[0]);
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
        wrappedMultiSig.approveBatchTransaction(txId);
        state = wrappedMultiSig.updateTransactionState(txId[0]);
        assertEq(uint8(state), 1, "Transaction need to be in Active State");

        vm.warp(block.timestamp + 24 hours + 1);
        vm.expectRevert();
        vm.prank(signer1);
        wrappedMultiSig.revokeBatchConfirmation(txId);
        MultiSigWallet.TransactionState state_ = wrappedMultiSig.updateTransactionState(txId[0]);
        assertEq(uint8(state_), 3, "Transaction should be expired");
    }

    // function test_SuperAdminTransfership(address account) public {
    //     address pendingOwner = makeAddr("PendingOwner");
    //     vm.assume(account != address(0));
    //     assertEq(wrappedMultiSig.superAdmin(), superAdmin);
    //     vm.expectEmit(true, false, false, false);
    //     emit SuperAdminshipHandoverRequested(pendingOwner);
    //     vm.prank(pendingOwner);
    //     wrappedMultiSig.requestFallbackAdminTransfer();

    //     // vm.expectEmit(true,false,false,false);
    //     // emit SuperAdminshipHandoverCanceled(pendingOwner);

    //     // vm.prank(pendingOwner);
    //     // wrappedMultiSig.cancelSuperAdminshipHandover();

    //     // vm.warp(block.timestamp + 48 hours + 1);

    //     // vm.expectRevert(bytes4(keccak256("SuperAdmin2Step_NoHandoverRequest()")));

    //     vm.expectEmit(true, true, false, false);
    //     emit SuperAdminshipTransferred(superAdmin, pendingOwner);

    //     vm.prank(superAdmin);
    //     wrappedMultiSig.completeSuperAdminshipHandover(pendingOwner);

    //     assertEq(wrappedMultiSig.superAdmin(), pendingOwner);
    //     assertTrue(wrappedMultiSig.isSigner(pendingOwner));
    //     assertFalse(wrappedMultiSig.isSigner(superAdmin));
    // }

    // function test_fallbackAdminTransfership(address account) public {
    //     address pendingOwner = makeAddr("PendingOwner");
    //     vm.assume(account != address(0));
    //     assertEq(wrappedMultiSig.fallbackAdmin(), fallbackAdmin);

    //     vm.expectEmit(true, false, false, false);
    //     emit FallbackAdminshipHandoverRequested(pendingOwner);

    //     vm.prank(pendingOwner);
    //     wrappedMultiSig.requestFallbackAdminHandover();

    //     // vm.expectEmit(true,false,false,false);
    //     // emit SuperAdminshipHandoverCanceled(pendingOwner);

    //     // vm.prank(pendingOwner);
    //     // wrappedMultiSig.cancelSuperAdminshipHandover();
    //     // assertEq(wrappedMultiSig.fallbackAdmin(),fallbackAdmin);

    //     // vm.warp(block.timestamp + 48 hours + 1);

    //     // vm.expectRevert(bytes4(keccak256("FallbackAdmin2Step_NoHandoverRequest()")));

    //     vm.expectEmit(true, true, false, false);
    //     emit FallbackAdminshipTransferred(fallbackAdmin, pendingOwner);

    //     vm.prank(fallbackAdmin);
    //     wrappedMultiSig.completeFallbackAdminshipHandover(pendingOwner);

    //     assertEq(wrappedMultiSig.fallbackAdmin(), pendingOwner);
    // }

    function test_TransactionCancellationDueToLackOfApprovals() public {
        test_AddSigner();
        vm.startPrank(signer1);
        uint256[] memory txId = createPauseTransaction();

        // Approve partially
        wrappedMultiSig.approveBatchTransaction(txId);
        vm.stopPrank();

        // Advance time beyond expiration
        vm.warp(block.timestamp + 48 hours + 1);

        // Attempt to execute and expect failure due to insufficient approvals
        vm.startPrank(fallbackAdmin);
        vm.expectRevert();
        wrappedMultiSig.executeBatchTransaction(txId);
    }

    function test_InitializeOnlyOnce() public {
        vm.startPrank(superAdmin);

        // Attempt to initialize again should revert
        vm.expectRevert();
        wrappedMultiSig.initialize(superAdmin, fallbackAdmin, address(token));

        vm.stopPrank();
    }

    function test_NonAdminCannotInitialize() public {
        vm.prank(nonSigner);
        vm.expectRevert();
        wrappedMultiSig.initialize(superAdmin, fallbackAdmin, address(token));
    }

    function test_AddExistingSigner() public {
        vm.startPrank(superAdmin);
        wrappedMultiSig.addSigner(signer1);

        // Adding the same signer again should revert
        vm.expectRevert();
        wrappedMultiSig.addSigner(signer1);

        vm.stopPrank();
    }

    function test_RemoveNonExistentSigner() public {
        vm.startPrank(superAdmin);

        // Attempting to remove a non-signer should revert
        vm.expectRevert();
        wrappedMultiSig.removeSigner(nonSigner);

        vm.stopPrank();
    }

    function test_AddSigner_NotSuperAdmin() public {
        vm.startPrank(signer1); // signer1 is not the superAdmin
        vm.expectRevert();
        wrappedMultiSig.addSigner(signer2);
        vm.stopPrank();
    }

    function test_RemoveSigner_NotSuperAdmin() public {
        test_AddSigner();
        vm.startPrank(signer1); // signer1 is not the superAdmin
        vm.expectRevert();
        wrappedMultiSig.removeSigner(signer2);
        vm.stopPrank();
    }

    function test_RenounceSignership_Effectiveness() public {
        test_AddSigner();
        vm.startPrank(signer2);
        wrappedMultiSig.renounceSignership(address(1)); // Renounce without replacement

        // Attempt approval after renouncing (should fail)
        vm.expectRevert();
        uint256[] memory txIds = new uint256[](1);
        txIds[0] = 1;
        wrappedMultiSig.approveBatchTransaction(txIds);
        vm.stopPrank();
    }

    function test_AddDuplicateSigner() public {
        vm.startPrank(superAdmin);
        wrappedMultiSig.addSigner(signer1);
        vm.expectRevert();
        wrappedMultiSig.addSigner(signer1);
        vm.stopPrank();
    }

    function test_ApprovalByNonSigner() public {
        test_AddSigner();
        vm.startPrank(address(0xDEADBEEF)); // A non-signer
        vm.expectRevert();
        uint256[] memory txIds = new uint256[](1);
        txIds[0] = 1;
        wrappedMultiSig.approveBatchTransaction(txIds);
        vm.stopPrank();
    }

    function test_ExecuteTransaction_InsufficientApprovals() public {
        test_AddSigner();
        vm.startPrank(signer1);
        uint256[] memory txId = createPauseTransaction();
        vm.expectRevert();
        wrappedMultiSig.executeBatchTransaction(txId);
        vm.stopPrank();
    }

    function test_TransactionExpiration() public {
        test_AddSigner();
        vm.startPrank(signer1);
        uint256[] memory txId = createPauseTransaction();
        wrappedMultiSig.approveBatchTransaction(txId);
        vm.warp(block.timestamp + 7 days + 1); // Fast-forward past expiration
        wrappedMultiSig.updateTransactionState(txId[0]);
        (,,,,,, MultiSigWallet.TransactionState state,) = wrappedMultiSig.getTransaction(txId[0]);
        assertEq(uint8(state), uint8(MultiSigWallet.TransactionState.Expired));
        vm.stopPrank();
    }

    function test_createBlackListTransaction() public {
        // vm.assume(account!=address(0));
        address account = makeAddr("account");
        address to = makeAddr("to");
        test_FallbackAdminMintTransaction();

        selectors = [BLACKLIST_ACCOUNT_SELECTOR];
        params = [abi.encode(account)];
        vm.prank(signer1);
        txId = wrappedMultiSig.createBatchTransaction(selectors, params);

        vm.prank(signer1);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(signer2);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(signer3);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(superAdmin);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(address(3));
        vm.warp(block.timestamp + 24 hours + 1);
        wrappedMultiSig.executeBatchTransaction(txId);

        assertEq(token.isBlackListed(account), true, "Inconsistent State");

        vm.expectRevert();
        vm.prank(to);
        token.transfer(account, 10 * 10 ** 18);
    }

    function test_removeBlackListTransaction() public {
        test_createBlackListTransaction();

        address account = makeAddr("account");
        address to = makeAddr("to");

        selectors = [REMOVE_BLACKLIST_ACCOUNT_SELECTOR];
        params = [abi.encode(account)];

        vm.prank(signer1);
        txId = wrappedMultiSig.createBatchTransaction(selectors, params);

        vm.prank(signer1);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(signer2);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(signer3);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(superAdmin);
        wrappedMultiSig.approveBatchTransaction(txId);

        vm.prank(address(3));
        vm.warp(block.timestamp + 24 hours + 1);
        wrappedMultiSig.executeBatchTransaction(txId);

        assertEq(token.isBlackListed(account), false, "Inconsistent State");

        vm.prank(to);
        token.transfer(account, 10 * 10 ** 18);
        assertEq(token.balanceOf(account), 10 * 10 ** 18, "Token Doesn't mint successfully");
    }

    function test_CreateTransactionBatch() public {
        address to = address(1223);
        //(gas: 4 28 625)
        selectors = [MINT_SELECTOR, MINT_SELECTOR];
        // selectors = [MINT_SELECTOR];

        params = [abi.encode(to, 10_000), abi.encode(to, 100_000)];

        uint256 gasBefore = gasleft();
        vm.prank(superAdmin);
        wrappedMultiSig.createBatchTransaction(selectors, params);

        uint256 gasAfter = gasleft();

        console.log("Gas used", gasBefore - gasAfter);
    }

    function createPauseTransaction() public returns (uint256[] memory) {
        selectors = [PAUSE_STATE_SELECTOR];
        params = [abi.encode(2)];
        uint256[] memory trnx = wrappedMultiSig.createBatchTransaction(selectors, params);
        return trnx;
    }

    // function test_CreateTransaction() public {
    //     address to = address(1223);

    //     // (gas: 3 99 118)
    //     //188159
    //     //1029953

    //     uint256 gasBefore = gasleft();
    //     vm.prank(superAdmin);
    //     wrappedMultiSig.createMintTransaction(to, 10_000);
    //     uint256 gasAfter = gasleft();

    //     console.log("gas USed : ", gasBefore - gasAfter);
    // }

    // function test_approveTransaction() public {
    // }
}

//for signers[] array
// current state of transaction
// revert fallback
