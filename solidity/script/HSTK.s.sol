// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {HstkToken} from "../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract DeployHSTK is Script {
    HstkToken public hashToken;
    address superAdmin = address(0xE4f3B256c27cE7c76C5D16Ae81838aA14d8846C8); // Replace this with Address of the owner
    address fallbackAdmin = address(0x6C231C5e75e2b92B8e16508539b5431298dFF1E4);
    MultiSigWallet multiSigContract;
    ERC1967Proxy multiSig;

    function deployMultiSig() public returns (address) {
        multiSigContract = new MultiSigWallet();


        multiSig = new ERC1967Proxy(address(multiSigContract), "");
        hashToken = new HstkToken(address(multiSig));

        MultiSigWallet(address(multiSig)).initialize(superAdmin, fallbackAdmin, address(hashToken));

        vm.label(address(multiSig), "MultiSig Proxy");
        vm.label(address(hashToken), "HASH Token Address:");

        return address(multiSig);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deployMultiSig();
        vm.stopBroadcast();
    }

    ////source .env && forge script script/HSTK.s.sol:DeployHSTK --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
}
