// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract TestHelper is Script {

	function preRun() internal {
		bool isFork = vm.envOr("IS_FORK", false);
    if (block.chainid == 1) {
        if (isFork) {
            address mainnetProxyOwner = Addresses.PROXY_OWNER;
            console.log("Running deploy on fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
            console.log("Deploying on mainnet deployer: %s", msg.sender);
        }
    } else if (block.chainid == 5) {
        uint256 deployerPrivateKey = vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console.log("Deploying on Gorli");
    } else {
        revert("Not Mainnet or Goerli");
    }
	}

	function getAddresses() internal view 
		returns (
			ProxyFactory proxyFactory,
			ProxyAdmin proxyAdmin,
			LRTConfig lrtConfig,
			LRTOracle lrtOracle,
			LRTDepositPool lrtDepositPool,
			NodeDelegator nodeDelegator,
			NodeDelegator nodeDelegatorNativeStaking,
			address strategyManager,
			address stETHStrategy,
			address oethStrategy
		){

		if (block.chainid == 1) {
			proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
			proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
			lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
			lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
			lrtDepositPool = LRTDepositPool(Addresses.LRT_DEPOSIT_POOL);
			strategyManager = Addresses.EIGEN_STRATEGY_MANAGER;
			stETHStrategy = Addresses.STETH_EIGEN_STRATEGY;
			oethStrategy = Addresses.OETH_EIGEN_STRATEGY;
			nodeDelegator = NodeDelegator(payable(Addresses.NODE_DELEGATOR));
			nodeDelegatorNativeStaking = NodeDelegator(payable(Addresses.NODE_DELEGATOR_NATIVE_STAKING));
		} else if (block.chainid == 5) {
			proxyFactory = ProxyFactory(AddressesGoerli.PROXY_FACTORY);
			proxyAdmin = ProxyAdmin(AddressesGoerli.PROXY_ADMIN);
			lrtConfig = LRTConfig(AddressesGoerli.LRT_CONFIG);
			lrtOracle = LRTOracle(AddressesGoerli.LRT_ORACLE);
			lrtDepositPool = LRTDepositPool(AddressesGoerli.LRT_DEPOSIT_POOL);
			strategyManager = AddressesGoerli.EIGEN_STRATEGY_MANAGER;
			stETHStrategy = AddressesGoerli.STETH_EIGEN_STRATEGY;
			oethStrategy = AddressesGoerli.OETH_EIGEN_STRATEGY;
			nodeDelegator = NodeDelegator(payable(AddressesGoerli.NODE_DELEGATOR));
			nodeDelegatorNativeStaking = NodeDelegator(payable(AddressesGoerli.NODE_DELEGATOR_NATIVE_STAKING));
		} else {
        revert("Not Mainnet or Goerli");
    }
	}

	function postRun() internal {
		bool isFork = vm.envOr("IS_FORK", false);
    if (isFork) {
        vm.stopPrank();
    } else {
        vm.stopBroadcast();
    }
	}
}