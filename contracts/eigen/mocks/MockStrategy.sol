// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockStrategy {
    IERC20 public underlyingToken_;
    uint256 public mockUserUnderlyingViewBal;

    constructor(address _underlyingToken, uint256 _mockUserUnderlyingViewBal) {
        underlyingToken_ = IERC20(_underlyingToken);

        mockUserUnderlyingViewBal = _mockUserUnderlyingViewBal;
    }

    function underlyingToken() external view returns (IERC20) {
        return underlyingToken_;
    }

    function userUnderlyingView(address) external view returns (uint256) {
        return mockUserUnderlyingViewBal;
    }

    function sharesToUnderlyingView(uint256 amountShares) external view returns (uint256) {
        return mockUserUnderlyingViewBal;
    }
}
