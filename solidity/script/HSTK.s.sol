// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {HstkToken} from "../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract DeployHSTK is Script {
    HstkToken public hashToken;
    address superAdmin = address(0x14e7bBbDAc66753AcABcbf3DFDb780C6bD357d8E); // Replace this with Address of the owner
    address fallbackAdmin = address(0x9CE26bf410428d57B3E28b8c3A59457A7C476B65);
    MultiSigWallet multiSigContract;
    ERC1967Proxy multiSig;

    function deployMultiSig() public returns (address) {
        multiSigContract = new MultiSigWallet();
        // bytes memory multiSigCalldata = abi.encodeWithSelector(MultiSigWallet.initialize.selector, admin);

        multiSig = new ERC1967Proxy(address(multiSigContract),"");
        hashToken = new HstkToken(address(multiSig));

        MultiSigWallet(address(multiSig)).initialize(superAdmin,fallbackAdmin,address(hashToken));

        vm.label(address(multiSig), "MultiSig");
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
