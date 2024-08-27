// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

///  Yield Nest's EigenLayer vault. eg ynLSDe for ETH
interface IynEigen {
    function deposit(IERC20 asset, uint256 amount, address receiver) external returns (uint256 shares);
}
