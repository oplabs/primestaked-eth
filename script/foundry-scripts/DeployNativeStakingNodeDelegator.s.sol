// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { Vm } from "forge-std/Test.sol";

import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

contract DeployNativeStakingNodeDelegator is Script {
    NodeDelegator public nodeDelegatorProxy2;
    LRTConfig public lrtConfigProxy;
    ProxyFactory public proxyFactory;
    LRTDepositPool public lrtDepositPoolProxy;
    address[] public newNodeDelegatorContracts;
    address public eigenpodManagerAddress;
    address public operatorAddress;

    function _setUpByAdmin() internal {
        // ----------- callable by admin ----------------

        // add nodeDelegators to LRTDepositPool queue
        // TODO uncomment
        newNodeDelegatorContracts.push(address(nodeDelegatorProxy2));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(newNodeDelegatorContracts);

        // set the Eigen Pod Manager address to LRT constants
        lrtConfigProxy.setContract(LRTConstants.EIGEN_POD_MANAGER, eigenpodManagerAddress);
        lrtConfigProxy.grantRole(LRTConstants.OPERATOR_ROLE, operatorAddress);

        nodeDelegatorProxy2.createEigenPod();
    }

    function run() external {
        address proxyAdminAddress;
        bool isFork = vm.envOr("IS_FORK", false);

        if (block.chainid == 1) {
            proxyAdminAddress = Addresses.PROXY_ADMIN;
            lrtConfigProxy = LRTConfig(Addresses.LRT_CONFIG);
            lrtDepositPoolProxy = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
            proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
            eigenpodManagerAddress = Addresses.EIGEN_POD_MANAGER;
            operatorAddress = Addresses.OPERATOR_ROLE;

            if (isFork) {
                address mainnetProxyOwner = Addresses.PROXY_OWNER;
                console.log("Running deploy on fork impersonating: %s", mainnetProxyOwner);
                vm.startPrank(mainnetProxyOwner);
            } else {
                console.log("Deploying on mainnet deployer: %s", msg.sender);
                uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
                vm.startBroadcast(deployerPrivateKey);
            }
        }
        // Goerli
        else if (block.chainid == 5) {
            eigenpodManagerAddress = AddressesGoerli.EIGEN_POD_MANAGER;
            proxyAdminAddress = AddressesGoerli.PROXY_ADMIN;
            lrtConfigProxy = LRTConfig(AddressesGoerli.LRT_CONFIG);
            proxyFactory = ProxyFactory(AddressesGoerli.PROXY_FACTORY);
            lrtDepositPoolProxy = LRTDepositPool(AddressesGoerli.LRT_DEPOSIT_POOL);
            operatorAddress = msg.sender;

            console.log("Deploying on Gorli deployer: %s", msg.sender);
            uint256 deployerPrivateKey = vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
        } else {
            revert("Not Mainnet or Goerli");
        }

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));

        address nodeDelegatorImplementation = address(new NodeDelegator());
        nodeDelegatorProxy2 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));

        // init NodeDelegator
        nodeDelegatorProxy2.initialize(address(lrtConfigProxy));

        console.log("Native staking node delegator (proxy) deployed at: ", address(nodeDelegatorProxy2));

        _setUpByAdmin();
        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
