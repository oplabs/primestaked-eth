// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockStrategy {
    IERC20 public underlyingToken_;
    uint256 public mockUserUnderlyingViewBal;
    uint256 public mockAssetsPerShare;

    constructor(address _underlyingToken, uint256 _mockUserUnderlyingViewBal, uint256 _mockAssetsPerShare) {
        underlyingToken_ = IERC20(_underlyingToken);

        mockUserUnderlyingViewBal = _mockUserUnderlyingViewBal;
        mockAssetsPerShare = _mockAssetsPerShare;
    }

    function underlyingToken() external view returns (IERC20) {
        return underlyingToken_;
    }

    function userUnderlyingView(address) external view returns (uint256) {
        return mockUserUnderlyingViewBal;
    }

    function sharesToUnderlyingView(uint256 amountShares) external view returns (uint256) {
        return amountShares * mockAssetsPerShare / 1e18;
    }

    function underlyingToShares(uint256 amountUnderlying) external view returns (uint256) {
        return amountUnderlying * 1e18 / mockAssetsPerShare;
    }
}
