// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { MEthPriceOracle } from "contracts/oracles/MEthPriceOracle.sol";
import { SfrxETHPriceOracle } from "contracts/oracles/SfrxETHPriceOracle.sol";
import { WETHPriceOracle } from "contracts/oracles/WETHPriceOracle.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

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
            address mainnetProxyOwner = Addresses.PROXY_OWNER;
            console.log("Running deploy on fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            console.log("Deploying on mainnet deployer: %s", msg.sender);
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            vm.startBroadcast(deployerPrivateKey);
        }

        lrtConfig = Addresses.LRT_CONFIG;
        proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);
        proxyAdmin = Addresses.PROXY_ADMIN;

        console.log("Deployer: %s", msg.sender);

        if (block.number < 19_142_698) {
            deployChainlinkOracle();
            deployOETHOracle();
            deployEthXPriceOracle();
            deployMEthPriceOracle();
            deploySfrxEthPriceOracle();
        }
        deployOETHOracle();

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
        // Deploy OETHPriceOracle
        address implContract = address(new OETHPriceOracle(Addresses.OETH_TOKEN));
        console.log("OETHPriceOracle deployed at: %s", implContract);

        // Deploy OETHPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("OETHPriceOracleProxy")));
        console.log("OETHPriceOracleProxy deployed at: %s", proxy);
    }

    function deployWETHOracle() private {
        // Deploy WETHPriceOracle
        address implContract = address(new WETHPriceOracle(Addresses.WETH_TOKEN));
        console.log("WETHPriceOracle deployed at: %s", implContract);

        // Deploy WETHPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("WETHPriceOracleProxy")));
        console.log("WETHPriceOracleProxy deployed at: %s", proxy);
    }

    function deployEthXPriceOracle() private {
        // Deploy EthXPriceOracle
        address implContract = address(new EthXPriceOracle());
        console.log("EthXPriceOracle deployed at: %s", implContract);

        // Deploy EthXPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("EthXPriceOracleProxy")));
        console.log("EthXPriceOracleProxy deployed at: %s", proxy);

        // Initialize the proxy
        EthXPriceOracle(proxy).initialize(Addresses.STADER_STAKING_POOL_MANAGER);
        console.log("Initialized EthXPriceOracleProxy");
    }

    function deployMEthPriceOracle() private {
        // Deploy MEthPriceOracle
        address implContract = address(new MEthPriceOracle(Addresses.METH_TOKEN, Addresses.METH_STAKING));
        console.log("MEthPriceOracle deployed at: %s", implContract);

        // Deploy MEthPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("MEthPriceOracleProxy")));
        console.log("MEthPriceOracleProxy deployed at: %s", proxy);
    }

    function deploySfrxEthPriceOracle() private {
        // Deploy SfrxETHPriceOracle
        address implContract = address(new SfrxETHPriceOracle(Addresses.SFRXETH_TOKEN, Addresses.FRAX_DUAL_ORACLE));
        console.log("SfrxETHPriceOracle deployed at: %s", implContract);

        // Deploy SfrxETHPriceOracle proxy
        address proxy =
            proxyFactory.create(implContract, proxyAdmin, keccak256(abi.encodePacked("SfrxETHPriceOracleProxy")));
        console.log("SfrxETHPriceOracleProxy deployed at: %s", proxy);
    }
}
