// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

contract DeployDepositPool is Script {
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
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
        }

        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        // Deploy the new implementation contract
        address newDepositPoolImpl = address(new LRTDepositPool());
        console.log("LRTDepositPool implementation deployed at: %s", newDepositPoolImpl);

        // upgrade proxy if on a fork
        if (isFork) {
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.LRT_DEPOSIT_POOL), newDepositPoolImpl);

            // Test moving the Operator role from the multisig to the relayer
            LRTConfig config = LRTConfig(Addresses.LRT_CONFIG);
            config.grantRole(LRTConstants.OPERATOR_ROLE, Addresses.RELAYER);
            config.revokeRole(LRTConstants.OPERATOR_ROLE, Addresses.ADMIN_MULTISIG);
        }

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
