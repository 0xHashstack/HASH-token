// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClaimsContract is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public totalAllocated;

    struct Allocation {
        address recipient;
        uint256 amount;
        uint256 vestingStart;
        uint256 vestingDuration;
    }

    Allocation[] public allocations;

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }

    function addAllocation(address _recipient, uint256 _amount, uint256 _vestingStart, uint256 _vestingDuration)
        external
        onlyOwner
    {
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Invalid amount");

        allocations.push(Allocation(_recipient, _amount, _vestingStart, _vestingDuration));
        totalAllocated += _amount;
    }

    function releaseTokens(uint256 _allocationIndex) external {
        Allocation storage allocation = allocations[_allocationIndex];
        require(allocation.recipient == msg.sender, "Not authorized");
        require(block.timestamp >= allocation.vestingStart, "Vesting not started");

        uint256 vestedAmount =
            allocation.amount * (block.timestamp - allocation.vestingStart) / (allocation.vestingDuration);
        uint256 unreleasedAmount = vestedAmount - token.balanceOf(address(this));
        require(unreleasedAmount > 0, "No tokens to release");

        token.safeTransfer(allocation.recipient, unreleasedAmount);
    }
}
