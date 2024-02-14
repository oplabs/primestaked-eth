// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { MEthPriceOracle } from "contracts/oracles/MEthPriceOracle.sol";
import { SfrxETHPriceOracle } from "contracts/oracles/SfrxETHPriceOracle.sol";
import { WETHPriceOracle } from "contracts/oracles/WETHPriceOracle.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

library OracleLib {
    function deployLRTOracle() internal returns (address newImpl) {
        // Deploy the new contract
        newImpl = address(new LRTOracle());
        console.log("LRTOracle implementation deployed at: %s", newImpl);
    }

    function upgradeLRTOracle(address newImpl) external {
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.LRT_ORACLE), newImpl);
    }

    function deployChainlinkOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy ChainlinkPriceOracle
        address implContract = address(new ChainlinkPriceOracle());
        console.log("ChainlinkPriceOracle deployed at: %s", implContract);

        // Deploy ChainlinkPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("ChainlinkPriceOracleProxy")));
        console.log("ChainlinkPriceOracleProxy deployed at: %s", proxy);

        // Initialize ChainlinkPriceOracleProxy
        ChainlinkPriceOracle(proxy).initialize(Addresses.LRT_CONFIG);
        console.log("Initialized ChainlinkPriceOracleProxy");
    }

    function upgradeChainlinkOracle(address newImpl) external {
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.CHAINLINK_ORACLE_PROXY), newImpl);
    }

    function deployOETHOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy OETHPriceOracle
        address implContract = address(new OETHPriceOracle(Addresses.OETH_TOKEN));
        console.log("OETHPriceOracle deployed at: %s", implContract);

        // Deploy OETHPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("OETHPriceOracleProxy")));
        console.log("OETHPriceOracleProxy deployed at: %s", proxy);
    }

    function deployEthXPriceOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy EthXPriceOracle
        address implContract = address(new EthXPriceOracle());
        console.log("EthXPriceOracle deployed at: %s", implContract);

        // Deploy EthXPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("EthXPriceOracleProxy")));
        console.log("EthXPriceOracleProxy deployed at: %s", proxy);

        // Initialize the proxy
        EthXPriceOracle(proxy).initialize(Addresses.STADER_STAKING_POOL_MANAGER);
        console.log("Initialized EthXPriceOracleProxy");
    }

    function deployMEthPriceOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy MEthPriceOracle
        address implContract = address(new MEthPriceOracle(Addresses.METH_TOKEN, Addresses.METH_STAKING));
        console.log("MEthPriceOracle deployed at: %s", implContract);

        // Deploy MEthPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("MEthPriceOracleProxy")));
        console.log("MEthPriceOracleProxy deployed at: %s", proxy);
    }

    function deploySfrxEthPriceOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy SfrxETHPriceOracle
        address implContract = address(new SfrxETHPriceOracle(Addresses.SFRXETH_TOKEN, Addresses.FRAX_DUAL_ORACLE));
        console.log("SfrxETHPriceOracle deployed at: %s", implContract);

        // Deploy SfrxETHPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("SfrxETHPriceOracleProxy")));
        console.log("SfrxETHPriceOracleProxy deployed at: %s", proxy);
    }

    function deployWETHOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy WETHPriceOracle
        address implContract = address(new WETHPriceOracle(Addresses.WETH_TOKEN));
        console.log("WETHPriceOracle deployed at: %s", implContract);

        // Deploy WETHPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("WETHPriceOracleProxy")));
        console.log("WETHPriceOracleProxy deployed at: %s", proxy);
    }
}
