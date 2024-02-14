// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { AddAssetsLib } from "contracts/libraries/AddAssetsLib.sol";

contract AddMoreAssets is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_150_615;
    }

    function _fork() internal override {
        vm.startPrank(Addresses.INITIAL_DEPLOYER);

        AddAssetsLib.addRETH();
        AddAssetsLib.addSwETH();

        vm.stopPrank();
    }
}
