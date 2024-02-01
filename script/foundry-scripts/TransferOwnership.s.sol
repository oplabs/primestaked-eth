// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract TransferOwnership is Script {
    address public proxyAdminOwner;
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;
    LRTConfig public lrtConfigProxy;
   
    function run() external {
        vm.startBroadcast();

        // IMPORTANT: Update config variables
        proxyAdmin = ProxyAdmin(0x60fF8354e9C0E78e032B7daeA8da2c3265287dBd);
        lrtConfigProxy = LRTConfig(0x5E598B1A8658a5a1434CEAA6988D43aeB028F430);
        // End of Config variables

        proxyAdminOwner = proxyAdmin.owner();
        console.log("Current owner of ProxyAdmin: ", proxyAdminOwner);

        uint256 chainId = block.chainid;
        address manager;
        address admin;

        if (chainId == 1) {
            // mainnet
            manager = 0xEc574b7faCEE6932014EbfB1508538f6015DCBb0;
            admin = 0xEc574b7faCEE6932014EbfB1508538f6015DCBb0;
        } else if (chainId == 5) {
            // goerli
            manager = proxyAdminOwner;
            admin = proxyAdminOwner;
        } else {
            revert("Unsupported network");
        }

        lrtConfigProxy.grantRole(LRTConstants.MANAGER, manager);
        lrtConfigProxy.revokeRole(LRTConstants.MANAGER, proxyAdminOwner);
        console.log("Manager permission granted to: ", manager);

        lrtConfigProxy.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin);
        lrtConfigProxy.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, proxyAdminOwner);
        proxyAdmin.transferOwnership(admin);

        console.log("ProxyAdmin ownership transferred to: ", admin);

        vm.stopBroadcast();
    }
}
