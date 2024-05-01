// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";

contract deployProxyFactory is Script {
    uint256 internal constant MAX_DEPOSITS = 1000 ether;

    bool isForked;

    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

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
            console.log("Deploying on Holesky with deployer: %s", deployer);
        }

        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

        if (isForked) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
