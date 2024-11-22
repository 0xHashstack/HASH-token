# OptimismMintableERC20

## Overview

The `OptimismMintableERC20` smart contract is a specialized ERC20 token implementation designed for use in cross-chain scenarios, particularly as a bridgeable token on the Base Layer 2 network. This contract allows for the seamless minting and burning of tokens across the Layer 1 (L1) and Layer 2 (L2) networks, enabling cross-chain token transfers by mirroring the token on both chains.

The contract is fully compliant with ERC20 standards and includes extensions for bridge authorization, pausing, blacklisting, and token recovery, making it versatile and secure for multi-chain applications.

## Key Features

- **Cross-Chain Minting and Burning**: Supports token minting and burning via authorized bridge contracts, allowing token representation on both L1 and L2 networks.
- **Bridge Authorization Management**: Only authorized bridge addresses are permitted to mint and burn tokens, enhancing security.
- **Pausable Operations**: Contract functions can be partially or fully paused by a multisig-admin, adding control over operations during specific situations.
- **Blacklist Functionality**: Ability to blacklist certain addresses, preventing them from performing token transfers.
- **Token Recovery**: Admins can recover any ERC20 tokens accidentally sent to the contract.
- **Versioning**: Uses `Semver` for tracking contract version.

## System Architecture

### Role Hierarchy

1. **Multisig Admin**
   - Grants and revokes bridge authorization
   - Manages contract state (pause, unpause)
   - Recovers accidentally sent tokens
   - Controls blacklist management

2. **Authorized Bridges**
   - Can mint and burn tokens on L2 on behalf of L1 operations

### Key Components

#### 1. Cross-Chain Functionality

The contract utilizes `REMOTE_TOKEN` to store the address of the equivalent L1 or L2 token. Only authorized bridge contracts can initiate cross-chain transactions by calling the `mint` and `burn` functions. This ensures secure and controlled token movement across chains.

#### 2. Pausable and Blacklist Features

The contract includes both **pause** and **blacklist** functionality:
- **Pause Mechanism**: Admin can set contract status to active, partially paused, or fully paused, restricting operations under specific conditions.
- **Blacklist Mechanism**: Specific addresses can be blacklisted, preventing them from transferring or approving tokens, adding another layer of security.

#### 3. Token Rescue

A token recovery function is provided, allowing the multisig admin to recover any mistakenly sent ERC20 tokens from this contract.

## Contract Functions

### Core Functions

- **authorizeBridge(address _bridge)**: Adds a bridge to the list of authorized bridges allowed to mint and burn tokens. Callable only by the multisig admin.
- **revokeBridgeAuthorization(address _bridge)**: Removes a bridge from the list of authorized bridges, disabling its ability to mint and burn tokens.
- **mint(address _to, uint256 _amount)**: Mints tokens to a specified address. Only callable by an authorized bridge during active or partially paused states, and only if the recipient is not blacklisted.
- **burn(address _from, uint256 _amount)**: Burns tokens from a specified address. Only callable by an authorized bridge during active or partially paused states.
- **transfer** and **transferFrom**: Modified to include blacklist checks, ensuring blacklisted addresses cannot send or receive tokens.

### Helper Functions

- **isAuthorizedBridge(address _bridge)**: Verifies if a specific bridge address is authorized to mint or burn tokens.
- **recoverToken(address asset, address to)**: Allows the admin to recover tokens accidentally sent to this contract, transferring them to a specified recipient address.
- **supportsInterface(bytes4 _interfaceId)**: Implements ERC165 to specify the interfaces supported by this contract.
- **updateOperationalState(uint8 newState)**: Updates the contract's operational state (active, partial pause, or full pause), managed by the multisig admin.

### Events

- **BridgeAuthorized**: Emitted when a bridge is authorized for minting and burning.
- **BridgeUnauthorized**: Emitted when a bridge’s authorization is revoked.
- **Mint**: Emitted whenever tokens are minted to an address.
- **Burn**: Emitted whenever tokens are burned from an address.
- **Token_Rescued**: Emitted when tokens are recovered from the contract by the admin.

## Usage Example

1. **Bridge Authorization**: The admin authorizes a new bridge to handle minting and burning.
2. **Cross-Chain Minting**: An authorized bridge mints tokens on L2 based on L1 operations.
3. **Pausing**: If necessary, the admin can partially or fully pause contract operations.
4. **Blacklist Management**: Specific addresses can be blacklisted, preventing them from transferring tokens.
5. **Token Recovery**: Admin can recover mistakenly sent ERC20 tokens to the contract.

