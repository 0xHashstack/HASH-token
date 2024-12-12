// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "./utils/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Claimable is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public currentId;
    IERC20 public token;
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant PERCENTAGE_DENOMINATOR = 100;

    enum TicketType {
        Investors,
        CommunityPartners,
        Airdrop1,
        ContentCreators,
        Others
    }

    struct Ticket {
        uint256 cliff;
        uint256 vesting;
        uint256 createdAt;
        uint256 lastClaimedAt;
        uint256 amount;
        uint256 claimed;
        uint256 balance;
        uint256 tgePercentage;
        address beneficiary;
        bool isRevoked;
        TicketType ticketType;
    }

    mapping(address => uint256[]) public beneficiaryTickets;
    mapping(uint256 => Ticket) private tickets;

    event TicketCreated(uint256 indexed id, uint256 amount, uint256 tgePercentage, uint8 ticketType);
    event Claimed(uint256 indexed id, uint256 amount, address claimer);
    event ClaimDelegated(uint256 indexed id, uint256 amount, address pendingClaimer);
    event Revoked(uint256 indexed id, uint256 amount);

    error ZeroAddress();
    error UnauthorizedAccess();
    error InvalidBeneficiary();
    error InvalidAmount();
    error InvalidVestingPeriod();
    error InvalidTGEPercentage();
    error NothingToClaim();
    error TransferFailed();
    error InvalidParams();
    error NoPendingClaim();
    error TicketRevoked();
    error InvalidTicketType();

    modifier notRevoked(uint256 _id) {
        if (tickets[_id].isRevoked) revert TicketRevoked();
        _;
    }

    function initialize(address _token, address _owner) public initializer {
        if (_token == address(0)) revert ZeroAddress();
        __Ownable_init(_owner);
        token = IERC20(_token);
    }

    function create(
        address _beneficiary,
        uint256 _cliff,
        uint256 _vesting,
        uint256 _amount,
        uint256 _tgePercentage,
        uint8 _ticketType
    ) public onlyOwner returns (uint256 ticketId) {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_amount == 0) revert InvalidAmount();
        if (_vesting < _cliff) revert InvalidVestingPeriod();
        if (_tgePercentage > PERCENTAGE_DENOMINATOR) {
            revert InvalidTGEPercentage();
        }
        if (_ticketType > 4) revert InvalidTicketType();

        ticketId = ++currentId;
        Ticket storage ticket = tickets[ticketId];

        ticket.beneficiary = _beneficiary;
        ticket.cliff = _cliff;
        ticket.vesting = _vesting;
        ticket.amount = _amount;
        ticket.balance = _amount;
        ticket.createdAt = block.timestamp;
        ticket.tgePercentage = _tgePercentage;
        ticket.ticketType = TicketType(_ticketType);

        beneficiaryTickets[_beneficiary].push(ticketId);

        emit TicketCreated(ticketId, _amount, _tgePercentage, _ticketType);
    }

    /// @notice allow batch create tickets with the same terms same amount
    function batchCreateSameAmount(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256 _amount,
        uint256 _tgePercentage,
        uint8 _ticketType
    ) public {
        /// @dev set maximum array length?
        require(_beneficiaries.length > 0, "At least one beneficiary is required");
        for (uint256 i = 0; i < _beneficiaries.length;) {
            create(_beneficiaries[i], _cliff, _vesting, _amount, _tgePercentage, _ticketType);
            unchecked {
                ++i;
            }
        }
    }

    function batchCreate(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256[] memory _amounts,
        uint256 _tgePercentage,
        uint8 _ticketType
    ) public {
        if (_beneficiaries.length != _amounts.length) revert InvalidParams();
        if (_beneficiaries.length == 0) revert InvalidParams();

        for (uint256 i = 0; i < _beneficiaries.length;) {
            create(_beneficiaries[i], _cliff, _vesting, _amounts[i], _tgePercentage, _ticketType);
            unchecked {
                ++i;
            }
        }
    }

    function hasCliffed(uint256 _id) public view returns (bool) {
        Ticket memory ticket = tickets[_id];
        if (ticket.cliff == 0) return true;
        return block.timestamp >= ticket.createdAt.add(ticket.cliff.mul(SECONDS_PER_DAY));
    }

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

    function available(uint256 _id) public view returns (uint256) {
        Ticket memory ticket = tickets[_id];
        if (ticket.balance == 0) return 0;

        uint256 unlockedAmount = unlocked(_id);
        return unlockedAmount > ticket.claimed ? unlockedAmount.sub(ticket.claimed) : 0;
    }

    function claimTicket(uint256 _id, address _recipient) public notRevoked(_id) nonReentrant returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (_recipient == address(0)) revert InvalidParams();
        if (ticket.beneficiary != msg.sender) revert UnauthorizedAccess();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 claimableAmount = available(_id);
        if (claimableAmount == 0) revert NothingToClaim();

        _processClaim(_id, claimableAmount, _recipient);
        return true;
    }

    function _processClaim(uint256 _id, uint256 _amount, address _claimer) private {
        Ticket storage ticket = tickets[_id];
        ticket.claimed = ticket.claimed.add(_amount);
        ticket.balance = ticket.balance.sub(_amount);
        ticket.lastClaimedAt = block.timestamp;

        emit Claimed(_id, _amount, _claimer);
        if (!token.transfer(_claimer, _amount)) revert TransferFailed();
    }

    function revoke(uint256 _id) public notRevoked(_id) returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (msg.sender != owner()) revert UnauthorizedAccess();
        if (ticket.isRevoked) revert TicketRevoked();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 remainingBalance = ticket.balance;
        ticket.isRevoked = true;
        ticket.balance = 0;

        emit Revoked(_id, remainingBalance);
        if (!token.transfer(owner(), remainingBalance)) revert TransferFailed();
        return true;
    }

    // function claimAllTicket(uint _ids[],address _receipient)

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function viewTicket(uint256 _id) public view returns (Ticket memory) {
        return tickets[_id];
    }

    function myBeneficiaryTickets(address _beneficiary) public view returns (uint256[] memory) {
        return beneficiaryTickets[_beneficiary];
    }

    function transferToken(address _to, uint256 _amount) external onlyOwner {
        if (!token.transfer(_to, _amount)) revert TransferFailed();
    }
}
