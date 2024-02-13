// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { TestHelper } from './utils/TestHelper.sol';

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

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

contract DeployDelegatorPoolOracle is Script, TestHelper {
    ProxyAdmin public proxyAdmin;
    ProxyFactory public proxyFactory;
    LRTConfig public lrtConfig;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    //ChainlinkPriceOracle public chainlinkPriceOracleProxy;
    //EthXPriceOracle public ethXPriceOracleProxy;
    NodeDelegator public nodeDelegatorProxy1;
    address[] public nodeDelegatorContracts;

    // deposit limit for all assets
    uint256 public minAmountToDeposit = 10 ether;

    function maxApproveToEigenStrategyManager(address nodeDel) private {
        (address stETH, address ethx) = getLSTs();
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(stETH);
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(ethx);
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
        (address stETH, address ethx) = getLSTs();
        // ----------- callable by admin ----------------

        // add oracle to LRT config
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfig.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));

        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address stETHStrategy, address ethXStrategy,) = getAssetStrategies();
        lrtConfig.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);

        // lrtConfig.updateAssetStrategy(stETH, stETHStrategy);
        // lrtConfig.updateAssetStrategy(ethx, ethXStrategy);

        // add minter role to lrtDepositPool so it mints primeETH
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function setUpByManager() private {
        // --------- callable by manager -----------
        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        // maxApproveToEigenStrategyManager(address(nodeDelegatorProxy1));
    }

    function run() external {
        preRun();
        // (ProxyFactory proxyFactory, ProxyAdmin proxyAdmin, LRTConfig lrtConfig, LRTOracle lrtOracle, LRTDepositPool lrtDepositPool, address strategyManager, address stETHStrategy, address oethStrategy)
        (
            proxyFactory,
            proxyAdmin,
            lrtConfig,
            ,,,,,,
        ) = getAddresses();

        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));
        uint256 chainId = block.chainid;

        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        address lrtOracleImplementation = address(new LRTOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator());

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
        lrtDepositPoolProxy.initialize(address(lrtConfig));

        lrtOracleProxy = LRTOracle(proxyFactory.create(address(lrtOracleImplementation), address(proxyAdmin), salt));
        // init LRTOracle
        lrtOracleProxy.initialize(address(lrtConfig));

        nodeDelegatorProxy1 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));

        // init NodeDelegator
        nodeDelegatorProxy1.initialize(address(lrtConfig));

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
        postRun();
    }
}
