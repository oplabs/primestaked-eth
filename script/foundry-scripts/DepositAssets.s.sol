// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console2.sol";
import "forge-std/StdJson.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import { Addresses } from "contracts/utils/Addresses.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DepositAssets is Script {
    using stdJson for string;

    LRTDepositPool public depositPool;
    NodeDelegator public nodeDelegator;
    uint256 public constant NODE_DELEGATOR_INDEX = 0;

    uint256 public maxDepositAmount;

    error TransferToNodeDelegatorFailed();
    error DepositToELStrategyFailed();

    string internal TX_FILE = string.concat(vm.projectRoot(), "/data/tx.gen.csv");

    string outData = "";

    function run() external {
        if (block.chainid != 1) {
            revert("Not Mainnet");
        }

        unpauseAllStrategies();

        maxDepositAmount = vm.envUint("MAX_DEPOSIT_AMOUNT");
        if (maxDepositAmount == 0) {
            maxDepositAmount = type(uint256).max;
        }

        vm.startPrank(Addresses.MANAGER_ROLE);

        depositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        nodeDelegator = NodeDelegator(payable(Addresses.NODE_DELEGATOR));

        depositAssetToEL(Addresses.OETH_TOKEN);
        depositAssetToEL(Addresses.SFRXETH_TOKEN);
        depositAssetToEL(Addresses.METH_TOKEN);
        depositAssetToEL(Addresses.STETH_TOKEN);
        depositAssetToEL(Addresses.RETH_TOKEN);
        depositAssetToEL(Addresses.SWETH_TOKEN);
        depositAssetToEL(Addresses.ETHX_TOKEN);

        vm.writeFile(TX_FILE, outData);

        vm.stopPrank();
    }

    function depositAssetToEL(address asset) private {
        // Check balance of DepositPool
        uint256 balance = ERC20(asset).balanceOf(address(depositPool));

        if (balance < 1 ether) {
            // Skip when nothing to transfer
            return;
        }
        balance = Math.min(balance, maxDepositAmount);

        // Transfer to NodeDelegator
        console.log("Simulating transfer of %s assets to NodeDelegator: %s", balance, asset);

        // Build tx call
        bytes memory transferTxData =
            abi.encodeCall(depositPool.transferAssetToNodeDelegator, (NODE_DELEGATOR_INDEX, asset, balance));

        // Simulate it
        (bool success,) = address(depositPool).call(transferTxData);
        if (!success) {
            revert TransferToNodeDelegatorFailed();
        }

        // Deposit to EL strategy
        console.log("Simulating deposit of %s assets to EL Strategy: %s", balance, asset);

        // Build tx call
        bytes memory depositTxData = abi.encodeCall(nodeDelegator.depositAssetIntoStrategy, (asset));

        // Simulate it
        (success,) = address(nodeDelegator).call(depositTxData);

        if (!success) {
            revert DepositToELStrategyFailed();
        }

        outData = string.concat(
            outData,
            vm.toString(address(depositPool)),
            ",",
            vm.toString(transferTxData),
            "\n",
            vm.toString(address(nodeDelegator)),
            ",",
            vm.toString(depositTxData),
            "\n"
        );
    }

    function unpauseAllStrategies() private {
        vm.startPrank(Addresses.EIGEN_UNPAUSER);

        // IStrategy eigenStrategy = IStrategy(strategyAddress);
        IStrategy eigenStrategyManager = IStrategy(Addresses.EIGEN_STRATEGY_MANAGER);

        // Unpause deposits and withdrawals
        eigenStrategyManager.unpause(0);
        // eigenStrategy.unpause(0);

        vm.stopPrank();
    }
}
