// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { AddressesHolesky } from "contracts/utils/Addresses.sol";

contract UpgradeNodeDelegators is Script {
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

        // Deploy new DelegatorNode implementation
        address nodeImpl = NodeDelegatorLib.deployImpl();

        if (isForked) {
            // Upgrade the proxy contracts
            NodeDelegatorLib.upgrade(AddressesHolesky.NODE_DELEGATOR, nodeImpl);
            NodeDelegatorLib.upgrade(AddressesHolesky.NODE_DELEGATOR_NATIVE_STAKING, nodeImpl);

            vm.stopPrank();
        } else {
            // use Hardhat task with Defender Relayer for Holesky network
            vm.stopBroadcast();
        }
    }
}
