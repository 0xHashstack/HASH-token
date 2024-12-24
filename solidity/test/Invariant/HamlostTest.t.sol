// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Claimable} from "../../src/Claimable.sol";
import {HstkToken} from "../../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract HalmosTest is Test {
    Claimable public claimable;
    HstkToken public token;

    address public owner;
    address public beneficiary1;
    address public beneficiary2;
    address public claimer;

    function setUp() public {
        owner = address(100);
        beneficiary1 = address(1);

        // Deploy mock ERC20 token
        token = new HstkToken(owner);

        // Deploy and initialize Claimable contract
        Claimable implementation = new Claimable();

        bytes memory callData = abi.encodeWithSelector(Claimable.initialize.selector, address(token), owner);

        ERC1967Proxy claimableContract_ = new ERC1967Proxy(address(implementation), callData);

        claimable = Claimable(address(claimableContract_));

        vm.prank(owner);
        token.mint(address(claimable), 10_000_000 * 10 ** 18);
    }

    // Ticket Creation Tests
    function createTicket() public returns (uint256) {
        // Create ticket
        vm.prank(owner);
        uint256 ticketId = claimable.create(beneficiary1, 30, 90, 1000, 20, 0);
        return ticketId;
    }

    function check_claimedLessthanAllocated() public {
        createTicket();
        assert(token.balanceOf(beneficiary1) <= 1000);
    }
}
