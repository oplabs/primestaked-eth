// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IPrimeETH is IERC20 {
    function mint(address account, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function pause() external;

    function unpause() external;

    function updateLRTConfig(address _lrtConfig) external;
}
