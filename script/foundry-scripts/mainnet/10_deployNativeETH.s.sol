// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { OracleLib } from "contracts/libraries/OracleLib.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { AddAssetsLib } from "contracts/libraries/AddAssetsLib.sol";

contract DeployNativeETH is BaseMainnetScript {
    address newDepositPoolImpl;
    address wethOracleProxy;

    constructor() {
        // Will only execute script before this block number
        // deployBlockNum = ;
    }

    function _execute() internal override {
        // Deploy new LTRDepositPool implementation
        newDepositPoolImpl = DepositPoolLib.deploy();

        // Deploy new NodeDelegator with proxy and initialize it
        NodeDelegatorLib.deployInit();

        // Deploy new WETH oracle
        wethOracleProxy = OracleLib.deployWETHOracle();
    }

    function _fork() internal override {
        console.log("Current contract ", address(this));
        // Upgrade proxies
        vm.startPrank(Addresses.PROXY_OWNER);
        DepositPoolLib.upgrade(newDepositPoolImpl);
        vm.stopPrank();

        vm.startPrank(Addresses.MANAGER_ROLE);
        AddAssetsLib.addWETHManager();
        vm.stopPrank();

        vm.startPrank(Addresses.ADMIN_ROLE);
        AddAssetsLib.addWETHAdmin(wethOracleProxy);
        vm.stopPrank();
    }
}
