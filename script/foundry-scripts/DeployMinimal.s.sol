// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TestHelper } from './utils/TestHelper.sol';

function getLSTs() view returns (address stETH, address ethx) {
    uint256 chainId = block.chainid;

    if (chainId == 1) {
        // mainnet
        stETH = Addresses.STETH_TOKEN;
        ethx = Addresses.ETHX_TOKEN;
    } else if (chainId == 5) {
        // goerli
        stETH = AddressesGoerli.STETH_TOKEN;
        ethx = AddressesGoerli.ETHX_TOKEN;
    } else {
        revert("Unsupported network");
    }
}

contract DeployMinimal is Script, TestHelper {
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    PrimeStakedETH public PRETHProxy;

    function setUpByAdmin() private {
        // ----------- callable by admin ----------------

        // grant manager role to the deployer
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, deployerAddress);
    }

    function run() external {
        preRun();

        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));
        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();

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
        (address stETH, address ethx) = getLSTs();
        address predictedPRETHAddress = proxyFactory.computeAddress(primeETHImplementation, address(proxyAdmin), salt);
        console.log("predictedPRETHAddress: ", predictedPRETHAddress);
        // init LRTConfig
        // the initialize config supports only 2 LSTs. we will add the others post deployment
        lrtConfigProxy.initialize(deployerAddress, stETH, ethx, predictedPRETHAddress);

        PRETHProxy = PrimeStakedETH(proxyFactory.create(address(primeETHImplementation), address(proxyAdmin), salt));
        // init PrimeStakedETH
        PRETHProxy.initialize(address(lrtConfigProxy));

        console.log("LRTConfig proxy deployed at: ", address(lrtConfigProxy));
        console.log("PrimeStakedETH proxy deployed at: ", address(PRETHProxy));

        // setup
        setUpByAdmin();

        postRun();
    }
}
