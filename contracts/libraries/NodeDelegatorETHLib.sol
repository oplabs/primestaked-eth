// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { NodeDelegatorETH } from "contracts/NodeDelegatorETH.sol";
import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

library NodeDelegatorETHLib {
    function deployImpl() internal returns (address implementation) {
        address wethAddress = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesHolesky.WETH_TOKEN;

        // Deploy the new contract
        implementation = address(new NodeDelegatorETH(wethAddress));
        console.log("NodeDelegatorETH implementation deployed at: %s", implementation);
    }

    function deployProxy(
        address implementation,
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory,
        uint256 saltIndex
    )
        internal
        returns (NodeDelegatorETH nodeDelegator)
    {
        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked-nodeDelegator", saltIndex));
        address proxy = proxyFactory.create(implementation, address(proxyAdmin), salt);
        console.log("NodeDelegatorETH proxy deployed at: ", proxy);

        nodeDelegator = NodeDelegatorETH(payable(proxy));
    }

    function initialize(NodeDelegatorETH nodeDelegator, LRTConfig config) internal {
        nodeDelegator.initialize(address(config));
    }

    function deployInit(uint256 saltIndex) internal returns (NodeDelegatorETH nodeDelegator) {
        address wethAddress = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesHolesky.WETH_TOKEN;

        // Deploy the new contract
        address nodeDelegatorImpl = address(new NodeDelegatorETH(wethAddress));
        console.log("NodeDelegatorETH implementation deployed at: %s", nodeDelegatorImpl);

        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;
        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked-nodeDelegator", saltIndex));

        address proxyFactoryAddress = block.chainid == 1 ? Addresses.PROXY_FACTORY : AddressesHolesky.PROXY_FACTORY;
        address nodeDelegatorProxy =
            ProxyFactory(proxyFactoryAddress).create(nodeDelegatorImpl, proxyAdminAddress, salt);
        nodeDelegator = NodeDelegatorETH(payable(nodeDelegatorProxy));

        // init new NodeDelegatorETH
        address lrtConfigProxy = block.chainid == 1 ? Addresses.LRT_CONFIG : AddressesHolesky.LRT_CONFIG;
        nodeDelegator.initialize(lrtConfigProxy);

        console.log("Native staking node delegator (proxy) deployed at: ", nodeDelegatorProxy);
    }

    function upgrade(address proxyAddress, address newImpl) internal returns (NodeDelegatorETH) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded NodeDelegatorETH proxy %s to new implementation %s", proxyAddress, newImpl);

        return NodeDelegatorETH(payable(proxyAddress));
    }
}
