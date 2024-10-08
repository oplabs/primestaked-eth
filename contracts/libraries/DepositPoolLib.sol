// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

library DepositPoolLib {
    function deployImpl() internal returns (address implementation) {
        address wethAddress = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesHolesky.WETH_TOKEN;
        address withdrawAddress = block.chainid == 1 ? Addresses.OETH_TOKEN : AddressesHolesky.STETH_TOKEN;
        address ynLSDe = block.chainid == 1 ? Addresses.YN_LSD_E : AddressesHolesky.YN_LSD_E;
        address wOETH = block.chainid == 1 ? Addresses.WOETH : AddressesHolesky.WOETH;

        // Deploy the new contract
        implementation = address(new LRTDepositPool(wethAddress, withdrawAddress, wOETH, ynLSDe));
        console.log("LRTDepositPool implementation deployed at: %s", implementation);
    }

    function deployProxy(
        address implementation,
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory
    )
        internal
        returns (LRTDepositPool depositPool)
    {
        address proxy = proxyFactory.create(implementation, address(proxyAdmin), LRTConstants.SALT);
        console.log("LRTDepositPool proxy deployed at: ", proxy);

        depositPool = LRTDepositPool(proxy);
    }

    function initialize(LRTDepositPool depositPool, LRTConfig config) internal {
        depositPool.initialize(address(config));
    }

    function upgrade(address newImpl) internal returns (LRTDepositPool) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;
        address proxyAddress = block.chainid == 1 ? Addresses.LRT_DEPOSIT_POOL : AddressesHolesky.LRT_DEPOSIT_POOL;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        console.log("Proxy admin owner %s", proxyAdmin.owner());

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded LRTDepositPool proxy %s to new implementation %s", proxyAddress, newImpl);

        return LRTDepositPool(proxyAddress);
    }

    function addNodeDelegator(address nodeDelegatorProxy) internal {
        address depositPoolAddress = block.chainid == 1 ? Addresses.LRT_DEPOSIT_POOL : AddressesHolesky.LRT_DEPOSIT_POOL;
        LRTDepositPool depositPool = LRTDepositPool(depositPoolAddress);

        address[] memory nodeDelegatorContracts = new address[](1);
        nodeDelegatorContracts[0] = nodeDelegatorProxy;
        depositPool.addNodeDelegatorContractToQueue(nodeDelegatorContracts);
    }
}
