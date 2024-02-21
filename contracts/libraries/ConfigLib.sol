// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

library ConfigLib {
    function deployImpl() internal returns (address implementation) {
        // Deploy new implementation contract
        implementation = address(new LRTConfig());
        console.log("LRTConfig implementation deployed at: %s", implementation);
    }

    function deployProxy(
        address implementation,
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory
    )
        internal
        returns (LRTConfig config)
    {
        address proxy = proxyFactory.create(implementation, address(proxyAdmin), LRTConstants.SALT);
        console.log("LRTConfig proxy deployed at: ", proxy);

        config = LRTConfig(proxy);
    }

    function initialize(LRTConfig config, address adminAddress, address primeETHAddress) internal {
        // initialize new LRTConfig contract
        address stETH = block.chainid == 1 ? Addresses.STETH_TOKEN : AddressesGoerli.STETH_TOKEN;
        address ethx = block.chainid == 1 ? Addresses.ETHX_TOKEN : AddressesGoerli.ETHX_TOKEN;

        config.initialize(adminAddress, stETH, ethx, primeETHAddress);
    }

    function upgrade(address proxyAddress, address newImpl) internal returns (LRTConfig) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesGoerli.PROXY_ADMIN;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded LRTConfig proxy %s to new implementation %s", proxyAddress, newImpl);

        return LRTConfig(payable(proxyAddress));
    }
}
