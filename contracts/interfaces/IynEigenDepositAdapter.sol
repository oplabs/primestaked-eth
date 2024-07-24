// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Interface to Yield Nest's ynEigenDepositAdapter contract.
/// https://github.com/yieldnest/yieldnest-protocol/blob/feature/yneigen/test/integration/ynEIGEN/ynEigenDepositAdapter.t.sol#L46
interface IynEigenDepositAdapter {
    function deposit(IERC20 asset, uint256 amount, address receiver) external returns (uint256);
}
