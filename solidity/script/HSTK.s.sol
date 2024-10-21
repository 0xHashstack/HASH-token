// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HstkToken} from "../src/HSTK.sol";

contract CounterScript is Script {
    HstkToken public hashToken;
    address admin = address(323);                              // Replace this with Address of the owner
    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        hashToken = new HstkToken(admin);
        vm.label(address(hashToken),"HASH Token Address:");
        vm.stopBroadcast();
    }
}
