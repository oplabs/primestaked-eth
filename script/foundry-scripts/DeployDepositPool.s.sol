// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

contract DeployDepositPool is Script {
    LRTConfig public lrtConfigProxy;
    ProxyFactory public proxyFactory;
    LRTDepositPool public lrtDepositPoolProxy;
    uint256 public minAmountToDeposit = 0.0001 ether;

    function setUpByAdmin() private {
        // ----------- callable by admin ----------------

        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));
        
        // add minter role to lrtDepositPool so it mints primeETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        // add min amount to deposit in LRTDepositPool
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function run() public {
        address proxyAdminAddress;
        bool isFork = vm.envOr("IS_FORK", false);

        if (block.chainid == 1) {
            lrtConfigProxy = LRTConfig(Addresses.LRT_CONFIG);
            lrtDepositPoolProxy = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));

            if (isFork) {
                address proxyAdminAddress = Addresses.PROXY_OWNER;
                console.log("Running deploy on fork impersonating: %s", proxyAdminAddress);
                vm.startPrank(proxyAdminAddress);
            } else {
                console.log("Deploying on mainnet deployer: %s", msg.sender);
                uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
                vm.startBroadcast(deployerPrivateKey);
            }
        } else if (block.chainid == 5) {
            proxyAdminAddress = 0x5Cc848d0333fa42A58aD346FD880CE7c5bD62c90;
            lrtConfigProxy = LRTConfig(0xAa62544784d28E9546820B5A46f2c346caB7d43A);
            proxyFactory = ProxyFactory(0x3A958C0C7cC87aC5A0d0cc5Ac3ddd6FE97F13AdD);

            console.log("Deploying on Gorli deployer: %s", msg.sender);
            uint256 deployerPrivateKey = vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
        } else {
            revert("Not Mainnet or Goerli");
        }

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Deploy the new implementation contract
        address newDepositPoolImpl = address(new LRTDepositPool());
        console.log("LRTDepositPool implementation deployed at: %s", newDepositPoolImpl);

        // upgrade proxy if on a fork
        if (isFork && block.chainid == 1) {
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.LRT_DEPOSIT_POOL), newDepositPoolImpl);

            // Test moving the Operator role from the multisig to the relayer
            LRTConfig config = LRTConfig(Addresses.LRT_CONFIG);
            config.grantRole(LRTConstants.OPERATOR_ROLE, Addresses.RELAYER);
            config.revokeRole(LRTConstants.OPERATOR_ROLE, Addresses.ADMIN_MULTISIG);
        } 
        // deploy a new deposit pool proxy
        else if (block.chainid == 5) {
            bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));

            lrtDepositPoolProxy = LRTDepositPool(
                payable(proxyFactory.create(address(newDepositPoolImpl), address(proxyAdmin), salt))
            );
            // init LRTDepositPool
            lrtDepositPoolProxy.initialize(address(lrtConfigProxy));

            //setUpByAdmin();

            console.log("Deposit pool proxy deployed at: ", address(lrtDepositPoolProxy));
        }

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
