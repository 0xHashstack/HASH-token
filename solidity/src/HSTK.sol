// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Pausable } from './utils/Pausable.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';
import { BlackListed } from './utils/BlackListed.sol';

/**
 * @title HstkToken
 * @dev Implementation of the HstkToken
 * This contract extends ERC20 with Pausable and BlackListed functionalities.
 * It includes features for minting, burning, token recovery, and various pause states.
 */
contract HstkToken is ERC20, Pausable, BlackListed {
    using SafeERC20 for IERC20;

    /// @dev Error thrown when attempting to mint tokens beyond the max supply
    error MAX_SUPPLY_EXCEEDED();

    /// @dev Event emitted when tokens are rescued from the contract
    event TOKEN_RESCUED(address indexed token, address indexed to, uint amount);

    /// @dev The maximum total supply of tokens
    uint private constant TOTAL_SUPPLY = 9_000_000_000;

    /**
     * @dev Constructor that gives the admin the initial supply of tokens
     * @param admin Address of the admin account
     */
    constructor(address admin) ERC20('Hstk Token', 'HSTK') Pausable() BlackListed(admin) {
        require(admin != address(0), 'Address cannot be zero address');
        _mint(admin, 1);
    }

    /**
     * @dev See {ERC20-transfer}.
     * Added whenNotPartialPaused and whenNotPaused modifiers
     */
    function transfer(
        address to,
        uint value
    )
        public
        virtual
        override
        whenNotPartialPaused
        whenNotPaused
        notBlackListed(to)
        returns (bool)
    {
        return super.transfer(to, value);
    }

    /**
     * @dev See {ERC20-transferFrom}.
     * Added whenNotPartialPaused and whenNotPaused modifiers
     */
    function transferFrom(
        address from,
        address to,
        uint value
    )
        public
        virtual
        override
        whenNotPartialPaused
        whenNotPaused
        notBlackListed(from)
        notBlackListed(to)
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }

    /**
     * @dev See {ERC20-approve}.
     * Added whenNotPaused modifier
     */
    function approve(
        address spender,
        uint value
    )
        public
        virtual
        override
        whenNotPaused
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
     * - Total supply after minting must not exceed TOTAL_SUPPLY
     */
    function mint(
        address account,
        uint value
    )
        external
        whenNotPaused
        zeroAddress(account)
        onlyAdmin
        notBlackListed(account)
    {
        if (totalSupply() + value > TOTAL_SUPPLY) {
            revert MAX_SUPPLY_EXCEEDED();
        }
        _mint(account, value);
    }

    /**
     * @dev Burns tokens
     * @param account The address whose tokens will be burned
     * @param value The amount of tokens to burn
     * Requirements:
     * - Can only be called by the admin
     * - Contract must not be paused
     * - `account` cannot be the zero address
     */
    function burn(address account, uint value) external whenNotPaused zeroAddress(account) onlyAdmin {
        _burn(account, value);
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
    function recoverToken(
        address asset,
        address to
    )
        external
        whenNotPaused
        onlyAdmin
        zeroAddress(asset)
        zeroAddress(to)
    {
        IERC20 interfaceAsset = IERC20(asset);
        uint balance = interfaceAsset.balanceOf(address(this));

        interfaceAsset.safeTransfer(to, balance);

        emit TOKEN_RESCUED(asset, to, balance);
    }

    /**
     * @dev Pauses all token transfers.
     * Requirements:
     * - Can only be called by the admin
     * - The contract must not be paused
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     * Requirements:
     * - Can only be called by the admin
     * - The contract must be paused
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @dev Partially pauses the contract, limiting some functionalities.
     * Requirements:
     * - Can only be called by the admin
     * - The contract must not be partially paused
     */
    function partialPause() external onlyAdmin {
        _partialPause();
    }

    /**
     * @dev Removes the partial pause state, restoring full functionality.
     * Requirements:
     * - Can only be called by the admin
     * - The contract must be partially paused
     */
    function partialUnPause() external onlyAdmin {
        _partialUnpause();
    }
}
