// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.4;

import {SafeMath} from "./utils/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {console} from "forge-std/console.sol";

contract Claimable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;

    uint256 public currentId;
    IERC20 public token;
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant PERCENTAGE_DENOMINATOR = 100;

    struct Ticket {
        address beneficiary;
        address pendingClaimer;
        uint256 cliff;
        uint256 vesting;
        uint256 amount;
        uint256 claimed;
        uint256 balance;
        uint256 createdAt;
        uint256 lastClaimedAt;
        uint256 numClaims;
        uint256 tgePercentage;
        bool irrevocable;
        bool isRevoked;
    }

    mapping(address => uint256[]) public beneficiaryTickets;
    mapping(address=>uint256[]) public claimerTickets;
    mapping(uint256 => Ticket) private tickets;

    event TicketCreated(uint256 indexed id, uint256 amount, uint256 tgePercentage, bool irrevocable);
    event Claimed(uint256 indexed id, uint256 amount, address claimer);
    event ClaimDelegated(uint256 indexed id, uint256 amount, address pendingClaimer);
    event Revoked(uint256 indexed id, uint256 amount);

    error ZeroAddress();
    error UnauthorizedAccess();
    error InvalidBeneficiary();
    error InvalidAmount();
    error InvalidVestingPeriod();
    error InvalidTGEPercentage();
    error TicketRevoked();
    error NothingToClaim();
    error TransferFailed();
    error IrrevocableTicket();
    error InvalidParams();
    error NoPendingClaim();

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
        bool _irrevocable
    ) public onlyOwner returns (uint256 ticketId) {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_amount == 0) revert InvalidAmount();
        if (_vesting < _cliff) revert InvalidVestingPeriod();
        if (_tgePercentage > PERCENTAGE_DENOMINATOR) revert InvalidTGEPercentage();

        ticketId = ++currentId;
        Ticket storage ticket = tickets[ticketId];

        ticket.beneficiary = _beneficiary;
        ticket.cliff = _cliff;
        ticket.vesting = _vesting;
        ticket.amount = _amount;
        ticket.balance = _amount;
        ticket.createdAt = block.timestamp;
        ticket.irrevocable = _irrevocable;
        ticket.tgePercentage = _tgePercentage;

        beneficiaryTickets[_beneficiary].push(ticketId);

        emit TicketCreated(ticketId, _amount, _tgePercentage, _irrevocable);
    }

    /// @notice allow batch create tickets with the same terms same amount
    function batchCreateSameAmount(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256 _amount,
        uint256 _tgePercentage,
        bool _irrevocable
    ) public {
        /// @dev set maximum array length?
        require(_beneficiaries.length > 0, "At least one beneficiary is required");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            create(_beneficiaries[i], _cliff, _vesting, _amount, _tgePercentage, _irrevocable);
        }
    }

    function batchCreate(
        address[] memory _beneficiaries,
        uint256 _cliff,
        uint256 _vesting,
        uint256[] memory _amounts,
        uint256 _tgePercentage,
        bool _irrevocable
    ) public onlyOwner {
        if (_beneficiaries.length != _amounts.length) revert InvalidParams();
        if (_beneficiaries.length == 0) revert InvalidParams();

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_amounts[i] > 0) {
                create(_beneficiaries[i], _cliff, _vesting, _amounts[i], _tgePercentage, _irrevocable);
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

        console.log("remainingAmount: ", remainingAmount);

        // Calculate cliff timestamp
        uint256 cliffTime = ticket.createdAt.add(ticket.cliff.mul(SECONDS_PER_DAY));

        console.log("cliffTime: ", cliffTime);

        // Calculate total vesting duration (from cliff end to vesting end)
        uint256 vestingDuration = (ticket.vesting).mul(SECONDS_PER_DAY);

        console.log("vestingDuration: ", vestingDuration);

        // Calculate time elapsed since cliff
        uint256 timeSinceCliff = block.timestamp.sub(cliffTime);

        console.log("timeSinceCliff: ", timeSinceCliff);

        // If vesting period complete, return full amount
        if (timeSinceCliff >= vestingDuration) {
            return ticket.amount;
        }

        // Calculate linear vesting for remaining amount
        uint256 vestedAmount = remainingAmount.mul(timeSinceCliff).div(vestingDuration);

        console.log("vestedAmount: ", vestedAmount);

        return tgeAmount.add(vestedAmount);
    }

    function available(uint256 _id) public view notRevoked(_id) returns (uint256) {
        Ticket memory ticket = tickets[_id];
        if (ticket.balance == 0) return 0;

        uint256 unlockedAmount = unlocked(_id);
        return unlockedAmount > ticket.claimed ? unlockedAmount.sub(ticket.claimed) : 0;
    }

    function delegateClaim(uint256 _id, address _pendingClaimer) public notRevoked(_id) returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (_pendingClaimer == address(0)) revert InvalidParams();
        if (ticket.beneficiary != msg.sender) revert UnauthorizedAccess();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 claimableAmount = available(_id);
        if (claimableAmount == 0) revert NothingToClaim();

        if (_pendingClaimer == msg.sender) {
            _processClaim(_id, claimableAmount, msg.sender);
        } else {
            ticket.pendingClaimer = _pendingClaimer;
            claimerTickets[_pendingClaimer].push(_id);
            emit ClaimDelegated(_id, claimableAmount, _pendingClaimer);
        }
        return true;
    }

    function acceptClaim(uint256 _id) external notRevoked(_id) returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (ticket.pendingClaimer == address(0)) revert NoPendingClaim();
        if (msg.sender != ticket.pendingClaimer) revert UnauthorizedAccess();

        uint256 claimableAmount = available(_id);
        if (claimableAmount == 0) revert NothingToClaim();

        address claimer = ticket.pendingClaimer;
        _processClaim(_id, claimableAmount, claimer);
        return true;
    }

    function _processClaim(uint256 _id, uint256 _amount, address _claimer) private {
        Ticket storage ticket = tickets[_id];
        ticket.claimed = ticket.claimed.add(_amount);
        ticket.balance = ticket.balance.sub(_amount);
        ticket.lastClaimedAt = block.timestamp;
        ticket.numClaims++;

        emit Claimed(_id, _amount, _claimer);
        if (!token.transfer(_claimer, _amount)) revert TransferFailed();
    }

    function revoke(uint256 _id) public notRevoked(_id) returns (bool) {
        Ticket storage ticket = tickets[_id];
        if (msg.sender != owner()) revert UnauthorizedAccess();
        if (ticket.irrevocable) revert IrrevocableTicket();
        if (ticket.balance == 0) revert NothingToClaim();

        uint256 remainingBalance = ticket.balance;
        ticket.isRevoked = true;
        ticket.balance = 0;

        emit Revoked(_id, remainingBalance);
        if (!token.transfer(owner(), remainingBalance)) revert TransferFailed();
        return true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function viewTicket(uint256 _id) public view returns (Ticket memory) {
        return tickets[_id];
    }

    function myBeneficiaryTickets(address _beneficiary) public view returns (uint256[] memory) {
        return beneficiaryTickets[_beneficiary];
    }
    function myClaimerTickets(address _claimer) public view returns (uint256[] memory) {
        return claimerTickets[_claimer];
    }

    function transferToken(address _to, uint256 _amount) external onlyOwner {
        if (!token.transfer(_to, _amount)) revert TransferFailed();
    }
}
