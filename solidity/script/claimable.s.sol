// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Claimable} from "../src/Claimable2.sol";
import {HstkToken} from "../src/HSTK.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/Proxy/ERC1967/ERC1967Proxy.sol";

contract DeployClaimable is Script {
    HstkToken public hashToken;
    address superAdmin = address(0x121631f31B2C8Cb8d2A938C4D3ca5773832F3fa9); // Replace this with Address of the owner
    ERC1967Proxy claimContract;

    function deployClaimable() public returns (address) {
        Claimable claim = new Claimable();
        // bytes memory multiSigCalldata = abi.encodeWithSelector(MultiSigWallet.initialize.selector, admin);

        claimContract = new ERC1967Proxy(address(claim), "");
        hashToken = new HstkToken(address(superAdmin));

        // bytes memory multiSigCalldata = abi.encodeWithSelector(MultiSigWallet.initialize.selector, admin);

        Claimable(address(claimContract)).initialize(address(hashToken), superAdmin);

        vm.label(address(claimContract), "Claim Contract");
        vm.label(address(hashToken), "HASH Token Address:");

        return address(claimContract);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deployClaimable();
        vm.stopBroadcast();
    }

    ////source .env && forge script script/claimable.s.sol:DeployClaimable --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
}
