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
import { LRTConfigRoleChecker } from "contracts/utils/LRTConfigRoleChecker.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AddAssets is Script {
    ProxyFactory public proxyFactory;
    ProxyAdmin public proxyAdmin;

    LRTConfig public lrtConfig;
    LRTOracle public lrtOracle;
    address oethOracleProxy;

    function run() external {
        // IMPORTNAT: Uncomment after delpoying LRTOracle
        // or manually change if running on forked net
        lrtOracle = LRTOracle(0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32);

        if (block.chainid != 1) {
            revert("Not Mainnet");
        }

        bool isFork = vm.envOr("IS_FORK", false);
        if (isFork) {
            address mainnetProxyOwner = 0x7fbd78ae99151A3cfE46824Cd6189F28c8C45168;
            console.log("Running deploy on fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            console.log("Deploying on mainnet deployer: %s", msg.sender);
            vm.startBroadcast();
        }

        proxyFactory = ProxyFactory(0x279b272E8266D2fd87e64739A8ecD4A5c94F953D);
        proxyAdmin = ProxyAdmin(0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758);
        lrtConfig = LRTConfig(0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF);
        // add manager role to the deployer
        lrtConfig.grantRole(LRTConstants.MANAGER, msg.sender);

        addOETH();
        addStETH();
        addETHx();
        addSfrxETH();
        addMEth();
        // addRETH();

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }

    function addOETH() private {
        address oeth = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
        address strategy = 0xa4C637e0F704745D182e4D38cAb7E7485321d059;

        address oethOracleProxy = 0xc513bDfbC308bC999cccc852AF7C22aBDF44A995;

        configureAsset(LRTConstants.OETH_TOKEN, oeth, strategy, oethOracleProxy);

        console.log("Configured OETH");
    }

    function addSfrxETH() private {
        address sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
        address strategy = 0x8CA7A5d6f3acd3A7A8bC468a8CD0FB14B6BD28b6;

        address assetOracleProxy = 0x407d53b380A4A05f8dce5FBd775DF51D1DC0D294;

        configureAsset(LRTConstants.SFRXETH_TOKEN, sfrxETH, strategy, assetOracleProxy);

        console.log("Configured sfrxETH");
    }

    function addMEth() private {
        address mETH = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
        address strategy = 0x8CA7A5d6f3acd3A7A8bC468a8CD0FB14B6BD28b6;

        address assetOracleProxy = 0xE709cee865479Ae1CF88f2f643eF8D7e0be6e369;

        configureAsset(LRTConstants.M_ETH_TOKEN, mETH, strategy, assetOracleProxy);

        console.log("Configured mETH");
    }

    function addStETH() private {
        address stETH = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
        address strategy = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
        address assetOracle = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;

        addAssetWithChainlinkOracle(LRTConstants.ST_ETH_TOKEN, stETH, strategy, assetOracle);

        console.log("Configured stETH");
    }

    function addRETH() private {
        address reth = 0xae78736Cd615f374D3085123A210448E74Fc6393;
        address strategy = 0x1BeE69b7dFFfA4E2d53C2a2Df135C388AD25dCD2;
        address assetOracle = 0x536218f9E9Eb48863970252233c8F271f554C2d0;

        addAssetWithChainlinkOracle(LRTConstants.R_ETH_TOKEN, reth, strategy, assetOracle);

        console.log("Configured RETH");
    }

    function addETHx() private {
        address ethx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
        address strategy = 0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d;
        address assetOracleProxy = 0x85B4C05c9dC3350c220040BAa48BD0aD914ad00C;
        // NOTE: ETHx is already supported, only update the Oracle and strategy
        // lrtConfig.updateAssetStrategy(ethx, strategy);

        lrtOracle.updatePriceOracleFor(ethx, assetOracleProxy);

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
        ChainlinkPriceOracle chainlinkOracleProxy = ChainlinkPriceOracle(0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09);

        lrtConfig.setToken(tokenId, asset);

        // TODO: Check Deposit limits
        lrtConfig.addNewSupportedAsset(asset, 100_000 ether);

        chainlinkOracleProxy.updatePriceFeedFor(asset, assetOracle);
        lrtConfig.updateAssetStrategy(asset, strategy);

        lrtOracle.updatePriceOracleFor(asset, assetOracle);
    }

    function configureAsset(bytes32 tokenId, address asset, address strategy, address assetOracle) private {
        lrtConfig.setToken(tokenId, asset);

        // TODO: Check Deposit limits
        lrtConfig.addNewSupportedAsset(asset, 100_000 ether);
        lrtConfig.updateAssetStrategy(asset, strategy);

        lrtOracle.updatePriceOracleFor(asset, assetOracle);
    }
}
