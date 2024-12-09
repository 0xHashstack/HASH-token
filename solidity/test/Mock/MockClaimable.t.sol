// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Claimable} from "../../src/Claimable2.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockClaimable is Claimable {
    constructor(address admin) {}
}
