// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Console2.sol";
import {HashToken} from "../src/token/HashToken.sol";

contract DeployToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wallet = vm.envAddress("WALLET_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        console2.log(".......... Deploying Contract .........");

        HashToken token = new HashToken(wallet);

        vm.stopBroadcast();

        console2.log("Contract Deployed to", address(token));
    }
}
