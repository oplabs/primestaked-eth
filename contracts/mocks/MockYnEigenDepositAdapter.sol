// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MockToken } from "./MockToken.sol";

contract MockYnEigenDepositAdapter {
    address public ynLSDe;

    constructor(address _ynLSDe) {
        ynLSDe = _ynLSDe;
    }

    function deposit(IERC20 asset, uint256 amount, address receiver) external returns (uint256) {
        asset.transferFrom(msg.sender, address(this), amount);

        MockToken(ynLSDe).mint(receiver, amount);
    }
}
