// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

library NodeDelegatorLib {
    function deploy() internal returns (address newImpl) {
        // Deploy the new contract
        newImpl = address(new NodeDelegator());
        console.log("NodeDelegator implementation deployed at: %s", newImpl);
    }

    function deployInit() internal returns (NodeDelegator nodeDelegator) {
        // Deploy the new contract
        address nodeDelegatorImpl = address(new NodeDelegator());
        console.log("NodeDelegator implementation deployed at: %s", nodeDelegatorImpl);

        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesGoerli.PROXY_ADMIN;
        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));

        address proxyFactoryAddress = block.chainid == 1 ? Addresses.PROXY_FACTORY : AddressesGoerli.PROXY_FACTORY;
        address nodeDelegatorProxy =
            ProxyFactory(proxyFactoryAddress).create(nodeDelegatorImpl, proxyAdminAddress, salt);
        nodeDelegator = NodeDelegator(payable(nodeDelegatorProxy));

        // init new NodeDelegator
        address lrtConfigProxy = block.chainid == 1 ? Addresses.LRT_CONFIG : AddressesGoerli.LRT_CONFIG;
        nodeDelegator.initialize(lrtConfigProxy);

        console.log("Native staking node delegator (proxy) deployed at: ", nodeDelegatorProxy);
    }

    function upgrade(address proxyAddress, address newImpl) internal returns (NodeDelegator) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesGoerli.PROXY_ADMIN;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded NodeDelegator proxy %s to new implementation %s", proxyAddress, newImpl);

        return NodeDelegator(payable(proxyAddress));
    }
}
