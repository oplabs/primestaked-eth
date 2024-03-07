pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOETH is IERC20 {
    function rebaseOptIn() external;

    function rebaseOptOut() external;
}
