// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { Addresses } from "contracts/utils/Addresses.sol";

abstract contract BaseMainnetScript is Script {
    uint256 public deployBlockNum = type(uint256).max;
    bool isForked = false;

    function run() external {
        if (block.chainid != 1) {
            revert("Not Mainnet");
        }
        // Will not execute script if after this block number
        if (block.number > deployBlockNum) {
            // console.log("Current block %s, script block %s", block.number, deployBlockNum);
            return;
        }

        isForked = vm.envOr("IS_FORK", false);
        if (isForked) {
            address mainnetProxyOwner = Addresses.PROXY_OWNER;
            console.log("Running script on fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            console.log("Deploying on mainnet deployer: %s", msg.sender);
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
        }

        _execute();

        if (isForked) {
            vm.stopPrank();
            _fork();
        } else {
            vm.stopBroadcast();
        }
    }

    function _execute() internal virtual { }

    function _fork() internal virtual { }
}
