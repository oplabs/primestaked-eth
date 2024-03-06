// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

// Deploy new DepositPool and NodeDelegator contracts
// PR https://github.com/oplabs/primestaked-eth/pull/26
// Multisig txs
// https://etherscan.io/tx/0xcd6b20739331b3dfe9118f55d5f27be9c1f31bc901949433b84f9a8b9fea9fd1
// https://etherscan.io/tx/0xd8c1abbf0cba073deb061580fddb1aac11a7f7104c335bafce497fa3e20a36f9
contract UpgradeDepositPoolNodeDelegator is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_158_908;
    }

    address newDepositPoolImpl;
    address newNodeDelegatorLibImpl;

    function _execute() internal override {
        newDepositPoolImpl = DepositPoolLib.deployImpl();
        newNodeDelegatorLibImpl = NodeDelegatorLib.deployImpl();
    }

    function _fork() internal override {
        // The proxy owner was the multisig wallet
        vm.startPrank(Addresses.PROXY_OWNER);

        // Upgrade the proxies
        LRTDepositPool depositPool = DepositPoolLib.upgrade(newDepositPoolImpl);
        NodeDelegator nodeDelegator = NodeDelegatorLib.upgrade(Addresses.NODE_DELEGATOR, newNodeDelegatorLibImpl);

        // Opt in for OETH rebasing
        depositPool.optIn(Addresses.OETH_TOKEN);
        nodeDelegator.optIn(Addresses.OETH_TOKEN);

        vm.stopPrank();
    }
}
