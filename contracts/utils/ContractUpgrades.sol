// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ContractUpgrades is Test {
    function upgradeDepositPool() internal {
        LRTDepositPool newImpl = new LRTDepositPool();

        vm.prank(Addresses.PROXY_OWNER);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.LRT_DEPOSIT_POOL), address(newImpl)
        );
    }

    function upgradeNodeDelegator() internal {
        NodeDelegator newImpl = new NodeDelegator();

        vm.prank(Addresses.PROXY_OWNER);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.NODE_DELEGATOR), address(newImpl)
        );
    }

    function upgradeOracle() internal {
        LRTOracle newImpl = new LRTOracle();

        vm.prank(Addresses.PROXY_OWNER);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(ITransparentUpgradeableProxy(Addresses.LRT_ORACLE), address(newImpl));
    }

    function upgradeChainlinkPriceOracle() internal {
        ChainlinkPriceOracle newImpl = new ChainlinkPriceOracle();

        vm.prank(Addresses.PROXY_OWNER);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.CHAINLINK_ORACLE_PROXY), address(newImpl)
        );
    }
}
