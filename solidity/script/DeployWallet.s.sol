// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Console2.sol";
import {HashWallet} from "../src/wallet.sol";

contract DeployWallet is Script {
    address[] owners;

    function run() external returns (HashWallet){
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address charlie = makeAddr("charlie");

        owners.push(alice);
        owners.push(bob);
        owners.push(charlie);

        uint256 confirmations = 2;
        vm.startBroadcast(/*deployerPrivateKey*/);

        console2.log(".......... Deploying Contract .........");

        HashWallet wallet = new HashWallet(owners, confirmations);

        vm.stopBroadcast();

        console2.log("Contract Deployed to", address(wallet));
        return wallet;
    }
}
