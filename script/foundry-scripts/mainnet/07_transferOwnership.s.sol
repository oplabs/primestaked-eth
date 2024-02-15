// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { Addresses } from "contracts/utils/Addresses.sol";
import { BaseMainnetScript } from "./BaseMainnetScript.sol";

contract TransferOwnership is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_152_491;
    }

    function _execute() internal override {
        // Contracts that need to be transferred
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        LRTConfig lrtConfig = LRTConfig(Addresses.LRT_CONFIG);

        address currentProxyOwner = proxyAdmin.owner();
        console.log("Current owner of ProxyAdmin: ", currentProxyOwner);

        // Manager is gonna same as admin for now
        address multisig = Addresses.ADMIN_MULTISIG;

        /**
         * ################# Grant Permissions to Multi-sig
         */
        // LRTConfig
        lrtConfig.grantRole(LRTConstants.MANAGER, multisig);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, multisig);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, multisig);
        console.log("[LRTConfig] Manager, Operator & Admin permission granted to: ", multisig);

        /**
         * ################# Revoke Permissions for existing owner
         */
        lrtConfig.revokeRole(LRTConstants.MANAGER, currentProxyOwner);
        lrtConfig.revokeRole(LRTConstants.OPERATOR_ROLE, currentProxyOwner);
        lrtConfig.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, currentProxyOwner);
        console.log("[LRTConfig] Revoked roles from current owner");

        /**
         * ################# Transfer Ownership to multisig
         */
        proxyAdmin.transferOwnership(multisig);
        console.log("ProxyAdmin ownership transferred to: ", multisig);
    }
}
