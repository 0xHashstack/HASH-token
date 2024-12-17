//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console, StdInvariant} from "forge-std/Test.sol";
import {MockClaimable} from "./MockClaimable.t.sol";
import {Claimable} from "../../src/Claimable2.sol";
import {HstkToken} from "../../src/HSTK.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract InvariantClaimable is StdInvariant, Test {
    // Test accounts
    address admin = address(1);
    address claimer = address(2);
    address random = address(3);

    MockClaimable mockClaimable;

    function setUp() public {
        mockClaimable = new MockClaimable(admin);
        targetContract(address(mockClaimable));
    }

    function initMint() public {
        vm.startPrank(admin);
        mockClaimable.mintInit(address(mockClaimable));
        vm.stopPrank();
    }

    function createTicket() public returns (uint256) {
        address sender = msg.sender;
        vm.startPrank(admin);
        uint256 ticketId = mockClaimable.createTicket(sender, 30, 1000);
        vm.stopPrank();
        return ticketId;
    }

    // function invariant_test_CannotRedeemMoreThanClaimable() public {
    //     uint256 ticketId = createTicket();
    //     FuzzSelector memory _fuzzSelectors = FuzzSelector({
    //         addr: address(mockClaimable),
    //         selectors: new bytes4[](6)
    //     });
    //     _fuzzSelectors.selectors[0] = HstkToken.transfer.selector;
    //     _fuzzSelectors.selectors[1] = HstkToken.transferFrom.selector;
    //     _fuzzSelectors.selectors[2] = HstkToken.approve.selector;
    //     _fuzzSelectors.selectors[3] = HstkToken.mint.selector;
    //     _fuzzSelectors.selectors[4] = HstkToken.burn.selector;
    //     _fuzzSelectors.selectors[4] = Claimable.initialize.selector;
    //     excludeSelector(_fuzzSelectors);
    //     MockClaimable.Ticket memory ticket = mockClaimable.viewTicket(ticketId);
    //     assert(ticket.amount >= ticket.claimed);
    // }
}
