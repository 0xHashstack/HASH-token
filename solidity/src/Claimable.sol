// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.4;

import {SafeMath} from "./utils/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Optimized Claimable Contract
 * @dev Smart contract allowing recipients to claim ERC20 tokens with vesting schedule
 */
contract Claimable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public currentId;
    IERC20 public token;

    // Constants
    uint256 private constant SECONDS_PER_DAY = 86400;

    struct Ticket {
        address beneficiary;
        address pendingClaimer;
        uint32 cliff; // Optimized to uint32 - max ~136 years
        uint32 vesting; // Optimized to uint32
        uint96 amount; // Optimized to uint96 - max ~79 octillion (assuming 18 decimals)
        uint96 claimed; // Optimized to uint96
        uint96 balance; // Optimized to uint96
        uint32 createdAt; // Optimized to uint32
        uint32 lastClaimedAt; // Optimized to uint32
        uint32 numClaims; // Optimized to uint32
        bool irrevocable;
        bool isRevoked;
    }

    mapping(address => uint256[]) public beneficiaryTickets;
    mapping(uint256 => Ticket) private tickets;

    event TicketCreated(uint256 indexed id, uint256 amount, bool irrevocable);
    event Claimed(uint256 indexed id, uint256 amount, address claimer);
    event ClaimDelegated(uint256 indexed id, uint256 amount, address pendingClaimer);
    event Revoked(uint256 indexed id, uint256 amount);

    error ZeroAddress();
    error UnauthorizedAccess();
    error InvalidBeneficiary();
    error InvalidAmount();
    error InvalidVestingPeriod();
    error TicketRevoked();
    error NothingToClaim();
    error TransferFailed();
    error IrrevocableTicket();
    error InvalidParams();

    modifier canView(uint256 _id) {
        if (tickets[_id].beneficiary != msg.sender) revert UnauthorizedAccess();
        _;
    }

    modifier notRevoked(uint256 _id) {
        if (tickets[_id].isRevoked) revert TicketRevoked();
        _;
    }

    function initialize(address _token) public initializer {
        if (_token == address(0)) revert ZeroAddress();
        __Ownable_init(msg.sender);
        token = IERC20(_token);
    }

    function create(address _beneficiary, uint256 _cliff, uint256 _vesting, uint256 _amount, bool _irrevocable)
        public
        returns (uint256 ticketId)
    {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_amount == 0) revert InvalidAmount();
        if (_vesting < _cliff) revert InvalidVestingPeriod();

        ticketId = ++currentId;
        Ticket storage ticket = tickets[ticketId];

        ticket.beneficiary = _beneficiary;
        ticket.cliff = uint32(_cliff);
        ticket.vesting = uint32(_vesting);
        ticket.amount = uint96(_amount);
        ticket.balance = uint96(_amount);
        ticket.createdAt = uint32(block.timestamp);
        ticket.irrevocable = _irrevocable;

        beneficiaryTickets[_beneficiary].push(ticketId);

        emit TicketCreated(ticketId, _amount, _irrevocable);

        // Transfer tokens from creator to contract
        if (!token.transferFrom(msg.sender, address(this), _amount)) revert TransferFailed();
    }

    /// @notice allow batch create tickets with the same terms same amount
    function batchCreateSameAmount(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256 _amount,
        bool _irrevocable
    ) public {
        /// @dev set maximum array length?
        require(_beneficiaries.length > 0, "At least one beneficiary is required");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            create(_beneficiaries[i], _cliff, _vesting, _amount, _irrevocable);
        }
    }

    /// @notice allow batch create tickets with the same terms different amount
    function batchCreate(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256[] memory _amounts,
        bool _irrevocable
    ) public {
        /// @dev set maximum array length?
        require(_beneficiaries.length > 0, "At least one beneficiary is required");
        require(_beneficiaries.length == _amounts.length, "Number of beneficiaries should match the number of amounts.");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_amounts[i] > 0) {
                create(_beneficiaries[i], _cliff, _vesting, _amounts[i], _irrevocable);
            }
        }
    }

    function delegateClaim(uint256 _id, address _pendingClaimer) public notRevoked(_id) returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (_pendingClaimer == address(0)) revert InvalidParams();
        if (ticket.beneficiary != msg.sender) revert UnauthorizedAccess();
        if (ticket.balance == 0) revert NothingToClaim();
        uint256 claimableAmount = available(_id);
        if (claimableAmount == 0) revert NothingToClaim();
        ticket.claimed += uint96(claimableAmount);
        ticket.balance -= uint96(claimableAmount);
        ticket.lastClaimedAt = uint32(block.timestamp);
        ticket.numClaims++;

        if (_pendingClaimer == msg.sender) {
            emit Claimed(_id, claimableAmount, msg.sender);
            token.transfer(msg.sender, claimableAmount);
        } else {
            ticket.pendingClaimer = _pendingClaimer;
            emit ClaimDelegated(_id, claimableAmount, _pendingClaimer);
        }
        return true;
    }

    function acceptClaim(uint256 _ticketId) public returns (bool) {
        Ticket storage ticket = tickets[_id];
    }

    function revoke(uint256 _id) public notRevoked(_id) returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (msg.sender != owner()) revert UnauthorizedAccess();
        if (ticket.irrevocable) revert IrrevocableTicket();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 remainingBalance = ticket.balance;
        if (!token.transfer(owner(), remainingBalance)) revert TransferFailed();

        ticket.isRevoked = true;
        ticket.balance = 0;

        emit Revoked(_id, remainingBalance);
        return true;
    }

    function hasCliffed(uint256 _id) public view canView(_id) returns (bool) {
        Ticket memory ticket = tickets[_id];
        if (ticket.cliff == 0) return true;
        return block.timestamp > ticket.createdAt + (ticket.cliff * SECONDS_PER_DAY);
    }

    function unlocked(uint256 _id) public view canView(_id) returns (uint256) {
        Ticket memory ticket = tickets[_id];
        uint256 timeLapsed = block.timestamp - ticket.createdAt;
        uint256 vestingInSeconds = ticket.vesting * SECONDS_PER_DAY;
        return (timeLapsed * ticket.amount) / vestingInSeconds;
    }

    function available(uint256 _id) public view canView(_id) notRevoked(_id) returns (uint256) {
        Ticket memory ticket = tickets[_id];
        if (ticket.balance == 0) return 0;
        if (!hasCliffed(_id)) return 0;

        uint256 unlockedAmount = unlocked(_id);
        return unlockedAmount > ticket.claimed ? unlockedAmount - ticket.claimed : 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function viewTicket(uint256 _id) public view canView(_id) returns (Ticket memory) {
        return tickets[_id];
    }

    function myBeneficiaryTickets() public view returns (uint256[] memory) {
        return beneficiaryTickets[msg.sender];
    }
}
