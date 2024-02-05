// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

// import contract to be upgraded
// e.g. import "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";

contract UpgradeDepositPoolNodeDelegator is Script {
    ProxyAdmin public proxyAdmin;

    function run() public {
        if (block.chainid != 1) {
            revert("Not Mainnet");
        }

        bool isFork = vm.envOr("IS_FORK", false);
        if (isFork) {
            address mainnetProxyOwner = Addresses.PROXY_OWNER;
            console.log("Running deploy on fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            console.log("Deploying on mainnet deployer: %s", msg.sender);
            vm.startBroadcast();
        }

        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        // Deploy the new Deposit Pool contract
        address newDepositPoolImpl = address(new LRTDepositPool());
        console.log("LRTDepositPool implementation deployed at: %s", newDepositPoolImpl);
        // upgrade proxy if on a fork
        if (isFork) {
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.LRT_DEPOSIT_POOL), newDepositPoolImpl);
        }

        // Deploy the new Deposit Pool contract
        address newNodeDelegatorImpl = address(new NodeDelegator());
        console.log("NodeDelegator implementation deployed at: %s", newNodeDelegatorImpl);
        // upgrade proxy if on a fork
        if (isFork) {
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.NODE_DELEGATOR), newNodeDelegatorImpl);
        }

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
