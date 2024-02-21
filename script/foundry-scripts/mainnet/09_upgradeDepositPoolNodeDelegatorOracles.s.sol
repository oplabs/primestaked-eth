// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { OraclesLib } from "contracts/libraries/OraclesLib.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

// Upgrade LRTDepositPool, NodeDelegator, LRTOracle and ChainlinkPriceOracle contracts
// https://github.com/oplabs/primestaked-eth/pull/31
// Multisig txs
// https://etherscan.io/tx/0xad05809568f4fb7783014d4489ccd5cd90141c5582b8aec9652f89d37967f156
contract UpgradeDepositPoolNodeDelegatorOracles is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_172_239;
    }

    address newDepositPoolImpl;
    address newNodeDelegatorImpl;
    address newOracleImpl;
    address newChainlinkOracle;

    function _execute() internal override {
        newDepositPoolImpl = DepositPoolLib.deployImpl();
        newNodeDelegatorImpl = NodeDelegatorLib.deployImpl();
        newOracleImpl = OraclesLib.deployLRTOracleImpl();
        newChainlinkOracle = OraclesLib.deployChainlinkOracle();
    }

    function _fork() internal override {
        vm.startPrank(Addresses.PROXY_OWNER);
        // Upgrade the proxies
        DepositPoolLib.upgrade(newDepositPoolImpl);
        NodeDelegatorLib.upgrade(Addresses.NODE_DELEGATOR, newNodeDelegatorImpl);
        OraclesLib.upgradeLRTOracle(newOracleImpl);
        // OraclesLib.upgradeChainlinkOracle(newChainlinkOracle);
        vm.stopPrank();

        vm.startPrank(Addresses.ADMIN_ROLE);
        // move the Operator role from the multisig to the relayer
        LRTConfig config = LRTConfig(Addresses.LRT_CONFIG);
        config.grantRole(LRTConstants.OPERATOR_ROLE, Addresses.RELAYER);
        config.revokeRole(LRTConstants.OPERATOR_ROLE, Addresses.ADMIN_MULTISIG);
        vm.stopPrank();
    }
}
