// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockToken } from "./MockToken.sol";

contract MockYnEigen is MockToken {
    constructor(string memory name_, string memory symbol_) MockToken(name_, symbol_) { }

    function deposit(IERC20 asset, uint256 amount, address receiver) external returns (uint256) {
        asset.transferFrom(msg.sender, address(this), amount);

        _mint(receiver, amount);
    }
}
