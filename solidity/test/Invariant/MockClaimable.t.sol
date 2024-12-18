// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Claimable} from "../../src/Claimable.sol";
import {HstkToken} from "../../src/HSTK.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockClaimable is Claimable {
    // Constants
    uint256 private constant TOTAL_SUPPLY = 9_000_000_000e18;

    HstkToken private hstkToken;

    constructor(address admin) {
        hstkToken = new HstkToken(admin);
        initialize(address(hstkToken), admin);
        // Deploy and initialize Claimable contract
        // Claimable implementation = new Claimable();

        // bytes memory callData = abi.encodeWithSelector(Claimable.initialize.selector, address(hstkToken), admin);

        // ERC1967Proxy claimableContract_ = new ERC1967Proxy(address(implementation), callData);
    }

    function mintInit(address multiSig) public {
        hstkToken.mint(multiSig, 10_000_000 * 10 ** 10);
    }

    function createTicket(address claimer, uint256 cliff, uint256 amount) public returns (uint256) {
        return create(claimer, cliff, cliff + 10 * 86400, amount, 50, 0);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) public payable override {
        // hstkToken.upgradeToAndCall(newImplementation, data);
    }
}
