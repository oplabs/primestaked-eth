// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ContractUpgrades is Test {
    function upgradeDepositPool() internal {
        LRTDepositPool newLrtDepositPool = new LRTDepositPool();

        vm.prank(Addresses.PROXY_OWNER);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.LRT_DEPOSIT_POOL), address(newLrtDepositPool)
        );
    }

    function upgradeNodeDelegator() internal {
        NodeDelegator newNodeDelegator = new NodeDelegator();

        vm.prank(Addresses.PROXY_OWNER);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.NODE_DELEGATOR), address(newNodeDelegator)
        );
    }
}
