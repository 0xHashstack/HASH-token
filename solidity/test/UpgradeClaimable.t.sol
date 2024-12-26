// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {Claimable} from "../src/Claimable.sol";
import {NewClaimable} from "../src/NewClaimable.sol";
import {HstkToken} from "../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeClaimableTest is Test {
    address constant PROXY_ADDRESS = 0x256A0Be12D2a8Ff93C719350cA0D5fB624bEaA75; // Your deployed proxy address
    address constant SUPER_ADMIN = 0x14e7bBbDAc66753AcABcbf3DFDb780C6bD357d8E;

    NewClaimable newImplementation;
    Claimable proxy;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("RPC_URL"));

        // Deploy new implementation
        newImplementation = new NewClaimable();
        proxy = Claimable(PROXY_ADDRESS);
    }

    function testUpgrade() public {
        // Impersonate super admin
        vm.startPrank(SUPER_ADMIN);
        uint256[] memory _prevuserTickets = proxy.myBeneficiaryTickets(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721);
        console.log(_prevuserTickets.length);
        //         vm.rollFork(21470909);
        //         assertEq(block.number,
        // 21470909);
        //         console.log("block.number : ", block.number);
        // Perform upgrade through UUPS pattern
        proxy.upgradeToAndCall(address(newImplementation), "");

        newImplementation = NewClaimable(address(proxy));
        newImplementation.create(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721, 0, 1, 61125000000000000000000000, 50, 1);
        newImplementation.create(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721, 0, 1, 12125000000000000000000000, 50, 2);
        newImplementation.create(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721, 0, 1, 11125000000000000000000000, 50, 3);
        newImplementation.create(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721, 0, 1, 91125000000000000000000000, 50, 4);
        uint256[] memory userTickets =
            newImplementation.myBeneficiaryTickets(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721);
        console.log(userTickets.length);
        for (uint256 i = 0; i < userTickets.length; i++) {
            uint256 amountLeft = newImplementation.available(userTickets[i]);
            console.log(amountLeft);
        }
        vm.stopPrank();
        vm.startPrank(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721);
        newImplementation.claimAllTokens(0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721);
        for (uint256 i = 0; i < userTickets.length; i++) {
            uint256 amountLeft = newImplementation.available(userTickets[i]);
            console.log(amountLeft);
        }
        // uint tickets = newImplementation.currentId();

        vm.stopPrank();
    }
}
