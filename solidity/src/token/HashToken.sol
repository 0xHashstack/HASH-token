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
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IHash.sol";

contract HashToken is IHashToken, Ownable2Step, ERC20Permit, ERC20Votes {
    using SafeERC20 for IERC20;

    constructor(
        address admin
    ) ERC20("Hash Token", "HASH") Ownable(admin) ERC20Permit("Hash Token") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function rescueTokens(IERC20 token, address to) external override {
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(to, amount);

        emit TokensRescued(to, amount);
    }
}