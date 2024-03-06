// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { MEthPriceOracle } from "contracts/oracles/MEthPriceOracle.sol";
import { SfrxETHPriceOracle } from "contracts/oracles/SfrxETHPriceOracle.sol";
import { WETHPriceOracle } from "contracts/oracles/WETHPriceOracle.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

library OraclesLib {
    function deployLRTOracleImpl() internal returns (address implementation) {
        // Deploy the new contract
        implementation = address(new LRTOracle());
        console.log("LRTOracle implementation deployed at: %s", implementation);
    }

    function deployLRTOracleProxy(
        address implementation,
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory
    )
        internal
        returns (LRTOracle oracle)
    {
        address proxy = proxyFactory.create(implementation, address(proxyAdmin), LRTConstants.SALT);
        console.log("LRTOracle proxy deployed at: ", proxy);

        oracle = LRTOracle(proxy);
    }

    function upgradeLRTOracle(address implementation) internal {
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.LRT_ORACLE), implementation);
    }

    function initializeLRTOracle(LRTOracle oracle, LRTConfig config) internal {
        oracle.initialize(address(config));
    }

    function deployInitChainlinkOracle(
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory,
        LRTConfig config
    )
        internal
        returns (address proxy)
    {
        // Deploy ChainlinkPriceOracle
        address implContract = address(new ChainlinkPriceOracle());
        console.log("ChainlinkPriceOracle deployed at: %s", implContract);

        // Deploy ChainlinkPriceOracle proxy
        proxy = proxyFactory.create(
            implContract, address(proxyAdmin), keccak256(abi.encodePacked("ChainlinkPriceOracleProxy"))
        );
        console.log("ChainlinkPriceOracleProxy deployed at: %s", proxy);

        // Initialize ChainlinkPriceOracleProxy
        ChainlinkPriceOracle(proxy).initialize(address(config));
        console.log("Initialized ChainlinkPriceOracleProxy");
    }

    function deployChainlinkOracle() internal returns (address newImpl) {
        // Deploy the new contract
        newImpl = address(new ChainlinkPriceOracle());
        console.log("ChainlinkPriceOracle implementation deployed at: %s", newImpl);
    }

    function upgradeChainlinkOracle(address newImpl) internal {
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(Addresses.CHAINLINK_ORACLE_PROXY), newImpl);
    }

    function deployInitOETHOracle(ProxyAdmin proxyAdmin, ProxyFactory proxyFactory) internal returns (address proxy) {
        require(block.chainid == 1, "OETH does is only on mainnet");

        // Deploy OETHPriceOracle
        address implContract = address(new OETHPriceOracle(Addresses.OETH_TOKEN));
        console.log("OETHPriceOracle deployed at: %s", implContract);

        // Deploy OETHPriceOracle proxy
        proxy =
            proxyFactory.create(implContract, address(proxyAdmin), keccak256(abi.encodePacked("OETHPriceOracleProxy")));
        console.log("OETHPriceOracleProxy deployed at: %s", proxy);
    }

    function deployInitEthXPriceOracle(
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory
    )
        internal
        returns (address proxy)
    {
        // Deploy EthXPriceOracle
        address implContract = address(new EthXPriceOracle());
        console.log("EthXPriceOracle deployed at: %s", implContract);

        // Deploy EthXPriceOracle proxy
        proxy =
            proxyFactory.create(implContract, address(proxyAdmin), keccak256(abi.encodePacked("EthXPriceOracleProxy")));
        console.log("EthXPriceOracleProxy deployed at: %s", proxy);

        // Initialize the proxy
        address staderStakingPoolManager =
            block.chainid == 1 ? Addresses.STADER_STAKING_POOL_MANAGER : AddressesGoerli.STADER_STAKING_POOL_MANAGER;
        EthXPriceOracle(proxy).initialize(staderStakingPoolManager);
        console.log("Initialized EthXPriceOracleProxy");
    }

    function deployInitMEthPriceOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy MEthPriceOracle
        address implContract = address(new MEthPriceOracle(Addresses.METH_TOKEN, Addresses.METH_STAKING));
        console.log("MEthPriceOracle deployed at: %s", implContract);

        // Deploy MEthPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("MEthPriceOracleProxy")));
        console.log("MEthPriceOracleProxy deployed at: %s", proxy);
    }

    function deployInitSfrxEthPriceOracle() internal returns (address proxy) {
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        address proxyAdmin = Addresses.PROXY_ADMIN;

        // Deploy SfrxETHPriceOracle
        address implContract = address(new SfrxETHPriceOracle(Addresses.SFRXETH_TOKEN, Addresses.FRAX_DUAL_ORACLE));
        console.log("SfrxETHPriceOracle deployed at: %s", implContract);

        // Deploy SfrxETHPriceOracle proxy
        proxy = proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("SfrxETHPriceOracleProxy")));
        console.log("SfrxETHPriceOracleProxy deployed at: %s", proxy);
    }

    function deployInitWETHOracle(ProxyAdmin proxyAdmin, ProxyFactory proxyFactory) internal returns (address proxy) {
        address wethAddress = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesGoerli.WETH_TOKEN;

        // Deploy WETHPriceOracle
        address implContract = address(new WETHPriceOracle(wethAddress));
        console.log("WETHPriceOracle deployed at: %s", implContract);

        // Deploy WETHPriceOracle proxy
        proxy =
            proxyFactory.create(implContract, address(proxyAdmin), keccak256(abi.encodePacked("WETHPriceOracleProxy")));
        console.log("WETHPriceOracleProxy deployed at: %s", proxy);
    }
}
