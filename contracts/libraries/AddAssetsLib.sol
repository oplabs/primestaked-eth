// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

uint256 constant maxDeposits = 100_000 ether;

library AddAssetsLib {
    function getConfig() internal view returns (LRTConfig) {
        address configAddress = block.chainid == 1 ? Addresses.LRT_CONFIG : AddressesGoerli.LRT_CONFIG;
        return LRTConfig(configAddress);
    }

    function getOracle() internal view returns (LRTOracle) {
        address oracleAddress = block.chainid == 1 ? Addresses.LRT_ORACLE : AddressesGoerli.LRT_ORACLE;
        return LRTOracle(oracleAddress);
    }

    function addWETHAdmin(address wethOracleProxy) internal {
        LRTConfig lrtConfig = getConfig();
        lrtConfig.setToken(LRTConstants.WETH_TOKEN, Addresses.WETH_TOKEN);

        LRTOracle lrtOracle = getOracle();
        lrtOracle.updatePriceOracleFor(Addresses.WETH_TOKEN, wethOracleProxy);
    }

    function addWETHManager() internal {
        LRTConfig lrtConfig = getConfig();
        lrtConfig.addNewSupportedAsset(Addresses.WETH_TOKEN, maxDeposits);
    }

    function addOETH() internal {
        configureAsset(
            LRTConstants.OETH_TOKEN, Addresses.OETH_TOKEN, Addresses.OETH_EIGEN_STRATEGY, Addresses.OETH_ORACLE_PROXY
        );

        console.log("Configured OETH");
    }

    function addSfrxETH() internal {
        configureAsset(
            LRTConstants.SFRXETH_TOKEN,
            Addresses.SFRXETH_TOKEN,
            Addresses.SFRXETH_EIGEN_STRATEGY,
            Addresses.SFRXETH_ORACLE_PROXY
        );

        console.log("Configured sfrxETH");
    }

    function addMEth() internal {
        configureAsset(
            LRTConstants.M_ETH_TOKEN, Addresses.METH_TOKEN, Addresses.METH_EIGEN_STRATEGY, Addresses.METH_ORACLE_PROXY
        );

        console.log("Configured mETH");
    }

    function addStETH() internal {
        // NOTE: stETH is already supported so just need to add Oracle
        ChainlinkPriceOracle chainlinkOracleProxy = ChainlinkPriceOracle(Addresses.CHAINLINK_ORACLE_PROXY);
        chainlinkOracleProxy.updatePriceFeedFor(Addresses.STETH_TOKEN, Addresses.STETH_ORACLE);

        LRTOracle lrtOracle = getOracle();
        lrtOracle.updatePriceOracleFor(Addresses.STETH_TOKEN, address(chainlinkOracleProxy));

        console.log("Configured stETH");
    }

    function addRETH() internal {
        addAssetWithChainlinkOracle(
            LRTConstants.R_ETH_TOKEN, Addresses.RETH_TOKEN, Addresses.RETH_EIGEN_STRATEGY, Addresses.RETH_ORACLE
        );

        console.log("Configured RETH");
    }

    function addSwETH() internal {
        addAssetWithChainlinkOracle(
            LRTConstants.SWETH_TOKEN, Addresses.SWETH_TOKEN, Addresses.SWETH_EIGEN_STRATEGY, Addresses.SWETH_ORACLE
        );

        console.log("Configured swETH");
    }

    function addETHx() internal {
        LRTOracle lrtOracle = getOracle();
        // NOTE: ETHx is already supported so just need to add Oracle
        lrtOracle.updatePriceOracleFor(Addresses.ETHX_TOKEN, Addresses.ETHX_ORACLE_PROXY);

        console.log("Configured ETHx");
    }

    function addAssetWithChainlinkOracle(
        bytes32 tokenId,
        address asset,
        address strategy,
        address assetOracle
    )
        internal
    {
        LRTConfig lrtConfig = getConfig();
        LRTOracle lrtOracle = getOracle();

        ChainlinkPriceOracle chainlinkOracleProxy = ChainlinkPriceOracle(Addresses.CHAINLINK_ORACLE_PROXY);

        lrtConfig.setToken(tokenId, asset);

        lrtConfig.addNewSupportedAsset(asset, maxDeposits);

        chainlinkOracleProxy.updatePriceFeedFor(asset, assetOracle);
        lrtConfig.updateAssetStrategy(asset, strategy);

        lrtOracle.updatePriceOracleFor(asset, address(chainlinkOracleProxy));

        // TODO this needs to handle multiple Node Delegators
        NodeDelegator(payable(Addresses.NODE_DELEGATOR)).maxApproveToEigenStrategyManager(asset);
    }

    function configureAsset(bytes32 tokenId, address asset, address strategy, address assetOracle) internal {
        LRTConfig lrtConfig = getConfig();
        LRTOracle lrtOracle = getOracle();

        lrtConfig.setToken(tokenId, asset);

        lrtConfig.addNewSupportedAsset(asset, maxDeposits);
        lrtConfig.updateAssetStrategy(asset, strategy);

        lrtOracle.updatePriceOracleFor(asset, assetOracle);

        // TODO this needs to handle multiple Node Delegators
        NodeDelegator(payable(Addresses.NODE_DELEGATOR)).maxApproveToEigenStrategyManager(asset);
    }
}
