// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract DeployChainlinkPriceOracle is Script {
    function run() external {
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

        // Deploy the new contract
        address newImpl = address(new ChainlinkPriceOracle());
        console.log("ChainlinkPriceOracle implementation deployed at: %s", newImpl);

        // upgrade proxy if on a fork
        if (isFork) {
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.CHAINLINK_ORACLE_PROXY), newImpl);
        }

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
