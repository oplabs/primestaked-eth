// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";

contract DeployOracles is Script {
    ProxyFactory public proxyFactory;
    address public proxyAdmin;
    address public lrtConfig;

    function run() external {
        if (block.chainid != 1) {
            revert("Not Mainnet");
        }

        lrtConfig = 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF;
        proxyFactory = ProxyFactory(0x279b272E8266D2fd87e64739A8ecD4A5c94F953D);
        proxyAdmin = 0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758;

        console.log("Deployer: %s", msg.sender);

        deployChainlinkOracle();
        deployOETHOracle();
    }

    function deployChainlinkOracle() private {
        // Deploy ChainlinkPriceOracle
        address implContract = address(new ChainlinkPriceOracle());
        console.log("ChainlinkPriceOracle deployed at: %s", implContract);

        // Deploy ChainlinkPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("ChainlinkPriceOracleProxy")));
        console.log("ChainlinkPriceOracleProxy deployed at: %s", proxy);

        // Initialize ChainlinkPriceOracleProxy
        ChainlinkPriceOracle(proxy).initialize(lrtConfig);
        console.log("Initialized ChainlinkPriceOracleProxy");
    }

    function deployOETHOracle() private {
        address oeth = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;

        // Deploy OETHPriceOracle
        address implContract = address(new OETHPriceOracle(oeth));
        console.log("OETHPriceOracle deployed at: %s", implContract);

        // Deploy OETHPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("OETHPriceOracleProxy")));
        console.log("OETHPriceOracleProxy deployed at: %s", proxy);
    }
}
