// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {AccessRegistry} from "./AccessRegistry/AccessRegistry.sol";
import {UUPSUpgradeable} from "./utils/UUPSUpgradeable.sol";
import {Initializable} from "./utils/Initializable.sol";

/**
 * @title MultisigWallet
 * @author Hashstack Labs
 * @notice A multi-signature wallet contract with hierarchical roles and time-bound approvals
 * @dev Implements UUPS upgradeable pattern and role-based access control
 *
 * Architectural Overview:
 * 1. Hierarchical Role System:
 *    - Super Admin: Highest authority, can execute directly
 *    - Fallback Admin: Secondary admin, can initiate mint/burn
 *    - Signers: Regular participants who approve transactions
 *
 * 2. Transaction Lifecycle:
 *    - Creation -> Approval -> Execution/Expiration
 *    - Time-bound approval windows
 *    - Threshold-based consensus
 *
 * 3. Security Features:
 *    - Two-step ownership transfers
 *    - Role-based function restrictions
 *    - Time-locked approvals
 *    - Batch operation support
 */
contract MultiSigWallet is Initializable, AccessRegistry, UUPSUpgradeable {
    // ========== CONSTANTS ==========
    
    /// @dev Time window for regular signers to approve transactions
    /// @notice After this period, transactions without sufficient approvals expire
    uint256 private constant SIGNER_WINDOW = 24 hours;
    
    /// @dev Extended time window for fallback admin proposed transactions
    /// @notice Longer window for critical mint/burn operations
    uint256 private constant FALLBACK_ADMIN_WINDOW = 72 hours;
    
    /// @dev Minimum percentage of signers required for approval
    /// @notice Set to 60% for balanced security and efficiency
    uint256 private constant APPROVAL_THRESHOLD = 60;

    /// @notice Pre-computed function selectors for permitted operations
    /// @dev Using constants instead of computing keccak256 saves gas
    ///@dev bytes4(keccak256("mint(address,uint256)"))
    bytes4 public constant MINT_SELECTOR = 0x40c10f19;
    ///@dev bytes4(keccak256("updateOperationalState(uint8)"))
    bytes4 public constant PAUSE_STATE_SELECTOR = 0x50f20190;
    ///@dev bytes4(keccak256("blackListAccount(address)"))
    bytes4 public constant BLACKLIST_ACCOUNT_SELECTOR = 0xe0644962;
    ///@dev bytes4(keccak256("removeBlackListedAccount(address)"))
    bytes4 public constant REMOVE_BLACKLIST_ACCOUNT_SELECTOR = 0xc460f1be;
    ///@dev bytes4(keccak256("recoverToken(address,address)"))
    bytes4 public constant RECOVER_TOKENS_SELECTOR = 0xfeaea586;

    /// @dev Storage slot for token contract address
    /// @notice Uses assembly-optimized storage pattern
    bytes32 public constant TOKEN_CONTRACT_SLOT = 0x2e621e7466541a75ed3060ecb302663cf45f24d90bdac97ddad9918834bc5d75;

    // ========== ENUMS ==========
    
    /// @notice Defines possible states of a transaction
    /// @dev State transitions follow a strict flow
    enum TransactionState {
        Pending,     // Just created, awaiting first signature
        Active,      // Has at least one signature, within time window
        Queued,      // Has enough signatures, ready for execution
        Expired,     // Time window passed without enough signatures
        Executed     // Successfully executed
    }

    // ========== STRUCTS ==========
    
    /// @notice Complete transaction information structure
    /// @dev Optimized for minimal storage usage while maintaining functionality
    struct Transaction {
        uint256 proposedAt;      // Timestamp when transaction was proposed
        uint256 firstSignAt;     // Timestamp of first approval
        uint256 approvals;       // Current number of approvals
        address proposer;        // Address that proposed the transaction
        bytes4 selector;         // Target function selector
        TransactionState state;  // Current transaction state
        bool isFallbackAdmin;    // Flag for fallback admin proposals
        bytes params;            // Encoded function parameters
    }

    // ========== STATE VARIABLES ==========
    
    /// @notice Primary transaction storage
    /// @dev Maps transaction ID to transaction details
    mapping(uint256 => Transaction) private transactions;
    
    /// @notice Tracks individual signer approvals
    /// @dev Double mapping for efficient approval checking
    mapping(uint256 => mapping(address => bool)) hasApproved;
    
    /// @notice Registry of valid transaction IDs
    /// @dev Used for quick existence checks
    mapping(uint256 => bool) transactionIdExists;
    
    /// @notice Function permission mappings
    /// @dev Maps function selectors to permission flags
    mapping(bytes4 => bool) fallbackAdminFunctions;
    mapping(bytes4 => bool) signerFunctions;

    // ========== EVENTS ==========
    
    /// @notice Emitted when a new transaction is proposed
    /// @param txId Unique identifier of the transaction
    /// @param proposer Address that proposed the transaction
    /// @param proposedAt Timestamp of proposal
    event TransactionProposed(uint256 indexed txId, address proposer, uint256 proposedAt);
    
    /// @notice Emitted when a transaction receives an approval
    event TransactionApproved(uint256 indexed txId, address signer);
    
    /// @notice Emitted when an approval is revoked
    event TransactionRevoked(uint256 indexed txId, address revoker);
    
    /// @notice Emitted when a transaction is successfully executed
    event TransactionExecuted(uint256 indexed txId);
    
    /// @notice Emitted when a transaction expires
    event TransactionExpired(uint256 indexed txId);
    
    /// @notice Emitted when a transaction's state changes
    event TransactionStateChanged(uint256 indexed txId, TransactionState newState);
    
    /// @notice Emitted when a transaction fails to get sufficient approvals
    event InsufficientApprovals(uint256 indexed txId, uint256 approvals);
    
    /// @notice Emitted for direct super admin transactions
    event TransactionProposedBySuperAdmin(uint256 proposedAt);

    // ========== ERRORS ==========
    
    /// @dev Custom errors for gas-efficient error handling
    error UnauthorizedCall();            // Caller lacks necessary permissions
    error InvalidToken();                // Invalid token contract address
    error InvalidState();                // Invalid transaction state for operation
    error AlreadyApproved();            // Signer has already approved
    error TransactionNotSigned();        // Transaction hasn't been signed by caller
    error WindowExpired();               // Time window for operation has passed
    error TransactionAlreadyExist();     // Transaction ID already exists
    error TransactionIdNotExist();       // Transaction ID doesn't exist
    error FunctionAlreadyExists();       // Function already registered
    error FunctionDoesNotExist();        // Function not registered
    error ZeroAmountTransaction();       // Zero amount in transaction
    error InvalidParams();               // Invalid parameters provided

    // ========== INITIALIZATION ==========
    
    /// @notice Constructor
    /// @dev Disables initialization of implementation contract
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with required addresses and permissions
     * @dev Sets up initial admin roles and configures function permissions
     * @param _superAdmin Address to be granted super admin role
     * @param _fallbackAdmin Address to be granted fallback admin role
     * @param _tokenContract Address of the token contract to be managed
     */
    function initialize(
        address _superAdmin,
        address _fallbackAdmin,
        address _tokenContract
    ) external initializer notZeroAddress(_superAdmin) notZeroAddress(_fallbackAdmin) notZeroAddress(_tokenContract) {
        // Initialize access control
        _initializeAccessRegistry(_superAdmin, _fallbackAdmin);
        
        // Configure fallback admin permissions
        fallbackAdminFunctions[MINT_SELECTOR] = true;

        // Configure signer permissions
        signerFunctions[PAUSE_STATE_SELECTOR] = true;
        signerFunctions[BLACKLIST_ACCOUNT_SELECTOR] = true;
        signerFunctions[REMOVE_BLACKLIST_ACCOUNT_SELECTOR] = true;
        signerFunctions[RECOVER_TOKENS_SELECTOR] = true;

        // Store token contract address
        assembly {
            sstore(TOKEN_CONTRACT_SLOT, _tokenContract)
        }
    }

    // ========== CORE MULTISIG LOGIC ==========

    /**
     * @notice Updates the state of a transaction based on current conditions
     * @dev Evaluates time windows and approval thresholds to determine state
     * @param txId ID of the transaction to update
     * @return Current state of the transaction
     */
    function updateTransactionState(uint256 txId) public txExist(txId) returns (TransactionState) {
        Transaction storage transaction = transactions[txId];

        // Skip if transaction is in a final state
        if (transaction.state == TransactionState.Executed || transaction.state == TransactionState.Expired) {
            return transaction.state;
        }

        uint256 currentTime = block.timestamp;
        bool isExpired;

        // Calculate expiration based on proposer type
        if (transaction.isFallbackAdmin) {
            // Fallback admin gets longer window, but first signature starts regular window
            uint256 fallbackAdminDeadline = transaction.proposedAt + FALLBACK_ADMIN_WINDOW;
            uint256 deadline = transaction.firstSignAt != 0
                ? min(fallbackAdminDeadline, transaction.firstSignAt + SIGNER_WINDOW)
                : fallbackAdminDeadline;
            isExpired = currentTime > deadline;
        } else {
            // Regular signers have standard window
            isExpired = currentTime > transaction.proposedAt + SIGNER_WINDOW;
        }

        // Determine new state
        TransactionState newState = transaction.state;
        uint256 totalSigner = totalSigners();

        if (isExpired) {
            // Check if enough approvals were received
            if ((transaction.approvals * 100) / totalSigner >= APPROVAL_THRESHOLD) {
                newState = TransactionState.Queued;
            } else {
                emit InsufficientApprovals(txId, transaction.approvals);
                newState = TransactionState.Expired;
            }
        } else if (transaction.firstSignAt != 0) {
            newState = TransactionState.Active;
        }

        // Update state if changed
        if (newState != transaction.state) {
            transaction.state = newState;
            emit TransactionStateChanged(txId, transaction.state);
        }

        return transaction.state;
    }

    /**
     * @notice Creates multiple transactions in a batch
     * @dev Super admin transactions are executed immediately
     * @param _selector Array of function selectors
     * @param _params Array of encoded function parameters
     * @return txId Array of created transaction IDs
     */
    function createBatchTransaction(
        bytes4[] calldata _selector,
        bytes[] calldata _params
    ) external returns (uint256[] memory txId) {
        uint256 size = _selector.length;
        if (size == 0 || size != _params.length) revert InvalidParams();

        address sender = _msgSender();

        // Super admin path: direct execution
        if (sender == superAdmin()) {
            for (uint256 i; i < size;) {
                _call(_selector[i], _params[i]);
                unchecked { ++i; }
            }
            emit TransactionProposedBySuperAdmin(block.timestamp);
            return new uint256[](0);
        }

        // Regular path: create pending transactions
        txId = new uint256[](size);
        uint256 timestamp = block.timestamp;
        bool isSigner = isSigner(sender);
        bool isFallbackAdmin = sender == fallbackAdmin();

        for (uint256 i; i < size;) {
            bytes4 selector = _selector[i];
            
            // Verify permissions
            bool isValidFunction = isSigner ? signerFunctions[selector] : fallbackAdminFunctions[selector];
            if (!isValidFunction || (!isSigner && !isFallbackAdmin)) {
                revert UnauthorizedCall();
            }

            // Generate unique transaction ID
            txId[i] = uint256(keccak256(abi.encode(timestamp, sender, selector, _params[i])));

            if (transactionIdExists[txId[i]]) {
                revert TransactionAlreadyExist();
            }

            // Store transaction
            transactionIdExists[txId[i]] = true;
            Transaction storage transaction = transactions[txId[i]];
            transaction.proposer = sender;
            transaction.selector = selector;
            transaction.params = _params[i];
            transaction.proposedAt = timestamp;
            transaction.isFallbackAdmin = isFallbackAdmin;

            emit TransactionProposed(txId[i], sender, timestamp);

            unchecked { ++i; }
        }
    }

/** 
@notice Approves multiple transactions in a batch
@dev Only signers can approve transactions
@param txIds Array of transaction IDs to approve
*/

function approveBatchTransaction(uint256[] calldata txIds) public {
    address sender = _msgSender();
    if (!isSigner(sender)) revert UnauthorizedCall();

        uint256 len = txIds.length;
        uint256 currentTime = block.timestamp;

        for (uint256 i; i < len;) {
            uint256 txId = txIds[i];
            if (!transactionIdExists[txId]) revert TransactionIdNotExist();
            if (hasApproved[txId][sender]) revert AlreadyApproved();

            Transaction storage transaction = transactions[txId];
            TransactionState currentState = updateTransactionState(txId);

            if (currentState != TransactionState.Pending && currentState != TransactionState.Active) {
                revert InvalidState();
            }

            // Update first signature time if this is the first approval
            if (transaction.approvals == 0) {
                transaction.firstSignAt = currentTime;
            }

            unchecked {
                transaction.approvals += 1;
                ++i;
            }

            hasApproved[txId][sender] = true;
            emit TransactionApproved(txId, sender);
            updateTransactionState(txId);
        }
    }

/*
     
@notice Revokes approvals for multiple transactions
@dev Only signers who have approved can revoke their approval
@param txIds Array of transaction IDs to revoke approval from
*/

 // /**
    //  * @notice Revokes a previously approved transaction
    //  * @param txId The transaction ID to revoke
    //  */
    function revokeBatchConfirmation(uint256[] calldata txIds) external {
        address revoker = _msgSender();
        if (!isSigner(revoker)) revert UnauthorizedCall();

        uint256 len = txIds.length;
        for (uint256 i; i < len;) {
            uint256 txId = txIds[i];
            if (!transactionIdExists[txId]) revert TransactionIdNotExist();
            if (!hasApproved[txId][revoker]) revert TransactionNotSigned();

            Transaction storage transaction = transactions[txId];
            TransactionState currentState = updateTransactionState(txId);

            if (currentState != TransactionState.Active) {
                revert InvalidState();
            }

            unchecked {
                transaction.approvals -= 1;
                ++i;
            }

            hasApproved[txId][revoker] = false;
            emit TransactionRevoked(txId, revoker);
            updateTransactionState(txId);
        }
    }

    // /**
    //  * @notice Executes a transaction if it has enough approvals
    //  * @param txId The transaction ID to execute
    //  */
    function executeBatchTransaction(uint256[] calldata txIds) external {
        uint256 len = txIds.length;
        for (uint256 i; i < len;) {
            uint256 txId = txIds[i];
            if (!transactionIdExists[txId]) revert TransactionIdNotExist();

            Transaction storage transaction = transactions[txId];
            TransactionState currentState = updateTransactionState(txId);

            if (currentState != TransactionState.Queued) {
                revert InvalidState();
            }

            transaction.state = TransactionState.Executed;
            _call(transaction.selector, transaction.params);
            emit TransactionExecuted(txId);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calls a function on the token contract
     * @param functionSelector The function selector for the call
     * @param callData The call data for the function
     */
    function _call(bytes4 functionSelector, bytes memory callData) internal {
        // solhint-disable-next-line avoid-low-level-calls
        address token = tokenContract();
        (bool success,) = token.call(abi.encodePacked(functionSelector, callData));
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
        external
        view
        txExist(txId)
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
        Transaction storage trnx = transactions[txId];
        return (
            trnx.proposer,
            trnx.selector,
            trnx.params,
            trnx.proposedAt,
            trnx.firstSignAt,
            trnx.approvals,
            trnx.state,
            trnx.isFallbackAdmin
        );
    }

    /**
     * @notice Checks if a transaction ID is valid
     * @param txId The transaction ID to check
     * @return flag True if the transaction ID is valid, false otherwise
     */

    function isValidTransaction(uint256 txId) public view returns (bool flag) {
        return transactionIdExists[txId];
    }


    /**
     * @notice Authorizes contract upgrade
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlySuperAdmin {}

    modifier txExist(uint256 txId) {
        if (!isValidTransaction(txId)) {
            revert TransactionIdNotExist();
        }
        _;
    }

    function tokenContract() public view returns (address token) {
        assembly {
            token := sload(TOKEN_CONTRACT_SLOT)
        }
    }

    /// @dev Returns the minimum of `x` and `y`.
    function min(uint256 x, uint256 y) private pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }
}







    
