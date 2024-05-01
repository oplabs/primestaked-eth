// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { ConfigLib } from "contracts/libraries/ConfigLib.sol";
import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";

contract RevokeRoles is Script {
    bool isForked;

    function run() external {
        if (block.chainid != 17_000) {
            revert("Not Holesky");
        }

        isForked = vm.envOr("IS_FORK", false);
        if (isForked) {
            address mainnetProxyOwner = AddressesHolesky.PROXY_OWNER;
            console.log("Running script on Holesky fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            uint256 deployerPrivateKey = vm.envUint("HOLESKY_DEPLOYER_PRIVATE_KEY");
            address deployer = vm.rememberKey(deployerPrivateKey);
            vm.startBroadcast(deployer);
            console.log("Using deployer: %s", deployer);
        }

        LRTConfig lrtConfig = ConfigLib.get();
        lrtConfig.revokeRole(LRTConstants.OPERATOR_ROLE, AddressesHolesky.DEPLOYER);
        lrtConfig.revokeRole(LRTConstants.MANAGER, AddressesHolesky.DEPLOYER);
        lrtConfig.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, AddressesHolesky.DEPLOYER);

        if (isForked) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
