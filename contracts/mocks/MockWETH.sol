// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { MockToken } from "./MockToken.sol";
import { IWETH } from "../interfaces/IWETH.sol";

contract MockWETH is MockToken, IWETH {
    constructor(string memory name, string memory symbol) MockToken(name, symbol) { }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        payable(msg.sender).transfer(wad);
        _burn(msg.sender, wad);
        emit Withdrawal(msg.sender, wad);
    }
}
