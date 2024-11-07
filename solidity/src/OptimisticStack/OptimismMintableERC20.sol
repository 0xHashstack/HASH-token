// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ILegacyMintableERC20, IOptimismMintableERC20} from "./IOptimismMintableERC20.sol";
import {Pausable} from "../utils/Pausable.sol";
import {BlackListed} from "../utils/BlackListed.sol";
import {Semver} from "./Semver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title OptimismMintableERC20
 * @author Hashstack Finance
 * @notice OptimismMintableERC20 is a standard extension of the base ERC20 token contract designed
 *         to allow the StandardBridge contracts to mint and burn tokens. This makes it possible to
 *         use an OptimismMintablERC20 as the L2 representation of an L1 token, or vice-versa.
 *         Designed to be backwards compatible with the older StandardL2ERC20 token which was only
 *         meant for use on L2.
 */
contract OptimismMintableERC20 is IOptimismMintableERC20, ILegacyMintableERC20, ERC20, Semver, Pausable, BlackListed {
    using SafeERC20 for IERC20;
    /**
     * @notice Address of the corresponding version of this token on the remote chain.
     */

    address public immutable REMOTE_TOKEN;

    /**
     * @notice Mapping to track authorized bridge addresses that can mint and burn tokens
     * @dev Maps bridge address => authorization status (true = authorized, false = unauthorized)
     */
    mapping(address => bool) private authorizedBridges;

    /**
     * @notice Emitted when a bridge is authorized to handle token minting/burning
     * @param bridge The address of the bridge being authorized
     * @param operator The address that authorized the bridge
     */
    event BridgeAuthorized(address indexed bridge, address indexed operator);

    /**
     * @notice Emitted when a bridge's authorization is revoked
     * @param bridge The address of the bridge being unauthorized
     * @param operator The address that revoked the authorization
     */
    event BridgeUnauthorized(address indexed bridge, address indexed operator);

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

    /**
 * @notice A modifier that restricts function access to authorized bridges only
 */
modifier onlyAuthorizedBridge() {
    require(isAuthorizedBridge(_msgSender()), "OptimismMintableERC20: caller is not an authorized bridge");
    _;
}

    /**
     * @custom:semver 1.0.0
     *
     * @param _bridge      Address of the L2 standard bridge.
     * @param _remoteToken Address of the corresponding L1 token.
     */
    constructor(address _bridge, address _remoteToken, address _multiSig)
        ERC20("HSTK", "HSTK")
        Semver(1, 0, 0)
        Pausable()
        BlackListed(_multiSig)
    {
        REMOTE_TOKEN = _remoteToken;
        authorizedBridges[_bridge] = true;
    }

   
/**
 * @notice Authorizes a new bridge to mint and burn tokens
 * @dev Can only be called by contract admin/owner
 * @param _bridge Address of the bridge to authorize
 */
function authorizeBridge(address _bridge) external onlyMultiSig {
    require(_bridge != address(0), "OptimismMintableERC20: bridge cannot be zero address");
    require(!authorizedBridges[_bridge], "OptimismMintableERC20: bridge already authorized");
    
    authorizedBridges[_bridge] = true;
    emit BridgeAuthorized(_bridge, _msgSender());
}

/**
 * @notice Revokes a bridge's authorization to mint and burn tokens
 * @dev Can only be called by contract admin/owner
 * @param _bridge Address of the bridge to unauthorized
 */
function revokeBridgeAuthorization(address _bridge) external onlyMultiSig {
    require(_bridge != address(0), "OptimismMintableERC20: bridge cannot be zero address");
    require(authorizedBridges[_bridge], "OptimismMintableERC20: bridge not authorized");
    
    authorizedBridges[_bridge] = false;
    emit BridgeUnauthorized(_bridge, _msgSender());
}

/**
 * @notice Checks if a given address is an authorized bridge
 * @param _bridge Address to check for bridge authorization
 * @return bool True if the address is an authorized bridge, false otherwise
 */
function isAuthorizedBridge(address _bridge) public view returns(bool) {
    return authorizedBridges[_bridge];
}

    /**
     * @notice Allows the StandardBridge on this network to mint tokens.
     *
     * @param _to     Address to mint tokens to.
     * @param _amount Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount)
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyAuthorizedBridge
        allowedInActiveOrPartialPause
        notBlackListed(_to)
    {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    /**
     * @notice Allows the StandardBridge on this network to burn tokens.
     *
     * @param _from   Address to burn tokens from.
     * @param _amount Amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount)
        external
        virtual
        override(IOptimismMintableERC20, ILegacyMintableERC20)
        onlyAuthorizedBridge
        allowedInActiveOrPartialPause
    {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
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
     * @notice ERC165 interface check function.
     *
     * @param _interfaceId Interface ID to check.
     *
     * @return Whether or not the interface is supported by this contract.
     */
    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the legacy L2StandardERC20.
        bytes4 iface2 = type(ILegacyMintableERC20).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2 || _interfaceId == iface3;
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

    /**
     * @custom:legacy
     * @notice Legacy getter for the remote token. Use REMOTE_TOKEN going forward.
     */
    function l1Token() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /**
     * @custom:legacy
     * @notice Legacy getter for REMOTE_TOKEN.
     */
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }
}
