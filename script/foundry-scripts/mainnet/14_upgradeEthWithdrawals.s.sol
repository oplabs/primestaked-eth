// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { NodeDelegatorLSTLib } from "contracts/libraries/NodeDelegatorLSTLib.sol";
import { NodeDelegatorETHLib } from "contracts/libraries/NodeDelegatorETHLib.sol";
import { OraclesLib } from "contracts/libraries/OraclesLib.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { AddAssetsLib } from "contracts/libraries/AddAssetsLib.sol";
import { PrimeZapperLib } from "contracts/libraries/PrimeZapperLib.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

contract UpgradeEthWithdrawals is BaseMainnetScript {
    address newNodeDelegatorLSTImpl;
    address newNodeDelegatorETHImpl;

    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 20_489_772;
    }

    function _execute() internal override {
        console.log("Running deploy script UpgradeEthWithdrawals");
        // Deploy a new NodeDelegator implementations
        newNodeDelegatorLSTImpl = NodeDelegatorLSTLib.deployImpl();
        newNodeDelegatorETHImpl = NodeDelegatorETHLib.deployImpl();
    }

    function _fork() internal override {
        // Upgrade proxies
        vm.startPrank(Addresses.PROXY_OWNER);
        console.log("Impersonating proxy admin owner: %s", Addresses.PROXY_OWNER);

        // Upgrade the NodeDelegators to new implementations
        NodeDelegatorLSTLib.upgrade(Addresses.NODE_DELEGATOR, newNodeDelegatorLSTImpl);
        NodeDelegatorETHLib.upgrade(Addresses.NODE_DELEGATOR_NATIVE_STAKING, newNodeDelegatorETHImpl);
        vm.stopPrank();

        vm.startPrank(Addresses.ADMIN_ROLE);
        console.log("Impersonating Admin: %s", Addresses.ADMIN_ROLE);
        // set EIGEN_DELAYED_WITHDRAWAL_ROUTER address in LRTConfig
        LRTConfig(Addresses.LRT_CONFIG).setContract(
            LRTConstants.EIGEN_DELAYED_WITHDRAWAL_ROUTER, Addresses.EIGEN_DELAYED_WITHDRAWAL_ROUTER
        );
        console.log("keccak256 EIGEN_DELAYED_WITHDRAWAL_ROUTER:");
        console.logBytes32(LRTConstants.EIGEN_DELAYED_WITHDRAWAL_ROUTER);
        console.log("Set EIGEN_DELAYED_WITHDRAWAL_ROUTER in LRTConfig to ", Addresses.EIGEN_DELAYED_WITHDRAWAL_ROUTER);

        vm.stopPrank();
    }
}
