// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IStrategy } from "contracts/eigen/interfaces/IStrategy.sol";

contract MockStrategyManager {
    mapping(address depositor => mapping(address strategy => uint256 shares)) public depositorStrategyShareBalances;

    address[] public strategies;

    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares) {
        token.transferFrom(msg.sender, address(strategy), amount);

        shares = strategy.underlyingToShares(amount);

        depositorStrategyShareBalances[msg.sender][address(strategy)] += shares;

        strategies.push(address(strategy));

        return shares;
    }

    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory) {
        uint256[] memory shares = new uint256[](strategies.length);
        IStrategy[] memory strategies_ = new IStrategy[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            strategies_[i] = IStrategy(strategies[i]);
            shares[i] = depositorStrategyShareBalances[depositor][strategies[i]];
        }

        return (strategies_, shares);
    }

    function stakerStrategyShares(address user, IStrategy strategy) external view returns (uint256 shares) {
        shares = depositorStrategyShareBalances[user][address(strategy)];
    }
}
