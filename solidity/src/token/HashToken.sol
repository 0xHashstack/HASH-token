/// ----------------------------------------------------------------------------- ///
///                                                                               ///
///                             Hash Token Contract                               ///
///                                                                               ///
/// ----------------------------------------------------------------------------- ///
/// ----------------------------------------------------------------------------- ///
/// @title Token Contract                                                         ///
/// @author Hashstack Finance                                                     ///
/// @dev All functions calls are implemented                                      ///
/// @notice Token holders have the ability to burn their own tokens.This contract ///
///         supports the delegation of voting rights.                             ///
/// ----------------------------------------------------------------------------- ///

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IHashToken } from "../interfaces/IHash.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NostraToken is IHashToken, Ownable2Step, ERC20Votes {
    using SafeERC20 for IERC20;

    string private _name;
    string private _symbol;

    uint256 public constant override INITIAL_SUPPLY = 100_000_000e18;

    constructor(address admin) ERC20("Hash Token", "HASH") ERC20Permit("Hash Token") {    
        _mint(admin, INITIAL_SUPPLY);
        _transferOwnership(admin);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function rescueTokens(IERC20 token, address to) external override onlyOwner {
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(to, amount);

        emit TokensRescued(to, amount);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
}