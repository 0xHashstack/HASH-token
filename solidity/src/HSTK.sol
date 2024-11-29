// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Pausable} from "./utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {BlackListed} from "./utils/BlackListed.sol";

/**
 * @title HstkToken
 * @dev Implementation of the HstkToken
 * This contract extends ERC20 with Pausable and BlackListed functionalities.
 * It includes features for minting, burning, token recovery, and various pause states.
 */
contract HstkToken is ERC20, Pausable, BlackListed {
    using SafeERC20 for IERC20;

    /**
     * @notice Emitted whenever MAX Supply is reached.
     */
    error MAX_SUPPLY_EXCEEDED();

    /**
     * @notice Emitted whenever tokens are minted for an account.
     *
     * @param account Address of the account tokens are being minted for.
     * @param amount  Amount of tokens minted.
     */
    event Mint(address indexed account, uint256 amount);

    /**
     * @notice Event emitted when tokens are rescued from the contract
     *
     * @param token Address of the token to be rescued
     * @param to Address of receipient
     * @param amount amount transferred to 'to' address
     */
    event Token_Rescued(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Emitted whenever tokens are burned from an account.
     *
     * @param account Address of the account tokens are being burned from.
     * @param amount  Amount of tokens burned.
     */
    event Burn(address indexed account, uint256 amount);

    /// @dev The maximum total supply of tokens
    uint256 private constant MAX_SUPPLY = 9_000_000_000e18;

    /**
     * @dev Constructor that gives the admin the initial supply of tokens
     * @param _multisig Address of the multiSig account
     */
    constructor(address _multisig) ERC20("HSTK", "HSTK") Pausable() BlackListed(_multisig) {
        require(_multisig != address(0), "Address cannot be zero address");
        _mint(_multisig, 1 * 10 ** decimals());
    }

    /**
     * @dev See {ERC20-transfer}.
     * Added partialPausedOff and pausedOff modifiers
     */
    function transfer(address to, uint256 value)
        public
        override
        whenActive
        notBlackListed(_msgSender())
        notBlackListed(to)
        returns (bool)
    {
        return super.transfer(to, value);
    }

    /**
     * @dev See {ERC20-transferFrom}.
     * Added partialPausedOff and pausedOff modifiers
     */
    function transferFrom(address from, address to, uint256 value)
        public
        override
        whenActive
        notBlackListed(_msgSender())
        notBlackListed(from)
        notBlackListed(to)
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }

    /**
     * @dev See {ERC20-approve}.
     * Added pausedOff modifier
     */
    function approve(address spender, uint256 value)
        public
        override
        allowedInActiveOrPartialPause
        notBlackListed(_msgSender())
        notBlackListed(spender)
        returns (bool)
    {
        return super.approve(spender, value);
    }

    /**
     * @dev Mints new tokens
     * @param account The address that will receive the minted tokens
     * @param value The amount of tokens to mint
     * Requirements:
     * - Can only be called by the admin
     * - Contract must not be paused
     * - `account` cannot be the zero address
     * - Total supply after minting must not exceed MAX_SUPPLY
     */
    function mint(address account, uint256 value)
        external
        allowedInActiveOrPartialPause
        onlyMultiSig
        notBlackListed(account)
    {
        if (totalSupply() + value > MAX_SUPPLY) {
            revert MAX_SUPPLY_EXCEEDED();
        }
        _mint(account, value);
        emit Mint(account, value);
    }

    /**
     * @dev Burns tokens
     * @param value The amount of tokens to burn
     * Requirements:
     * - Contract must not be fully paused
     */
    function burn(uint256 value) external allowedInActiveOrPartialPause {
        _burn(_msgSender(), value);
        emit Burn(_msgSender(), value);
    }

    /**
     * @dev Recovers tokens accidentally sent to this contract
     * @param asset The address of the token to recover
     * @param to The address to send the recovered tokens
     * Requirements:
     * - Can only be called by the admin
     * - `asset` and `to` cannot be the zero address
     * @notice This function can be used to recover any ERC20 tokens sent to this contract by mistake
     */
    function recoverToken(address asset, address to) external allowedInActiveOrPartialPause onlyMultiSig {
        IERC20 interfaceAsset = IERC20(asset);
        uint256 balance = interfaceAsset.balanceOf(address(this));
        interfaceAsset.safeTransfer(to, balance);
        emit Token_Rescued(asset, to, balance);
    }

    /**
     * @dev Updates the contract's operational state
     * @param newState The new state to set (0: Active, 1: Partial Pause, 2: Full Pause)
     * Requirements:
     * - Can only be called by the MultiSig
     */
    function updateOperationalState(uint8 newState) external onlyMultiSig {
        _updateOperationalState(newState);
    }
}
