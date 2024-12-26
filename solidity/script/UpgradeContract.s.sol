// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Script, console} from "forge-std/Script.sol";
import {Claimable} from "../src/Claimable.sol";
import {NewClaimable} from "../src/NewClaimable.sol";
import {HstkToken} from "../src/HSTK.sol";

contract TestnetUpgradeScript is Script {
    address constant PROXY_ADDRESS = 0xCF97628F60eBaB69f2Eb182a86267a8478d0072e;
    address constant SUPER_ADMIN = 0x02847D22C33f5F060Bd27e69F1a413AD44cab213;
    HstkToken _hashToken;
    // Test addresses
    address[] testAddresses = [
        0x02847D22C33f5F060Bd27e69F1a413AD44cab213,
        0xaF7f488eDf63410AF7B82998A6a96a14dcB8e89d,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0xe2C8f362154aacE6144Cb9d96f45b9568e0Ea721 // Adding the specific address from your test
    ];

    Claimable oldImplementation;
    NewClaimable newImplementation;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Connect to existing proxy
        oldImplementation = Claimable(PROXY_ADDRESS);

        // Step 2: Create tickets on old implementation
        createTicketsOnOldContract();

        // Step 2.5: Store hash token
        _hashToken = HstkToken(payable(0xC8e007ec54F05e044737cc5Bcf6F8976a4242E99));
        _hashToken.mint(PROXY_ADDRESS, 12_125_000 * 10 ** 18);
        // Step 3: Deploy new implementation
        newImplementation = new NewClaimable();

        // Step 4: Upgrade to new implementation
        performUpgrade();

        // Step 5: Verify tickets and test claiming
        verifyAndTestClaiming();

        vm.stopBroadcast();
    }

    function createTicketsOnOldContract() internal {
        console.log("Creating tickets on old implementation...");

        for (uint256 i = 0; i < testAddresses.length; i++) {
            // Create different types of tickets for each address
            oldImplementation.create(
                testAddresses[i],
                10, // cliff
                15, // 1 day vesting
                161 * 10 ** 18, // 61.125M tokens
                50, // 50% TGE
                1 // ticket type
            );

            oldImplementation.create(
                testAddresses[i],
                30 days, // 1 month cliff
                180 days, // 6 months vesting
                220 * 10 ** 18, // 12.125M tokens
                25, // 25% TGE
                2 // ticket type
            );

            uint256[] memory oldTickets = oldImplementation.myBeneficiaryTickets(testAddresses[i]);
            console.log("Created tickets for address:", testAddresses[i]);
            console.log("Number of tickets:", oldTickets.length);
        }
    }

    function performUpgrade() internal {
        console.log("Performing upgrade...");

        // Store ticket counts before upgrade
        uint256[][] memory preUpgradeTickets = new uint256[][](testAddresses.length);
        for (uint256 i = 0; i < testAddresses.length; i++) {
            preUpgradeTickets[i] = oldImplementation.myBeneficiaryTickets(testAddresses[i]);
        }

        // Upgrade to new implementation
        oldImplementation.upgradeToAndCall(address(newImplementation), "");

        // Connect to upgraded contract
        newImplementation = NewClaimable(PROXY_ADDRESS);

        // Verify ticket counts after upgrade
        for (uint256 i = 0; i < testAddresses.length; i++) {
            uint256[] memory postUpgradeTickets = newImplementation.myBeneficiaryTickets(testAddresses[i]);
            require(postUpgradeTickets.length == preUpgradeTickets[i].length, "Ticket count mismatch after upgrade");
            console.log("Verified tickets for address:", testAddresses[i], "Count:", postUpgradeTickets.length);
        }
    }

    function verifyAndTestClaiming() internal {
        console.log("Testing claiming functionality...");

        for (uint256 i = 0; i < testAddresses.length; i++) {
            uint256[] memory userTickets = newImplementation.myBeneficiaryTickets(testAddresses[i]);

            console.log("\nAddress:", testAddresses[i]);
            console.log("Number of tickets:", userTickets.length);

            // Log available amounts before claiming
            console.log("Available amounts before claiming:");
            for (uint256 j = 0; j < userTickets.length; j++) {
                uint256 available = newImplementation.available(userTickets[j]);
                console.log("Ticket", userTickets[j], ":", available);
            }

            // Test claiming
            vm.stopBroadcast();
            vm.startPrank(testAddresses[i]);
            newImplementation.claimTokens(testAddresses[i]);

            vm.expectRevert();
            newImplementation.claimTokens(testAddresses[i]);
            console.log("Reverting Successfully");
            vm.stopPrank();
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

            // Log available amounts after claiming
            console.log("Available amounts after claiming:");
            for (uint256 j = 0; j < userTickets.length; j++) {
                uint256 available = newImplementation.available(userTickets[j]);
                console.log("Ticket", userTickets[j], ":", available);
            }
        }
    }
}
