// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

library DepositPoolLib {
    function deploy() internal returns (address newImpl) {
        // Deploy the new contract
        newImpl = address(new LRTDepositPool());
        console.log("LRTDepositPool implementation deployed at: %s", newImpl);
    }

    function upgrade(address newImpl) internal returns (LRTDepositPool) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesGoerli.PROXY_ADMIN;
        address proxyAddress = block.chainid == 1 ? Addresses.LRT_DEPOSIT_POOL : AddressesGoerli.LRT_DEPOSIT_POOL;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        console.log("Proxy admin owner %s", proxyAdmin.owner());

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded LRTDepositPool proxy %s to new implementation %s", proxyAddress, newImpl);

        return LRTDepositPool(proxyAddress);
    }
}
