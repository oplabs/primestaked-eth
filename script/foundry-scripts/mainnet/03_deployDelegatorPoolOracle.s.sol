// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

contract DeployDelegatorPoolOracle is BaseMainnetScript {
    ProxyAdmin public proxyAdmin;
    ProxyFactory public proxyFactory;
    LRTConfig public lrtConfigProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    NodeDelegator public nodeDelegatorProxy1;
    address[] public nodeDelegatorContracts;

    // deposit limit for all assets
    uint256 public minAmountToDeposit = 10 ether;

    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_143_860;
    }

    function _execute() internal override {
        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));

        // mainnet
        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        lrtConfigProxy = LRTConfig(Addresses.LRT_CONFIG);

        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        address lrtOracleImplementation = address(new LRTOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator(Addresses.WETH_TOKEN));
        //address chainlinkPriceOracleImplementation = address(new ChainlinkPriceOracle());
        //address ethxPriceOracleImplementation = address(new EthXPriceOracle());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("LRTOracle implementation deployed at: ", lrtOracleImplementation);
        //console.log("ChainlinkPriceOracle implementation deployed at: ", chainlinkPriceOracleImplementation);
        //console.log("EthXPriceOracle implementation deployed at: ", ethxPriceOracleImplementation);
        console.log("NodeDelegator implementation deployed at: ", nodeDelegatorImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        lrtDepositPoolProxy = LRTDepositPool(
            payable(proxyFactory.create(address(lrtDepositPoolImplementation), address(proxyAdmin), salt))
        );
        // init LRTDepositPool
        lrtDepositPoolProxy.initialize(address(lrtConfigProxy));

        lrtOracleProxy = LRTOracle(proxyFactory.create(address(lrtOracleImplementation), address(proxyAdmin), salt));
        // init LRTOracle
        lrtOracleProxy.initialize(address(lrtConfigProxy));

        nodeDelegatorProxy1 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));

        // init NodeDelegator
        nodeDelegatorProxy1.initialize(address(lrtConfigProxy));

        console.log("LRTDepositPool proxy deployed at: ", address(lrtDepositPoolProxy));
        console.log("LRTOracle proxy deployed at: ", address(lrtOracleProxy));
        //console.log("ChainlinkPriceOracle proxy deployed at: ", address(chainlinkPriceOracleProxy));
        //console.log("EthXPriceOracle proxy deployed at: ", address(ethXPriceOracleProxy));
        console.log("NodeDelegator proxy 1 deployed at: ", address(nodeDelegatorProxy1));

        // setup
        setUpByAdmin();
        setUpByManager();

        // update prETHPrice
        // can not update primeETHPrice of not all oracles configured
        // lrtOracleProxy.updatePrimeETHPrice();
    }

    function maxApproveToEigenStrategyManager(address nodeDel) private {
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(Addresses.STETH_TOKEN);
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(Addresses.ETHX_TOKEN);
    }

    function getAssetStrategies()
        private
        view
        returns (address strategyManager, address stETHStrategy, address ethXStrategy, address oethStrategy)
    {
        uint256 chainId = block.chainid;
        // list of all strategy deployments on below link
        // https://github.com/Layr-Labs/eigenlayer-contracts#deployments
        if (chainId == 1) {
            // mainnet
            strategyManager = Addresses.EIGEN_STRATEGY_MANAGER;
            stETHStrategy = Addresses.STETH_EIGEN_STRATEGY;
            ethXStrategy = Addresses.ETHX_EIGEN_STRATEGY;
            oethStrategy = Addresses.OETH_EIGEN_STRATEGY;
        } else {
            // testnet
            strategyManager = AddressesGoerli.EIGEN_STRATEGY_MANAGER;
            stETHStrategy = AddressesGoerli.STETH_EIGEN_STRATEGY;
            ethXStrategy = AddressesGoerli.ETHX_EIGEN_STRATEGY;
            oethStrategy = address(0);
        }
    }

    function setUpByAdmin() private {
        // add oracle to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));

        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address stETHStrategy, address ethXStrategy,) = getAssetStrategies();
        lrtConfigProxy.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);
        lrtConfigProxy.updateAssetStrategy(Addresses.STETH_TOKEN, stETHStrategy);
        lrtConfigProxy.updateAssetStrategy(Addresses.ETHX_TOKEN, ethXStrategy);

        // add minter role to lrtDepositPool so it mints primeETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function setUpByManager() private {
        // --------- callable by manager -----------
        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy1));
    }
}
