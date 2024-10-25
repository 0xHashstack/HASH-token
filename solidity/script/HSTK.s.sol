// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {HstkToken} from "../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract DeployHSTK is Script {
    HstkToken public hashToken;
    address admin = address(0x6C231C5e75e2b92B8e16508539b5431298dFF1E4); // Replace this with Address of the owner
    MultiSigWallet multiSigContract;
    ERC1967Proxy multiSig;

    function deployMultiSig() public returns (address) {
        multiSigContract = new MultiSigContract();
        bytes memory multiSigCalldata = abi.encodeWithSelector(MultiSigContract.initialize.selector, admin);

        multiSig = new ERC1967Proxy(address(multiSigContract), multiSigCalldata);

        vm.label(address(multiSig), "MultiSig");

        return address(multiSig);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deployMultiSig();
        vm.label(address(hashToken), "HASH Token Address:");
        vm.stopBroadcast();
    }

    ////source .env && forge script script/HSTK.s.sol:DeployHSTK --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
}
