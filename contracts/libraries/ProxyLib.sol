// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

library ProxyLib {
    function getProxyAdmin() internal returns (ProxyAdmin proxyAdmin) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;
        proxyAdmin = ProxyAdmin(proxyAdminAddress);
    }

    function getProxyFactory() internal returns (ProxyFactory proxyFactory) {
        address proxyFactoryAddress = block.chainid == 1 ? Addresses.PROXY_FACTORY : AddressesHolesky.PROXY_FACTORY;
        proxyFactory = ProxyFactory(proxyFactoryAddress);
    }
}
