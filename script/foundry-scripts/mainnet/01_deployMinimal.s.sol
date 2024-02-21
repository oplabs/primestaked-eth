// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract DeployMinimal is BaseMainnetScript {
    LRTConfig public lrtConfigProxy;

    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_138_974;
    }

    function _execute() internal override {
        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));
        ProxyFactory proxyFactory = new ProxyFactory();
        ProxyAdmin proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        address deployerAddress = proxyAdmin.owner();

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

        // deploy implementation contracts
        address lrtConfigImplementation = address(new LRTConfig());
        address primeETHImplementation = address(new PrimeStakedETH());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTConfig implementation deployed at: ", lrtConfigImplementation);
        console.log("PrimeStakedETH implementation deployed at: ", primeETHImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them
        lrtConfigProxy = LRTConfig(proxyFactory.create(address(lrtConfigImplementation), address(proxyAdmin), salt));

        // set up LRTConfig init params
        address predictedPRETHAddress = proxyFactory.computeAddress(primeETHImplementation, address(proxyAdmin), salt);
        console.log("predictedPRETHAddress: ", predictedPRETHAddress);
        // init LRTConfig
        // the initialize config supports only 2 LSTs. we will add the others post deployment
        lrtConfigProxy.initialize(deployerAddress, Addresses.STETH_TOKEN, Addresses.ETHX_TOKEN, predictedPRETHAddress);

        PrimeStakedETH PRETHProxy =
            PrimeStakedETH(proxyFactory.create(address(primeETHImplementation), address(proxyAdmin), salt));
        // init PrimeStakedETH
        PRETHProxy.initialize(address(lrtConfigProxy));

        console.log("LRTConfig proxy deployed at: ", address(lrtConfigProxy));
        console.log("PrimeStakedETH proxy deployed at: ", address(PRETHProxy));

        // Called by the admin which at this time is the deployer
        setUpByAdmin(deployerAddress);
    }

    function setUpByAdmin(address deployerAddress) private {
        // add oracle to LRT config
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, deployerAddress);
    }
}
