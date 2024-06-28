// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHashToken is IERC20 {
    /// @dev Triggered when minting is attempted to a zero address.
    error HashToken__MintingToZeroAddressNotAllowed();

    /// @dev Triggered when an attempt to mint new tokens is made before the minimum time since deployment has passed.
    error HashToken__MintingNotAllowedYet();

    /// @dev Emitted when tokens are rescued from the contract in case of any exploit.
    /// @param to The address receiving the rescued tokens.
    /// @param amount The amount of tokens rescued.
    event TokensRescued(address to, uint256 amount);

    /// @dev Destroys `amount` tokens from the caller's balance.
    /// @param amount The number of tokens to burn.
    function burn(uint256 amount) external;

    /// @dev Recovers tokens that have been accidentally sent to the contract or sends tokens to an address in case of any exploit.
    /// @param token The address of the token to be recovered.
    /// @param to The address to which the rescued tokens should be sent.
    function rescueTokens(IERC20 token, address to) external;
}
