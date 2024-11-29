// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import {AccessRegistry} from "./AccessRegistry/AccessRegistry.sol";
// import {UUPSUpgradeable} from "./utils/UUPSUpgradeable.sol";
// import {Initializable} from "./utils/Initializable.sol";

// /**
//  * @title MultisigWallet
//  * @notice Implements a multisig wallet with three types of actors:
//  * 1. Super Admin: Can execute any function directly
//  * 2. Fallback Admin: Can initiate mint/burn (requires signer approval)
//  * 3. Signers: Can initiate and must approve all other functions
//  */
// contract MultiSigWallet is Initializable, AccessRegistry, UUPSUpgradeable {
//     // ========== CONSTANTS ==========
//     uint256 private constant SIGNER_WINDOW = 24 hours;
//     uint256 private constant FALLBACK_ADMIN_WINDOW = 72 hours;
//     uint256 private constant APPROVAL_THRESHOLD = 60; // 60% of signers must approve

//     ///@dev bytes4(keccak256("mint(address,uint256)"))
//     bytes4 public constant MINT_SELECTOR = 0x40c10f19;

//     ///@dev bytes4(keccak256("burn(address,uint256)"))
//     bytes4 public constant BURN_SELECTOR = 0x9dc29fac;

//     ///@dev bytes4(keccak256("updateOperationalState(uint8)"))
//     bytes4 public constant PAUSE_STATE_SELECTOR = 0x50f20190;

//     ///@dev bytes4(keccak256("blackListAccount(address)"))
//     bytes4 public constant BLACKLIST_ACCOUNT_SELECTOR = 0xe0644962;

//     ///@dev bytes4(keccak256("removeBlackListedAccount(address)"))
//     bytes4 public constant REMOVE_BLACKLIST_ACCOUNT_SELECTOR = 0xc460f1be;

//     ///@dev bytes4(keccak256("recoverToken(address,address)"))
//     bytes4 public constant RECOVER_TOKENS_SELECTOR = 0xfeaea586;

//     ///@dev keccak256("HASH.token.hashstack.slot")
//     bytes32 public constant TOKEN_CONTRACT_SLOT = 0x2e621e7466541a75ed3060ecb302663cf45f24d90bdac97ddad9918834bc5d75;

//     // ========== ENUMS ==========
//     enum TransactionState {
//         Pending, // Just created, awaiting first signature
//         Active, // Has at least one signature, within time window
//         Queued, // Has enough signatures, ready for execution
//         Expired, // Time window passed without enough signatures
//         Executed // Successfully executed

//     }

//     // ========== STRUCTS ==========
//     struct Transaction {
//         uint256 proposedAt; // When the transaction was proposed
//         uint256 firstSignAt; // When the first signer approved
//         uint256 approvals; // Number of approvals received
//         address proposer;
//         bytes4 selector; // The function call data
//         TransactionState state; //state of the transaction(pending,)
//         bool isFallbackAdmin; // Whether this was proposed by fallback admin
//         bytes params;
//     }

//     // ========== STATE ==========
//     mapping(uint256 => Transaction) private transactions;
//     mapping(uint256 => mapping(address => bool)) hasApproved;
//     mapping(uint256 => bool) transactionIdExists;
//     // Function permissions
//     mapping(bytes4 => bool) fallbackAdminFunctions;
//     mapping(bytes4 => bool) signerFunctions;

//     // ========== EVENTS ==========
//     event TransactionProposed(uint256 indexed txId, address proposer, uint256 proposedAt);
//     event TransactionApproved(uint256 indexed txId, address signer);
//     event TransactionRevoked(uint256 indexed txId, address revoker);
//     event TransactionExecuted(uint256 indexed txId);
//     event TransactionExpired(uint256 indexed txId);
//     event TransactionStateChanged(uint256 indexed txId, TransactionState newState);
//     event InsufficientApprovals(uint256 indexed txId, uint256 approvals);
//     event TransactionProposedBySuperAdmin(uint256 proposedAt);

//     // ========== ERRORS ==========
//     error UnauthorizedCall();
//     error InvalidToken();
//     error InvalidState();
//     error AlreadyApproved();
//     error TransactionNotSigned();
//     error WindowExpired();
//     error TransactionAlreadyExist();
//     error TransactionIdNotExist();
//     error FunctionAlreadyExists();
//     error FunctionDoesNotExist();
//     error ZeroAmountTransaction();
//     // Helper error
//     error InvalidParams();

//     // ========== INITIALIZATION ==========
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _superAdmin, address _fallbackAdmin, address _tokenContract)
//         external
//         initializer
//         notZeroAddress(_superAdmin)
//         notZeroAddress(_fallbackAdmin)
//         notZeroAddress(_tokenContract)
//     {
//         _initializeAccessRegistry(_superAdmin, _fallbackAdmin);
//         // Set up function permissions
//         // Fallback admin can only mint and burn
//         fallbackAdminFunctions[MINT_SELECTOR] = true;
//         fallbackAdminFunctions[BURN_SELECTOR] = true;

//         // Signers can pause/unpause and manage blacklist
//         signerFunctions[PAUSE_STATE_SELECTOR] = true;
//         signerFunctions[BLACKLIST_ACCOUNT_SELECTOR] = true;
//         signerFunctions[REMOVE_BLACKLIST_ACCOUNT_SELECTOR] = true;
//         signerFunctions[RECOVER_TOKENS_SELECTOR] = true;

//         assembly {
//             sstore(TOKEN_CONTRACT_SLOT, _tokenContract)
//         }
//     }

//     // ========== CORE MULTISIG LOGIC ==========

//     /**
//      * @notice Updates the transaction state based on current conditions
//      * @param txId The transaction ID to update
//      * @return The current state of the transaction
//      */
//     function updateTransactionState(uint256 txId) public txExist(txId) returns (TransactionState) {
//         Transaction storage transaction = transactions[txId];

//         // Don't update final states
//         if (transaction.state == TransactionState.Executed || transaction.state == TransactionState.Expired) {
//             return transaction.state;
//         }

//         uint256 currentTime = block.timestamp;
//         bool isExpired;

//         // Check expiration based on transaction type
//         if (transaction.isFallbackAdmin) {
//             uint256 fallbackAdminDeadline = transaction.proposedAt + FALLBACK_ADMIN_WINDOW;
//             uint256 deadline = transaction.firstSignAt != 0
//                 ? min(fallbackAdminDeadline, transaction.firstSignAt + SIGNER_WINDOW)
//                 : fallbackAdminDeadline;
//             isExpired = currentTime > deadline;
//         } else {
//             isExpired = currentTime > transaction.proposedAt + SIGNER_WINDOW;
//         }

//         // Update state based on conditions
//         TransactionState newState = transaction.state;
//         uint256 totalSigner = totalSigners();

//         if (isExpired) {
//             if ((transaction.approvals * 100) / totalSigner >= APPROVAL_THRESHOLD) {
//                 newState = TransactionState.Queued;
//             } else {
//                 emit InsufficientApprovals(txId, transaction.approvals);
//                 newState = TransactionState.Expired;
//             }
//         } else if (transaction.firstSignAt != 0) {
//             newState = TransactionState.Active;
//         }

//         if (newState != transaction.state) {
//             transaction.state = newState;
//             emit TransactionStateChanged(txId, transaction.state);
//         }

//         return newState;
//     }

//     // Optimized batch transaction functions with gas improvements

//     function createBatchTransaction(bytes4[] calldata _selector, bytes[] calldata _params)
//         external
//         returns (uint256[] memory txId)
//     {
//         uint256 size = _selector.length;
//         if (size == 0 || size != _params.length) revert InvalidParams();

//         address sender = _msgSender();

//         // For super admin, we don't need to store or return txIds
//         if (sender == superAdmin()) {
//             for (uint256 i; i < size;) {
//                 _call(_selector[i], _params[i]);
//                 unchecked {
//                     ++i;
//                 }
//             }
//             emit TransactionProposedBySuperAdmin(block.timestamp);
//             return new uint256[](0);
//         }

//         // For other users, batch create transactions
//         txId = new uint256[](size);
//         uint256 timestamp = block.timestamp;
//         bool isSigner = isSigner(sender);
//         bool isFallbackAdmin = sender == fallbackAdmin();

//         for (uint256 i; i < size;) {
//             bytes4 selector = _selector[i];
//             // Cache permission check result
//             bool isValidFunction = isSigner ? signerFunctions[selector] : fallbackAdminFunctions[selector];
//             if (!isValidFunction || (!isSigner && !isFallbackAdmin)) {
//                 revert UnauthorizedCall();
//             }

//             // Generate txId more efficiently
//             txId[i] = uint256(keccak256(abi.encode(timestamp, sender, selector, _params[i])));

//             if (transactionIdExists[txId[i]]) {
//                 revert TransactionAlreadyExist();
//             }

//             transactionIdExists[txId[i]] = true;

//             // Store transaction with minimal storage writes
//             Transaction storage transaction = transactions[txId[i]];
//             transaction.proposer = sender;
//             transaction.selector = selector;
//             transaction.params = _params[i];
//             transaction.proposedAt = timestamp;
//             transaction.isFallbackAdmin = isFallbackAdmin;
//             // Other fields default to 0/false/Pending

//             emit TransactionProposed(txId[i], sender, timestamp);

//             unchecked {
//                 ++i;
//             }
//         }
//     }
//     /**
//      * @notice Checks if a transaction ID is valid
//      * @param txId The transaction ID to check
//      * @return flag True if the transaction ID is valid, false otherwise
//      */

//     function isValidTransaction(uint256 txId) public view returns (bool flag) {
//         return transactionIdExists[txId];
//     }

//     /**
//      * @notice Approves a transaction
//      * @param txIds The transaction ID to approve
//      */
//     function approveBatchTransaction(uint256[] calldata txIds) public {
//         address sender = _msgSender();
//         if (!isSigner(sender)) revert UnauthorizedCall();

//         uint256 len = txIds.length;
//         uint256 currentTime = block.timestamp;

//         for (uint256 i; i < len;) {
//             uint256 txId = txIds[i];
//             if (!transactionIdExists[txId]) revert TransactionIdNotExist();
//             if (hasApproved[txId][sender]) revert AlreadyApproved();

//             Transaction storage transaction = transactions[txId];
//             TransactionState currentState = updateTransactionState(txId);

//             if (currentState != TransactionState.Pending && currentState != TransactionState.Active) {
//                 revert InvalidState();
//             }

//             // Update first signature time if this is the first approval
//             if (transaction.approvals == 0) {
//                 transaction.firstSignAt = currentTime;
//             }
//             unchecked {
//                 transaction.approvals += 1;
//                 ++i;
//             }

//             hasApproved[txId][sender] = true;
//             emit TransactionApproved(txId, sender);
//             updateTransactionState(txId);
//         }
//     }

//     // /**
//     //  * @notice Revokes a previously approved transaction
//     //  * @param txId The transaction ID to revoke
//     //  */
//     function revokeBatchConfirmation(uint256[] calldata txIds) external {
//         address revoker = _msgSender();
//         if (!isSigner(revoker)) revert UnauthorizedCall();

//         uint256 len = txIds.length;
//         for (uint256 i; i < len;) {
//             uint256 txId = txIds[i];
//             if (!transactionIdExists[txId]) revert TransactionIdNotExist();
//             if (!hasApproved[txId][revoker]) revert TransactionNotSigned();

//             Transaction storage transaction = transactions[txId];
//             TransactionState currentState = updateTransactionState(txId);

//             if (currentState != TransactionState.Active) {
//                 revert InvalidState();
//             }

//             unchecked {
//                 transaction.approvals -= 1;
//                 ++i;
//             }

//             hasApproved[txId][revoker] = false;
//             emit TransactionRevoked(txId, revoker);
//             updateTransactionState(txId);
//         }
//     }

//     // /**
//     //  * @notice Executes a transaction if it has enough approvals
//     //  * @param txId The transaction ID to execute
//     //  */
//     function executeBatchTransaction(uint256[] calldata txIds) external {
//         uint256 len = txIds.length;
//         for (uint256 i; i < len;) {
//             uint256 txId = txIds[i];
//             if (!transactionIdExists[txId]) revert TransactionIdNotExist();

//             Transaction storage transaction = transactions[txId];
//             TransactionState currentState = updateTransactionState(txId);

//             if (currentState != TransactionState.Queued) {
//                 revert InvalidState();
//             }

//             transaction.state = TransactionState.Executed;
//             _call(transaction.selector, transaction.params);
//             emit TransactionExecuted(txId);

//             unchecked {
//                 ++i;
//             }
//         }
//     }

//     /**
//      * @notice Calls a function on the token contract
//      * @param functionSelector The function selector for the call
//      * @param callData The call data for the function
//      */
//     function _call(bytes4 functionSelector, bytes memory callData) internal {
//         // solhint-disable-next-line avoid-low-level-calls
//         address token = tokenContract();
//         (bool success,) = token.call(abi.encodePacked(functionSelector, callData));
//         if (!success) {
//             // If the call failed, we revert with the propagated error message.
//             // solhint-disable-next-line no-inline-assembly
//             assembly {
//                 let returnDataSize := returndatasize()
//                 returndatacopy(0, 0, returnDataSize)
//                 revert(0, returnDataSize)
//             }
//         }
//     }

//     // ========== VIEW FUNCTIONS ==========

//     function getTransaction(uint256 txId)
//         external
//         view
//         txExist(txId)
//         returns (
//             address proposer,
//             bytes4 selector,
//             bytes memory params,
//             uint256 proposedAt,
//             uint256 firstSignAt,
//             uint256 approvals,
//             TransactionState state,
//             bool isFallbackAdmin
//         )
//     {
//         Transaction storage trnx = transactions[txId];
//         return (
//             trnx.proposer,
//             trnx.selector,
//             trnx.params,
//             trnx.proposedAt,
//             trnx.firstSignAt,
//             trnx.approvals,
//             trnx.state,
//             trnx.isFallbackAdmin
//         );
//     }

//     /**
//      * @notice Authorizes contract upgrade
//      * @param newImplementation The address of the new implementation
//      */
//     function _authorizeUpgrade(address newImplementation) internal override onlySuperAdmin {}

//     modifier txExist(uint256 txId) {
//         if (!isValidTransaction(txId)) {
//             revert TransactionIdNotExist();
//         }
//         _;
//     }

//     function tokenContract() public view returns (address token) {
//         assembly {
//             token := sload(TOKEN_CONTRACT_SLOT)
//         }
//     }

//     /// @dev Returns the minimum of `x` and `y`.
//     function min(uint256 x, uint256 y) private pure returns (uint256 z) {
//         /// @solidity memory-safe-assembly
//         assembly {
//             z := xor(x, mul(xor(x, y), lt(y, x)))
//         }
//     }
// }








// pragma solidity ^0.8.4;

// import {AccessRegistry} from "./AccessRegistry/AccessRegistry.sol";
// import {UUPSUpgradeable} from "./utils/UUPSUpgradeable.sol";
// import {Initializable} from "./utils/Initializable.sol";

// /**
//  * @title MultisigWallet
//  * @author Hashstack Labs
//  * @notice A multi-signature wallet contract with hierarchical roles and time-bound approvals
//  * @dev Implements UUPS upgradeable pattern and role-based access control
//  *
//  * Key features:
//  * 1. Three-tier role system:
//  *    - Super Admin: Can execute any function directly
//  *    - Fallback Admin: Can propose mint/burn operations (requires signer approval)
//  *    - Signers: Can propose and must approve all other functions
//  * 2. Time-bound approval windows
//  * 3. Threshold-based approval system
//  * 4. Batch transaction support
//  */
// contract MultiSigWallet is Initializable, AccessRegistry, UUPSUpgradeable {
//     // ========== CONSTANTS ==========
    
//     /// @dev Time window for signers to approve a transaction
//     uint256 private constant SIGNER_WINDOW = 24 hours;
    
//     /// @dev Extended time window for fallback admin proposed transactions
//     uint256 private constant FALLBACK_ADMIN_WINDOW = 72 hours;
    
//     /// @dev Percentage of signers required for approval (60%)
//     uint256 private constant APPROVAL_THRESHOLD = 60;

//     // Function selectors for permitted operations
//     ///@dev Function selectors are precomputed for gas efficiency
//     bytes4 public constant MINT_SELECTOR = 0x40c10f19;
//     bytes4 public constant BURN_SELECTOR = 0x9dc29fac;
//     bytes4 public constant PAUSE_STATE_SELECTOR = 0x50f20190;
//     bytes4 public constant BLACKLIST_ACCOUNT_SELECTOR = 0xe0644962;
//     bytes4 public constant REMOVE_BLACKLIST_ACCOUNT_SELECTOR = 0xc460f1be;
//     bytes4 public constant RECOVER_TOKENS_SELECTOR = 0xfeaea586;

//     /// @dev Storage slot for token contract address using assembly optimization
//     bytes32 public constant TOKEN_CONTRACT_SLOT = 0x2e621e7466541a75ed3060ecb302663cf45f24d90bdac97ddad9918834bc5d75;

//     // ========== ENUMS ==========
    
//     /// @notice Represents the current state of a transaction
//     /// @dev State transitions: Pending -> Active -> Queued -> Executed or Expired
//     enum TransactionState {
//         Pending,     // Initial state, awaiting first signature
//         Active,      // Has at least one signature, within time window
//         Queued,      // Has enough signatures, ready for execution
//         Expired,     // Time window passed without enough signatures
//         Executed     // Successfully executed
//     }

//     // ========== STRUCTS ==========
    
//     /// @notice Structure containing all transaction details
//     /// @dev Optimized for minimal storage usage
//     struct Transaction {
//         uint256 proposedAt;      // Timestamp of proposal
//         uint256 firstSignAt;     // Timestamp of first approval
//         uint256 approvals;       // Number of current approvals
//         address proposer;        // Address that proposed the transaction
//         bytes4 selector;         // Function selector to be called
//         TransactionState state;  // Current state of transaction
//         bool isFallbackAdmin;    // Whether proposed by fallback admin
//         bytes params;            // Function parameters
//     }

//     // ========== STATE VARIABLES ==========
    
//     /// @dev Stores all transaction details
//     mapping(uint256 => Transaction) private transactions;
    
//     /// @dev Tracks which signers have approved which transactions
//     mapping(uint256 => mapping(address => bool)) hasApproved;
    
//     /// @dev Validates existence of transaction IDs
//     mapping(uint256 => bool) transactionIdExists;
    
//     /// @dev Maps function selectors to permission levels
//     mapping(bytes4 => bool) fallbackAdminFunctions;
//     mapping(bytes4 => bool) signerFunctions;

//     // ========== EVENTS ==========
    
//     /// @dev Emitted when various transaction states change
//     event TransactionProposed(uint256 indexed txId, address proposer, uint256 proposedAt);
//     event TransactionApproved(uint256 indexed txId, address signer);
//     event TransactionRevoked(uint256 indexed txId, address revoker);
//     event TransactionExecuted(uint256 indexed txId);
//     event TransactionExpired(uint256 indexed txId);
//     event TransactionStateChanged(uint256 indexed txId, TransactionState newState);
//     event InsufficientApprovals(uint256 indexed txId, uint256 approvals);
//     event TransactionProposedBySuperAdmin(uint256 proposedAt);

//     // ========== ERRORS ==========
    
//     /// @dev Custom errors for better gas efficiency and clearer error messages
//     error UnauthorizedCall();
//     error InvalidToken();
//     error InvalidState();
//     error AlreadyApproved();
//     error TransactionNotSigned();
//     error WindowExpired();
//     error TransactionAlreadyExist();
//     error TransactionIdNotExist();
//     error FunctionAlreadyExists();
//     error FunctionDoesNotExist();
//     error ZeroAmountTransaction();
//     error InvalidParams();

//     // ========== INITIALIZATION ==========
    
//     /// @dev Prevents initialization of implementation contract
//     constructor() {
//         _disableInitializers();
//     }

//     /**
//      * @notice Initializes the contract with key addresses and permissions
//      * @dev Sets up initial roles and function permissions
//      * @param _superAdmin Address of the super admin
//      * @param _fallbackAdmin Address of the fallback admin
//      * @param _tokenContract Address of the token contract to manage
//      */
//     function initialize(
//         address _superAdmin,
//         address _fallbackAdmin,
//         address _tokenContract
//     ) external initializer notZeroAddress(_superAdmin) notZeroAddress(_fallbackAdmin) notZeroAddress(_tokenContract) {
//         _initializeAccessRegistry(_superAdmin, _fallbackAdmin);
        
//         // Configure function permissions
//         fallbackAdminFunctions[MINT_SELECTOR] = true;
//         fallbackAdminFunctions[BURN_SELECTOR] = true;

//         signerFunctions[PAUSE_STATE_SELECTOR] = true;
//         signerFunctions[BLACKLIST_ACCOUNT_SELECTOR] = true;
//         signerFunctions[REMOVE_BLACKLIST_ACCOUNT_SELECTOR] = true;
//         signerFunctions[RECOVER_TOKENS_SELECTOR] = true;

//         assembly {
//             sstore(TOKEN_CONTRACT_SLOT, _tokenContract)
//         }
//     }
