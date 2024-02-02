// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// import contract to be upgraded
// e.g. import "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";

contract UpgradePrimeStakedToken is Script {
    ProxyAdmin public proxyAdmin;

    address public primeStakedETHProxy;
    address public newImplementation;

    function run() public {
        vm.startBroadcast(); // deployer must be the ProxyAdmin

        uint256 chainId = block.chainid;
        if (chainId == 1) {
            // Set the address from Minimal token deployment
            proxyAdmin = ProxyAdmin(0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758);
            // Set the address from Minimal token deployment
            primeStakedETHProxy = 0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615;
            newImplementation = address(new PrimeStakedETH());
        } else if (chainId == 5) {
            // goerli
            proxyAdmin = ProxyAdmin(0x22b65a789d3778c0bA1A5bc7C01958e657703fA8);
            primeStakedETHProxy = 0xA265e2387fc0da67CB43eA6376105F3Df834939a;
            newImplementation = address(new PrimeStakedETH());
        } else {
            revert("Unsupported network");
        }

        // upgrade contract
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(primeStakedETHProxy), newImplementation);

        vm.stopBroadcast();
    }
}
