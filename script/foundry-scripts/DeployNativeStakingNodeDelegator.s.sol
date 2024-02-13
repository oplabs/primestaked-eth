// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { Vm } from "forge-std/Test.sol";
import { TestHelper } from './utils/TestHelper.sol';

import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

contract DeployNativeStakingNodeDelegator is Script, TestHelper {
    NodeDelegator public nodeDelegatorProxy2;
    LRTConfig public lrtConfig;
    ProxyFactory public proxyFactory;
    LRTDepositPool public lrtDepositPool;
    ProxyAdmin public proxyAdmin;
    address[] public newNodeDelegatorContracts;
    address public eigenpodManagerAddress;
    address public operatorAddress;

    function _setUpByAdmin() internal {
        // ----------- callable by admin ----------------

        // add nodeDelegators to LRTDepositPool queue
        newNodeDelegatorContracts.push(address(nodeDelegatorProxy2));
        lrtDepositPool.addNodeDelegatorContractToQueue(newNodeDelegatorContracts);

        // set the Eigen Pod Manager address to LRT constants
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, eigenpodManagerAddress);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, operatorAddress);

        nodeDelegatorProxy2.createEigenPod();
    }

    function run() external {
        preRun();
        (
            proxyFactory,
            proxyAdmin,
            lrtConfig,,
            lrtDepositPool,
            ,,,,
        ) = getAddresses();

        if (block.chainid == 1) {
            eigenpodManagerAddress = Addresses.EIGEN_POD_MANAGER;
            operatorAddress = Addresses.OPERATOR_ROLE;
        } else if (block.chainid == 5) {
            eigenpodManagerAddress = AddressesGoerli.EIGEN_POD_MANAGER;
            operatorAddress = AddressesGoerli.OPERATOR_ROLE;
        }

        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));

        address nodeDelegatorImplementation = address(new NodeDelegator());
        nodeDelegatorProxy2 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));

        // init NodeDelegator
        nodeDelegatorProxy2.initialize(address(lrtConfig));

        console.log("Native staking node delegator (proxy) deployed at: ", address(nodeDelegatorProxy2));

        _setUpByAdmin();
        postRun();
    }
}
