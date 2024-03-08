// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { OraclesLib } from "contracts/libraries/OraclesLib.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { AddAssetsLib } from "contracts/libraries/AddAssetsLib.sol";
import { PrimeZapperLib } from "contracts/libraries/PrimeZapperLib.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

contract DeployNativeETH is BaseMainnetScript {
    address newDepositPoolImpl;
    address newNodeDelegator1Impl;
    NodeDelegator newNodeDelegator2;
    address wethOracleProxy;

    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_379_670;
    }

    function _execute() internal override {
        // Deploy new NodeDelegator with proxy and initialize it
        // This will be done via the Defender Relayer for mainnet but is left in here for fork testing
        newNodeDelegator2 = NodeDelegatorLib.deployInit(1);

        // Deploy new LTRDepositPool implementation
        newDepositPoolImpl = DepositPoolLib.deployImpl();

        // Deploy a new implementation of NodeDelegator
        newNodeDelegator1Impl = NodeDelegatorLib.deployImpl();

        // Deploy new WETH oracle
        wethOracleProxy =
            OraclesLib.deployInitWETHOracle(ProxyAdmin(Addresses.PROXY_ADMIN), ProxyFactory(Addresses.PROXY_FACTORY));

        // Deploy new Prime Zapper
        PrimeZapperLib.deploy();
    }

    function _fork() internal override {
        console.log("Current contract ", address(this));
        // Upgrade proxies
        vm.startPrank(Addresses.PROXY_OWNER);
        console.log("Impersonating proxy admin owner: %s", Addresses.PROXY_OWNER);
        DepositPoolLib.upgrade(newDepositPoolImpl);
        // Upgrade the old NodeDelegator to new implementation
        NodeDelegatorLib.upgrade(Addresses.NODE_DELEGATOR, newNodeDelegator1Impl);
        vm.stopPrank();

        vm.startPrank(Addresses.MANAGER_ROLE);
        console.log("Impersonating Manager: %s", Addresses.MANAGER_ROLE);
        AddAssetsLib.addWETHManager();
        vm.stopPrank();

        vm.startPrank(Addresses.ADMIN_ROLE);
        console.log("Impersonating Admin: %s", Addresses.ADMIN_ROLE);
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
        console.log("Impersonating Manager: %s", Addresses.MANAGER_ROLE);

        // Start the event recorder
        vm.recordLogs();

        // Create an EigenPod attached to the NodeDelegator
        newNodeDelegator2.createEigenPod();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        console.log("EigenPod");
        console.logBytes32(entries[3].topics[1]);
        console.log("PodOwner = NodeDelegator");
        console.logBytes32(entries[3].topics[2]);
        assert(entries[3].topics[0] == keccak256("EigenPodCreated(address,address)"));

        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.OETH_TOKEN, 0);
        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.STETH_TOKEN, 0);
        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.ETHX_TOKEN, 0);
        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.SWETH_TOKEN, 0);
        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.RETH_TOKEN, 0);
        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.SFRXETH_TOKEN, 0);
        LRTConfig(Addresses.LRT_CONFIG).updateAssetDepositLimit(Addresses.METH_TOKEN, 0);

        vm.stopPrank();

        vm.startPrank(Addresses.ADMIN_MULTISIG);
        console.log("Impersonating multisig: %s", Addresses.ADMIN_MULTISIG);

        // Transfer some SSV to the NodeDelegator
        IERC20(Addresses.SSV_TOKEN).transfer(address(newNodeDelegator2), 20e18);

        vm.stopPrank();

        console.log("Completed fork function in deploy script");
    }
}
