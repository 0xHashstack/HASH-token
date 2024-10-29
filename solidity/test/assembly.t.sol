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
    error CallerZeroAddress();

    enum TransactionState {
        Pending,
        Active,
        Queued,
        Expired,
        Executed
    }

    // struct Transaction {
    //     address from;
    //     bytes4 functionSelector;
    //     bytes parameters; // Store encoded parameters as bytes
    //     uint256 noOfConformation;
    //     TransactionStatus status;
    //     uint256 activationTimeForSigners;
    //     uint256 activationtimeForFallbackAdmin;
    //     uint8 txType; // 1 for signers, 2 for fallback superAdmin
    // }

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

    // function test_checkModifier() public {

    //     wrappedMultiSig.addSigner(owner1);
    //     wrappedMultiSig.checkModifier(address(0));
    // }
}
