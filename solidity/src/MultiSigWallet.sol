// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessRegistry} from "./utils/AccessRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title MultisigWallet
 * @notice Implements a multisig wallet with three types of actors:
 * 1. Super Admin: Can execute any function directly
 * 2. Fallback Admin: Can initiate mint/burn (requires signer approval)
 * 3. Signers: Can initiate and must approve all other functions
 */
contract MultiSigWallet is Initializable, AccessRegistry, UUPSUpgradeable {
    // ========== CONSTANTS ==========
    uint256 private constant SIGNER_WINDOW = 24 hours;
    uint256 private constant FALLBACK_ADMIN_WINDOW = 72 hours;
    uint256 private constant APPROVAL_THRESHOLD = 60; // 60% of signers must approve

    bytes4 private constant MINT_SELECTOR = bytes4(keccak256("mint(address,uint256)"));
    bytes4 private constant BURN_SELECTOR = bytes4(keccak256("burn(address,uint256)"));
    bytes4 private constant PAUSE_SELECTOR = bytes4(keccak256("pause()"));
    bytes4 private constant UNPAUSE_SELECTOR = bytes4(keccak256("unpause()"));
    bytes4 private constant BLACKLIST_ACCOUNT_SELECTOR = bytes4(keccak256("blacklistAccount(address)"));
    bytes4 private constant REMOVE_BLACKLIST_ACCOUNT_SELECTOR = bytes4(keccak256("removeBlacklistedAccount(address)"));
    bytes4 private constant RECOVER_TOKENS_SELECTOR = bytes4(keccak256("recoverTokens(address,uint256)"));

    // ========== ENUMS ==========
    enum TransactionState {
        Pending, // Just created, awaiting first signature
        Active, // Has at least one signature, within time window
        Queued, // Has enough signatures, ready for execution
        Expired, // Time window passed without enough signatures
        Executed // Successfully executed

    }

    // ========== STRUCTS ==========
    struct Transaction {
        address proposer;
        bytes4 selector; // The function call data
        bytes params;
        uint256 proposedAt; // When the transaction was proposed
        uint256 firstSignAt; // When the first signer approved
        uint256 approvals; // Number of approvals received
        TransactionState state;
        bool isFallbackAdmin; // Whether this was proposed by fallback admin
    }

    // ========== STATE ==========
    address public tokenContract;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public hasApproved;
    mapping(uint256 => bool) private transactionIdExists;
    // Function permissions
    mapping(bytes4 => bool) public fallbackAdminFunctions;
    mapping(bytes4 => bool) public signerFunctions;

    // ========== EVENTS ==========
    event TransactionProposed(uint256 indexed txId, address proposer, uint256 proposedAt);
    event TransactionApproved(uint256 indexed txId, address signer);
    event TransactionRevoked(uint256 indexed txId, address revoker);
    event TransactionExecuted(uint256 indexed txId);
    event TransactionExpired(uint256 indexed txId);
    event TransactionStateChanged(uint256 indexed txId, TransactionState newState);
    event InsufficientApprovals(uint256 indexed txId,uint256 approvals);

    // ========== ERRORS ==========
    error UnauthorizedCall();
    error InvalidToken();
    error InvalidState();
    error AlreadyApproved();
    error TransactionNotSigned();
    error WindowExpired();
    error TransactionAlreadyExist();
    error TransactionIdNotExist();

    // ========== INITIALIZATION ==========
    constructor() {
        _disableInitializers();
    }

    function initialize(address _superAdmin, address _fallbackAdmin, address _tokenContract) external initializer 
        notZeroAddress(_superAdmin) notZeroAddress(_fallbackAdmin) notZeroAddress(_tokenContract){

        init(_superAdmin, _fallbackAdmin);
        tokenContract = _tokenContract;

        // Set up function permissions
        // Fallback admin can only mint and burn
        fallbackAdminFunctions[MINT_SELECTOR] = true;
        fallbackAdminFunctions[BURN_SELECTOR] = true;

        // Signers can pause/unpause and manage blacklist
        signerFunctions[PAUSE_SELECTOR] = true;
        signerFunctions[UNPAUSE_SELECTOR] = true;
        signerFunctions[BLACKLIST_ACCOUNT_SELECTOR] = true;
        signerFunctions[REMOVE_BLACKLIST_ACCOUNT_SELECTOR] = true;
        signerFunctions[RECOVER_TOKENS_SELECTOR] = true;
    }

    // ========== CORE MULTISIG LOGIC ==========

    /**
     * @notice Updates the transaction state based on current conditions
     * @param txId The transaction ID to update
     * @return The current state of the transaction
     */
    function _updateTransactionState(uint256 txId) public txExist(txId) returns (TransactionState) {
        Transaction storage transaction = transactions[txId];

        // Don't update final states
        if (transaction.state == TransactionState.Executed || transaction.state == TransactionState.Expired) {
            return transaction.state;
        }

        uint256 currentTime = block.timestamp;
        bool isExpired;

        // Check expiration based on transaction type
        if (transaction.isFallbackAdmin) {
            isExpired = currentTime > transaction.proposedAt + FALLBACK_ADMIN_WINDOW;
        } else if (transaction.firstSignAt != 0) {
            isExpired = currentTime > transaction.firstSignAt + SIGNER_WINDOW;
        }

        // Update state based on conditions
        TransactionState newState = transaction.state;

        if (isExpired && ((transaction.approvals * 100) / totalSigner >= APPROVAL_THRESHOLD)) {
            newState = TransactionState.Queued;
        }else if(isExpired){
            emit InsufficientApprovals(txId,transaction.approvals);
            newState = TransactionState.Expired;
        }else if (transaction.approvals == 0) {
            newState = TransactionState.Pending;
        } else if ((transaction.approvals * 100) / totalSigner >= APPROVAL_THRESHOLD) {
            newState = TransactionState.Queued;
        } else if (transaction.firstSignAt != 0) {
            newState = TransactionState.Active;
        }

        if (newState != transaction.state) {
            transaction.state = newState;
            emit TransactionStateChanged(txId, transaction.state);
        }

        return newState;
    }

    function _createStandardTransaction(bytes4 _selector, bytes memory _params) private returns (uint256) {
        if (_msgSender() == superAdmin) {
            _call(_selector, _params);
            return block.timestamp;
        }
        return createTransaction(_selector, _params);
    }

    // Helper functions now use the standard pattern
    function createMintTransaction(address to, uint256 amount) external notZeroAddress(to) virtual returns (uint256) {
        return _createStandardTransaction(MINT_SELECTOR, abi.encode(to, amount));
    }

    function createBurnTransaction(address from, uint256 amount) external notZeroAddress(from) virtual returns (uint256) {
        return _createStandardTransaction(BURN_SELECTOR, abi.encode(from, amount));
    }

    function createBlacklistAccountTransaction(address account) external notZeroAddress(account) virtual returns (uint256) {
        return _createStandardTransaction(BLACKLIST_ACCOUNT_SELECTOR, abi.encode(account));
    }

    function createBlacklistRemoveTransaction(address account) external notZeroAddress(account) virtual returns (uint256) {
        return _createStandardTransaction(REMOVE_BLACKLIST_ACCOUNT_SELECTOR, abi.encode(account));
    }

    function createPauseTransaction() external virtual returns (uint256) {
        return _createStandardTransaction(PAUSE_SELECTOR, "");
    }

    function createUnpauseTransaction() external virtual returns (uint256) {
        return _createStandardTransaction(UNPAUSE_SELECTOR, "");
    }

    function createRecoverTokensTransaction(address token, address to) external notZeroAddress(token) notZeroAddress(to) virtual returns (uint256) {
        return _createStandardTransaction(RECOVER_TOKENS_SELECTOR, abi.encode(token, to));
    }

    function isValidTransaction(uint256 txId) public view returns (bool) {
        return transactionIdExists[txId];
    }

    /**
     * @notice Proposes a new transaction
     * @param _selector The function call data to execute
     * @param _params Parameters needs to passed with functional call
     */
    function createTransaction(bytes4 _selector, bytes memory _params) internal returns (uint256 txId) {
        bool isSigner = isSigner(_msgSender());
        bool isFallbackAdmin = _msgSender() == fallbackAdmin;
        bool isValidFunction = isSigner ? signerFunctions[_selector] : fallbackAdminFunctions[_selector];

        if (!isValidFunction || (!isSigner && !isFallbackAdmin)) {
            revert UnauthorizedCall();
        }

        txId = uint256(keccak256(abi.encode(block.timestamp, _msgSender(), _selector, _params)));

        if (isValidTransaction(txId)) {
            revert TransactionAlreadyExist();
        }

        transactionIdExists[txId] = true;

        transactions[txId] = Transaction({
            proposer: _msgSender(),
            selector: _selector,
            params: _params,
            proposedAt: block.timestamp,
            firstSignAt: 0,
            approvals: 0,
            state: TransactionState.Pending,
            isFallbackAdmin: isFallbackAdmin
        });

        emit TransactionProposed(txId, _msgSender(), block.timestamp);

        return txId;
    }

    /**
     * @notice Approves a transaction
     * @param txId The transaction ID to approve
     */
    function approveTransaction(uint256 txId) external virtual txExist(txId) {
        if (!isSigner(_msgSender())) revert UnauthorizedCall();
        if (hasApproved[txId][_msgSender()]) revert AlreadyApproved();

        Transaction storage transaction = transactions[txId];
        TransactionState currentState = _updateTransactionState(txId);

        if (currentState != TransactionState.Pending && currentState != TransactionState.Active) {
            revert InvalidState();
        }

        // Update first signature time if this is the first approval
        if (transaction.approvals == 0) {
            transaction.firstSignAt = block.timestamp;
        }
        unchecked {
            transaction.approvals += 1;
        }
        hasApproved[txId][_msgSender()] = true;

        emit TransactionApproved(txId, _msgSender());
        _updateTransactionState(txId);
    }

    function revokeTransaction(uint256 txId) external virtual txExist(txId) {
        if (!isSigner(_msgSender())) revert UnauthorizedCall();
        if (!hasApproved[txId][_msgSender()]) revert TransactionNotSigned();

        Transaction storage transaction = transactions[txId];
        TransactionState currentState = _updateTransactionState(txId);

        if (currentState != TransactionState.Active) {
            revert InvalidState();
        }
        unchecked {
            transaction.approvals -= 1;
        }
        hasApproved[txId][_msgSender()] = false;

        emit TransactionRevoked(txId, _msgSender());

        _updateTransactionState(txId);
    }

    /**
     * @notice Executes a transaction if it has enough approvals
     * @param txId The transaction ID to execute
     */
    function executeTransaction(uint256 txId) external virtual txExist(txId) {
        Transaction storage transaction = transactions[txId];
        TransactionState currentState = _updateTransactionState(txId);

        if (currentState != TransactionState.Queued) {
            revert InvalidState();
        }
        transaction.state = TransactionState.Executed;

        _call(transaction.selector, transaction.params);

        emit TransactionExecuted(txId);
    }

    function _call(bytes4 functionSelector, bytes memory callData) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = tokenContract.call(abi.encodePacked(functionSelector, callData));
        if (!success) {
            // If the call failed, we revert with the propagated error message.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returnDataSize := returndatasize()
                returndatacopy(0, 0, returnDataSize)
                revert(0, returnDataSize)
            }
        }
    }

    // ========== VIEW FUNCTIONS ==========

    function getTransaction(uint256 txId)
        external txExist(txId)
        view
        returns (
            address proposer,
            bytes4 selector,
            bytes memory params,
            uint256 proposedAt,
            uint256 firstSignAt,
            uint256 approvals,
            TransactionState state,
            bool isFallbackAdmin
        )
    {
        Transaction storage tx = transactions[txId];
        return (
            tx.proposer,
            tx.selector,
            tx.params,
            tx.proposedAt,
            tx.firstSignAt,
            tx.approvals,
            tx.state,
            tx.isFallbackAdmin
        );
    }

    function _authorizeUpgrade(address) internal override onlySuperAdmin {}

    modifier txExist(uint256 txId) {
        if (!isValidTransaction(txId)) {
            revert TransactionIdNotExist();
        }
        _;
    }
}
