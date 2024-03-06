// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

library PrimeStakedETHLib {
    function deployImpl() internal returns (address implementation) {
        // Deploy the new contract
        implementation = address(new PrimeStakedETH());
        console.log("PrimeStakedETH implementation deployed at: %s", implementation);
    }

    function deployProxy(
        address implementation,
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory
    )
        internal
        returns (PrimeStakedETH primeETH)
    {
        address proxy = proxyFactory.create(implementation, address(proxyAdmin), LRTConstants.SALT);
        console.log("PrimeStakedETH proxy deployed at: ", proxy);

        primeETH = PrimeStakedETH(proxy);
    }

    function initialize(PrimeStakedETH primeETH, LRTConfig config) internal {
        primeETH.initialize(address(config));
    }

    function upgrade(address newImpl) internal returns (PrimeStakedETH) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesGoerli.PROXY_ADMIN;
        address proxyAddress = block.chainid == 1 ? Addresses.PRIME_STAKED_ETH : AddressesGoerli.PRIME_STAKED_ETH;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded PrimeStakedETH proxy %s to new implementation %s", proxyAddress, newImpl);

        return PrimeStakedETH(proxyAddress);
    }
}
