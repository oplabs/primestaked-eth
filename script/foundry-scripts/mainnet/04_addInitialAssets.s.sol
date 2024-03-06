// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { AddAssetsLib } from "contracts/libraries/AddAssetsLib.sol";

contract AddInitialAssets is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_146_000;
    }

    function _fork() internal override {
        vm.startPrank(Addresses.INITIAL_DEPLOYER);

        // add manager role to the deployer
        LRTConfig lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        lrtConfig.grantRole(LRTConstants.MANAGER, msg.sender);

        AddAssetsLib.addOETH();
        AddAssetsLib.addStETH();
        AddAssetsLib.addETHx();
        AddAssetsLib.addSfrxETH();
        AddAssetsLib.addMEth();

        vm.stopPrank();
    }
}
