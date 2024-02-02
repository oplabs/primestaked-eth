// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { MEthPriceOracle } from "contracts/oracles/MEthPriceOracle.sol";
import { SfrxETHPriceOracle } from "contracts/oracles/SfrxETHPriceOracle.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";

contract DeployOracles is Script {
    ProxyFactory public proxyFactory;
    address public proxyAdmin;
    address public lrtConfig;

    function run() external {
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

        lrtConfig = 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF;
        proxyFactory = ProxyFactory(0x279b272E8266D2fd87e64739A8ecD4A5c94F953D);
        proxyAdmin = 0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758;

        console.log("Deployer: %s", msg.sender);

        deployChainlinkOracle();
        deployOETHOracle();
        deployEthXPriceOracle();
        deployMEthPriceOracle();
        deploySfrxEthPriceOracle();

        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
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

    function deployEthXPriceOracle() private {
        address staderStakingPoolManager = 0xcf5EA1b38380f6aF39068375516Daf40Ed70D299;

        // Deploy EthXPriceOracle
        address implContract = address(new EthXPriceOracle());
        console.log("EthXPriceOracle deployed at: %s", implContract);

        // Deploy EthXPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("EthXPriceOracleProxy")));
        console.log("EthXPriceOracleProxy deployed at: %s", proxy);

        // Initialize the proxy
        EthXPriceOracle(proxy).initialize(staderStakingPoolManager);
        console.log("Initialized EthXPriceOracleProxy");
    }

    function deployMEthPriceOracle() private {
        address mEth = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
        address mEthStaking = 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f;

        // Deploy MEthPriceOracle
        address implContract = address(new MEthPriceOracle(mEth, mEthStaking));
        console.log("MEthPriceOracle deployed at: %s", implContract);

        // Deploy MEthPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("MEthPriceOracleProxy")));
        console.log("MEthPriceOracleProxy deployed at: %s", proxy);
    }

    function deploySfrxEthPriceOracle() private {
        address fraxDualOracle = 0x584902BCe4282003E420Cf5b7ae5063D6C1c182a;
        address sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;

        // Deploy SfrxETHPriceOracle
        address implContract = address(new SfrxETHPriceOracle(sfrxETH, fraxDualOracle));
        console.log("SfrxETHPriceOracle deployed at: %s", implContract);

        // Deploy SfrxETHPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("SfrxETHPriceOracleProxy")));
        console.log("SfrxETHPriceOracleProxy deployed at: %s", proxy);
    }
}
