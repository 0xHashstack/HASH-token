// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "./utils/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Claimable Token Vesting Contract
 * @notice A flexible token vesting contract that supports multiple vesting schedules
 * @dev Implements upgradeable, ownable, and reentrancy-protected token vesting
 *
 * Key Features:
 * - Support for multiple ticket types (Investors, Community Partners, Airdrops, etc.)
 * - Configurable cliff and vesting periods
 * - Partial claims with TGE (Token Generation Event) percentage
 * - Batch ticket creation
 * - Revocable tickets
 * - Upgradeable contract architecture
 */
contract NewClaimable is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard {
    using SafeMath for uint256;

    // Global ticket counter to generate unique ticket IDs
    uint256 public currentId;

    // ERC20 token contract for vesting
    IERC20 public token;

    // Constant for converting days to seconds in vesting calculations
    uint256 private constant SECONDS_PER_DAY = 86400;

    // Denominator for percentage calculations (100%)
    uint256 private constant PERCENTAGE_DENOMINATOR = 100;

    /**
     * @notice Enumeration of possible ticket types
     * @dev Allows categorization of token allocations
     */
    enum TicketType {
        Investors,
        CommunityPartners,
        Airdrop1,
        ContentCreators,
        Others
    }

    /**
     * @notice Detailed structure representing a token vesting ticket
     * @dev Stores all relevant information for a single vesting allocation
     */
    struct Ticket {
        uint256 cliff; // Cliff period in days before vesting starts
        uint256 vesting; // Total vesting period in days
        uint256 createdAt; // Timestamp when ticket was created
        uint256 lastClaimedAt; // Timestamp of last claim
        uint256 amount; // Total allocated amount
        uint256 claimed; // Amount already claimed
        uint256 balance; // Remaining claimable balance
        uint256 tgePercentage; // Percentage released at Token Generation Event
        address beneficiary; // Address entitled to claim tokens
        bool isRevoked; // Flag to indicate if ticket is revoked
        TicketType ticketType; // Type of ticket/allocation
    }

    // Mapping to track tickets owned by each beneficiary
    mapping(address => uint256[]) public beneficiaryTickets;

    // Internal mapping to store ticket details by ID
    mapping(uint256 => Ticket) private tickets;

    // Events to log key contract actions
    event TicketCreated(uint256 indexed id, uint256 amount, uint256 tgePercentage, uint8 ticketType);
    event Claimed(uint256 indexed id, uint256 amount, address claimer);
    event ClaimDelegated(uint256 indexed id, uint256 amount, address pendingClaimer);
    event Revoked(uint256 indexed id, uint256 amount);

    // Custom error definitions for more gas-efficient error handling
    error ZeroAddress();
    error UnauthorizedAccess();
    error InvalidBeneficiary();
    error InvalidAmount();
    error InvalidVestingPeriod();
    error InvalidTGEPercentage();
    error NothingToClaim();
    error TransferFailed();
    error InvalidParams();
    error TicketRevoked();
    error InvalidTicketType();

    /**
     * @notice Modifier to prevent operations on revoked tickets
     * @param _id Ticket ID to check
     */
    modifier notRevoked(uint256 _id) {
        if (tickets[_id].isRevoked) revert TicketRevoked();
        _;
    }

    /**
     * @notice Contract initializer (replaces constructor for upgradeable contracts)
     * @param _token Address of the ERC20 token to be vested
     * @param _owner Initial owner of the contract
     */
    function initialize(address _token, address _owner) public initializer {
        if (_token == address(0)) revert ZeroAddress();
        __Ownable_init(_owner);
        token = IERC20(_token);
    }

    /**
     * @notice Create a single vesting ticket
     * @dev Only callable by contract owner
     * @param _beneficiary Address to receive tokens
     * @param _cliff Number of days before vesting starts
     * @param _vesting Total vesting period in days
     * @param _amount Total amount of tokens to vest
     * @param _tgePercentage Percentage released at Token Generation Event
     * @param _ticketType Type of ticket/allocation
     * @return ticketId Unique identifier for the created ticket
     */
    function create(
        address _beneficiary,
        uint256 _cliff,
        uint256 _vesting,
        uint256 _amount,
        uint256 _tgePercentage,
        uint8 _ticketType
    ) public onlyOwner returns (uint256 ticketId) {
        // Validate input parameters
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_amount == 0) revert InvalidAmount();
        if (_vesting < _cliff) revert InvalidVestingPeriod();
        if (_tgePercentage > PERCENTAGE_DENOMINATOR) {
            revert InvalidTGEPercentage();
        }
        if (_ticketType > 4) revert InvalidTicketType();

        // Generate new ticket ID
        ticketId = ++currentId;
        Ticket storage ticket = tickets[ticketId];

        // Populate ticket details
        ticket.beneficiary = _beneficiary;
        ticket.cliff = _cliff;
        ticket.vesting = _vesting;
        ticket.amount = _amount;
        ticket.balance = _amount;
        ticket.createdAt = block.timestamp;
        ticket.tgePercentage = _tgePercentage;
        ticket.ticketType = TicketType(_ticketType);

        // Track tickets for each beneficiary
        beneficiaryTickets[_beneficiary].push(ticketId);

        emit TicketCreated(ticketId, _amount, _tgePercentage, _ticketType);
    }

    /**
     * @notice Create multiple tickets with identical terms
     * @param _beneficiaries Array of addresses to receive tokens
     * @param _cliff Number of days before vesting starts
     * @param _vesting Total vesting period in days
     * @param _amount Total amount of tokens to vest for each ticket
     * @param _tgePercentage Percentage released at Token Generation Event
     * @param _ticketType Type of ticket/allocation
     */
    function batchCreateSameAmount(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256 _amount,
        uint256 _tgePercentage,
        uint8 _ticketType
    ) public {
        // Ensure at least one beneficiary is provided
        require(_beneficiaries.length > 0, "At least one beneficiary is required");

        // Create tickets for each beneficiary
        for (uint256 i = 0; i < _beneficiaries.length;) {
            create(_beneficiaries[i], _cliff, _vesting, _amount, _tgePercentage, _ticketType);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Create multiple tickets with varying amounts
     * @param _beneficiaries Array of addresses to receive tokens
     * @param _cliff Number of days before vesting starts
     * @param _vesting Total vesting period in days
     * @param _amounts Array of token amounts for each ticket
     * @param _tgePercentage Percentage released at Token Generation Event
     * @param _ticketType Type of ticket/allocation
     */
    function batchCreate(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256[] memory _amounts,
        uint256 _tgePercentage,
        uint8 _ticketType
    ) public {
        // Validate input parameters
        if (_beneficiaries.length != _amounts.length) revert InvalidParams();
        if (_beneficiaries.length == 0) revert InvalidParams();

        // Create tickets for each beneficiary with corresponding amount
        for (uint256 i = 0; i < _beneficiaries.length;) {
            create(_beneficiaries[i], _cliff, _vesting, _amounts[i], _tgePercentage, _ticketType);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Check if a ticket has passed its cliff period
     * @param _id Ticket ID to check
     * @return Boolean indicating if cliff period has passed
     */
    function hasCliffed(uint256 _id) public view returns (bool) {
        Ticket memory ticket = tickets[_id];
        if (ticket.cliff == 0) return true;
        return block.timestamp >= ticket.createdAt.add(ticket.cliff.mul(SECONDS_PER_DAY));
    }

    /**
     * @notice Calculate total unlocked tokens for a ticket
     * @param _id Ticket ID to check
     * @return Amount of tokens that can be unlocked
     */
    function unlocked(uint256 _id) public view returns (uint256) {
        Ticket memory ticket = tickets[_id];

        // Calculate TGE amount - released immediately
        uint256 tgeAmount = ticket.amount.mul(ticket.tgePercentage).div(PERCENTAGE_DENOMINATOR);

        // If cliff hasn't passed, only TGE amount is available
        if (!hasCliffed(_id)) return tgeAmount;

        // Calculate remaining amount that will vest linearly
        uint256 remainingAmount = ticket.amount.sub(tgeAmount);

        // Calculate cliff timestamp
        uint256 cliffTime = ticket.createdAt.add(ticket.cliff.mul(SECONDS_PER_DAY));

        // Calculate total vesting duration (from cliff end to vesting end)
        uint256 vestingDuration = (ticket.vesting).mul(SECONDS_PER_DAY);

        // Calculate time elapsed since cliff
        uint256 timeSinceCliff = block.timestamp.sub(cliffTime);

        // If vesting period complete, return full amount
        if (timeSinceCliff >= vestingDuration) {
            return ticket.amount;
        }

        // Calculate linear vesting for remaining amount
        uint256 vestedAmount = remainingAmount.mul(timeSinceCliff).div(vestingDuration);

        return tgeAmount.add(vestedAmount);
    }

    /**
     * @notice Calculate currently available tokens for claim
     * @param _id Ticket ID to check
     * @return Amount of tokens available for immediate claim
     */
    function available(uint256 _id) public view returns (uint256) {
        Ticket memory ticket = tickets[_id];
        if (ticket.balance == 0) return 0;

        uint256 unlockedAmount = unlocked(_id);
        return unlockedAmount > ticket.claimed ? unlockedAmount.sub(ticket.claimed) : 0;
    }

    /**
     * @notice Claim tokens for a specific ticket
     * @param _id Ticket ID to claim
     * @param _recipient Address to receive tokens
     * @return Boolean indicating successful claim
     */
    function claimTicket(uint256 _id, address _recipient) public notRevoked(_id) nonReentrant returns (bool) {
        Ticket storage ticket = tickets[_id];

        // Validate claim conditions
        if (_recipient == address(0)) revert InvalidParams();
        if (ticket.beneficiary != msg.sender) revert UnauthorizedAccess();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 claimableAmount = available(_id);
        if (claimableAmount == 0) revert NothingToClaim();

        // Process the claim
        _processClaim(_id, claimableAmount, _recipient);
        return true;
    }

    /**
     * @notice Internal method to process token claims
     * @param _id Ticket ID
     * @param _amount Amount to claim
     * @param _claimer Address receiving tokens
     */
    function _processClaim(uint256 _id, uint256 _amount, address _claimer) private {
        Ticket storage ticket = tickets[_id];

        // Update ticket claim details
        ticket.claimed = ticket.claimed.add(_amount);
        ticket.balance = ticket.balance.sub(_amount);
        ticket.lastClaimedAt = block.timestamp;

        // Emit claim event and transfer tokens
        emit Claimed(_id, _amount, _claimer);
        if (!token.transfer(_claimer, _amount)) revert TransferFailed();
    }

    function claimAllTokens(address _beneficiary) external nonReentrant  {
        uint256[] memory _ticketIds = myBeneficiaryTickets(msg.sender);
        uint _ticketsLength = _ticketIds.length;
        bool flag = _ticketIds.length != 0;
        if (!flag) revert NothingToClaim();
        for (uint256 i = 0; i < _ticketsLength;) {
            uint _available = available(_ticketIds[i]);
            Ticket memory _ticket = tickets[_ticketIds[i]];
            if (_available != 0 && !_ticket.isRevoked) {
                _processClaim(_ticketIds[i], _available, _beneficiary);
                flag = true;
            }
            unchecked {
                i++;
            }
        }
        if (!flag) {
            revert NothingToClaim();
        }
    }

    /**
     * @notice Revoke a ticket, reclaiming unclaimed tokens
     * @param _id Ticket ID to revoke
     */
    function revoke(uint256 _id) public notRevoked(_id) onlyOwner {
        Ticket storage ticket = tickets[_id];

        // Validate revocation conditions
        if (ticket.isRevoked) revert TicketRevoked();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 remainingBalance = ticket.balance;
        ticket.isRevoked = true;
        ticket.balance = 0;

        emit Revoked(_id, remainingBalance);
    }

    /**
     * @notice Authorization method for contract upgrades
     * @dev Only owner can authorize contract implementation upgrades
     * @param newImplementation Address of new contract implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice View full details of a specific ticket
     * @param _id Ticket ID to retrieve
     * @return Ticket struct with all ticket details
     */
    function viewTicket(uint256 _id) public view returns (Ticket memory) {
        return tickets[_id];
    }

    /**
     * @notice Retrieve all ticket IDs for a specific beneficiary
     * @param _beneficiary Address to check tickets for
     * @return Array of ticket IDs
     */
    function myBeneficiaryTickets(address _beneficiary) public view returns (uint256[] memory) {
        return beneficiaryTickets[_beneficiary];
    }

    /**
     * @notice Transfer tokens from contract (only by owner)
     * @param _to Recipient address
     * @param _amount Amount of tokens to transfer
     */
    function transferToken(address _to, uint256 _amount) external onlyOwner {
        if (!token.transfer(_to, _amount)) revert TransferFailed();
    }

    function renounceOwnership() public virtual override onlyOwner {}
}
