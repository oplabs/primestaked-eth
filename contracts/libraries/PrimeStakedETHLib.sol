// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

library DepositPoolLib {
    function deploy() internal returns (address newImpl) {
        // Deploy the new contract
        newImpl = address(new PrimeStakedETH());
        console.log("PrimeStakedETH implementation deployed at: %s", newImpl);
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
