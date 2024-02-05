// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract UpdateDepositLimits is Script {
    uint256 maxDeposits = 100_000 ether;

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

        LRTConfig lrtConfig = LRTConfig(Addresses.LRT_CONFIG);

        lrtConfig.updateAssetDepositLimit(Addresses.OETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.SFRXETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.METH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.STETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.RETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.SWETH_TOKEN, maxDeposits);
        lrtConfig.updateAssetDepositLimit(Addresses.ETHX_TOKEN, maxDeposits);
    }
}
