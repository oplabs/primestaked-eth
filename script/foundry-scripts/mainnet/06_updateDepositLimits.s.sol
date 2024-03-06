// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract UpdateDepositLimits is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_150_847;
    }

    function _fork() internal override {
        vm.startPrank(Addresses.INITIAL_DEPLOYER);

        LRTConfig lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        uint256 maxDeposits = 100_000 ether;
        lrtConfig.updateAssetDepositLimit(Addresses.OETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.SFRXETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.METH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.STETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.RETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.SWETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.ETHX_TOKEN, maxDeposits);

        vm.stopPrank();
    }
}
