// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// import contract to be upgraded
// e.g. import "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";

contract UpgradePimeStakedToken is Script {
    ProxyAdmin public proxyAdmin;

    address public primeStakedETHProxy;
    address public newImplementation;

    function run() public {
        vm.startBroadcast(); // deployer must be the ProxyAdmin

        uint256 chainId = block.chainid;
        if (chainId == 1) {
            // mainnet
            // delete once variables are set
            revert("proxyAdmin & primeStakedETHProxy mainnet addresses not configured");
            // Set the address from Minimal token deployment
            proxyAdmin = ProxyAdmin(address(0));
            // Set the address from Minimal token deployment
            primeStakedETHProxy = address(0);
            newImplementation = address(new PrimeStakedETH());
        } else if (chainId == 5) {
            // goerli
            proxyAdmin = ProxyAdmin(0x49109629aC1deB03F2e9b2fe2aC4a623E0e7dfDC);
            primeStakedETHProxy = 0x9DCEE73a022615e78f380a58879D1C278ea38383; // example NodeDelegatorProxy1
            newImplementation = address(new PrimeStakedETH());
        } else {
            revert("Unsupported network");
        }

        // upgrade contract
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(primeStakedETHProxy), newImplementation);

        vm.stopBroadcast();
    }
}
