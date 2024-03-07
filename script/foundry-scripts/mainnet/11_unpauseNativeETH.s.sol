// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";

contract UnpauseNativeETH is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_386_190;
    }

    function _execute() internal override {
        // The contracts were deployed in the previous 10_deployNativeETH script
    }

    function _fork() internal override {
        vm.startPrank(Addresses.ADMIN_MULTISIG);
        console.log("Impersonating multisig: %s", Addresses.ADMIN_MULTISIG);

        // Unpause to allow WETH deposits
        LRTDepositPool(Addresses.LRT_DEPOSIT_POOL).unpause();

        // Transfer remaining SSV to the NodeDelegator
        IERC20(Addresses.SSV_TOKEN).transfer(Addresses.NODE_DELEGATOR_NATIVE_STAKING, 90 ether);

        // Test a ether deposit via the Zapper
        PrimeZapper(payable(Addresses.PRIME_ZAPPER)).deposit{ value: 32 ether }(31 ether, "");

        vm.stopPrank();

        console.log("Completed fork function in deploy script");
    }
}
