// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { OracleLib } from "contracts/libraries/OracleLib.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { AddAssetsLib } from "contracts/libraries/AddAssetsLib.sol";

contract DeployNativeETH is BaseMainnetScript {
    address newDepositPoolImpl;
    address newNodeDelegator1Impl;
    NodeDelegator newNodeDelegator2;
    address wethOracleProxy;

    constructor() {
        // Will only execute script before this block number
        // deployBlockNum = ;
    }

    function _execute() internal override {
        // Deploy new LTRDepositPool implementation
        newDepositPoolImpl = DepositPoolLib.deploy();

        // Deploy a new implementation of NodeDelegator
        newNodeDelegator1Impl = NodeDelegatorLib.deploy();

        // Deploy new NodeDelegator with proxy and initialize it
        newNodeDelegator2 = NodeDelegatorLib.deployInit();

        // Deploy new WETH oracle
        wethOracleProxy = OracleLib.deployInitWETHOracle();
    }

    function _fork() internal override {
        console.log("Current contract ", address(this));
        // Upgrade proxies
        vm.startPrank(Addresses.PROXY_OWNER);
        DepositPoolLib.upgrade(newDepositPoolImpl);
        // Upgrade the old NodeDelegator to new implementation
        NodeDelegatorLib.upgrade(Addresses.NODE_DELEGATOR, newNodeDelegator1Impl);
        vm.stopPrank();

        vm.startPrank(Addresses.MANAGER_ROLE);
        AddAssetsLib.addWETHManager();
        vm.stopPrank();

        vm.startPrank(Addresses.ADMIN_ROLE);
        AddAssetsLib.addWETHAdmin(wethOracleProxy);
        // set EIGEN_POD_MANAGER address in LRTConfig
        LRTConfig(Addresses.LRT_CONFIG).setContract(LRTConstants.EIGEN_POD_MANAGER, Addresses.EIGEN_POD_MANAGER);

        // Set SSV contract addresses in LRTConfig
        LRTConfig(Addresses.LRT_CONFIG).setContract(LRTConstants.SSV_TOKEN, Addresses.SSV_TOKEN);
        LRTConfig(Addresses.LRT_CONFIG).setContract(LRTConstants.SSV_NETWORK, Addresses.SSV_NETWORK);

        // Approve the SSV Network to transfer SSV tokens from the second NodeDelegator
        NodeDelegator(newNodeDelegator2).approveSSV();

        // add new Node Delegator to the deposit pool
        DepositPoolLib.addNodeDelegator(address(newNodeDelegator2));
        vm.stopPrank();

        vm.startPrank(Addresses.MANAGER_ROLE);
        newNodeDelegator2.createEigenPod();
        vm.stopPrank();
    }
}
