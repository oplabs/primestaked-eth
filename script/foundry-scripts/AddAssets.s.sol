// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { SfrxETHPriceOracle } from "contracts/oracles/SfrxETHPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract AddAssets is Script {
    uint256 maxDeposits = 100 ether;

    ProxyFactory public proxyFactory;
    ProxyAdmin public proxyAdmin;

    LRTConfig public lrtConfig;
    LRTOracle public lrtOracle;
    NodeDelegator public nodeDel;

    function run() external {
        if (block.chainid != 1) {
            revert("Not Mainnet");
        }

        bool isFork = vm.envOr("IS_FORK", false);
        if (isFork) {
            address mainnetProxyOwner = Addresses.PROXY_OWNER;
            console.log("Running deploy on fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            console.log("Deploying on mainnet deployer: %s", msg.sender);
            vm.startBroadcast();
        }

        proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);

        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
        nodeDel = NodeDelegator(payable(Addresses.NODE_DELEGATOR));

        if (block.number < 19_146_000) {
            // add manager role to the deployer
            lrtConfig.grantRole(LRTConstants.MANAGER, msg.sender);

            // Skip if they are already configured
            addOETH();
            addStETH();
            addETHx();
            addSfrxETH();
            addMEth();
        }

        if (block.number < 19_150_615) {
            addRETH();
            addSwETH();
        }

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }

    function addOETH() private {
        configureAsset(
            LRTConstants.OETH_TOKEN, Addresses.OETH_TOKEN, Addresses.OETH_EIGEN_STRATEGY, Addresses.OETH_ORACLE_PROXY
        );

        console.log("Configured OETH");
    }

    function addSfrxETH() private {
        configureAsset(
            LRTConstants.SFRXETH_TOKEN,
            Addresses.SFRXETH_TOKEN,
            Addresses.SFRXETH_EIGEN_STRATEGY,
            Addresses.SFRXETH_ORACLE_PROXY
        );

        console.log("Configured sfrxETH");
    }

    function addMEth() private {
        configureAsset(
            LRTConstants.M_ETH_TOKEN, Addresses.METH_TOKEN, Addresses.METH_EIGEN_STRATEGY, Addresses.METH_ORACLE_PROXY
        );

        console.log("Configured mETH");
    }

    function addStETH() private {
        // NOTE: stETH is already supported so just need to add Oracle
        ChainlinkPriceOracle chainlinkOracleProxy = ChainlinkPriceOracle(Addresses.CHAINLINK_ORACLE_PROXY);
        chainlinkOracleProxy.updatePriceFeedFor(Addresses.STETH_TOKEN, Addresses.STETH_ORACLE);
        lrtOracle.updatePriceOracleFor(Addresses.STETH_TOKEN, address(chainlinkOracleProxy));

        console.log("Configured stETH");
    }

    function addRETH() private {
        addAssetWithChainlinkOracle(
            LRTConstants.R_ETH_TOKEN, Addresses.RETH_TOKEN, Addresses.RETH_EIGEN_STRATEGY, Addresses.RETH_ORACLE
        );

        console.log("Configured RETH");
    }

    function addSwETH() private {
        addAssetWithChainlinkOracle(
            LRTConstants.SWETH_TOKEN, Addresses.SWETH_TOKEN, Addresses.SWETH_EIGEN_STRATEGY, Addresses.SWETH_ORACLE
        );

        console.log("Configured swETH");
    }

    function addETHx() private {
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
        private
    {
        ChainlinkPriceOracle chainlinkOracleProxy = ChainlinkPriceOracle(Addresses.CHAINLINK_ORACLE_PROXY);

        lrtConfig.setToken(tokenId, asset);

        lrtConfig.addNewSupportedAsset(asset, maxDeposits);

        chainlinkOracleProxy.updatePriceFeedFor(asset, assetOracle);
        lrtConfig.updateAssetStrategy(asset, strategy);

        lrtOracle.updatePriceOracleFor(asset, address(chainlinkOracleProxy));

        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(asset);
    }

    function configureAsset(bytes32 tokenId, address asset, address strategy, address assetOracle) private {
        lrtConfig.setToken(tokenId, asset);

        lrtConfig.addNewSupportedAsset(asset, maxDeposits);
        lrtConfig.updateAssetStrategy(asset, strategy);

        lrtOracle.updatePriceOracleFor(asset, assetOracle);

        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(asset);
    }
}
