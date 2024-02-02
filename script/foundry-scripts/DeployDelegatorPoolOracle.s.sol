// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

function getLSTs() view returns (address stETH, address ethx) {
    uint256 chainId = block.chainid;

    if (chainId == 1) {
        // mainnet
        stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        ethx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    } else if (chainId == 5) {
        // goerli
        stETH = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
        ethx = 0x3338eCd3ab3d3503c55c931d759fA6d78d287236;
    } else {
        revert("Unsupported network");
    }
}

contract DeployDelegatorPoolOracle is Script {
    ProxyAdmin public proxyAdmin;
    ProxyFactory public proxyFactory;
    LRTConfig public lrtConfigProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    //ChainlinkPriceOracle public chainlinkPriceOracleProxy;
    //EthXPriceOracle public ethXPriceOracleProxy;
    NodeDelegator public nodeDelegatorProxy1;
    address[] public nodeDelegatorContracts;

    uint256 public minAmountToDeposit;

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
            strategyManager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
            stETHStrategy = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
            ethXStrategy = 0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d;
            oethStrategy = 0xa4C637e0F704745D182e4D38cAb7E7485321d059;
        } else {
            // testnet
            strategyManager = 0x779d1b5315df083e3F9E94cB495983500bA8E907;
            stETHStrategy = 0xB613E78E2068d7489bb66419fB1cfa11275d14da;
            ethXStrategy = 0x5d1E9DC056C906CBfe06205a39B0D965A6Df7C14;
            oethStrategy = address(0);
        }
    }

    function setUpByAdmin() private {
        (address stETH, address ethx) = getLSTs();
        // ----------- callable by admin ----------------

        // add oracle to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));

        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address stETHStrategy, address ethXStrategy, address oethStrategy) = getAssetStrategies();
        lrtConfigProxy.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);
        lrtConfigProxy.updateAssetStrategy(stETH, stETHStrategy);
        lrtConfigProxy.updateAssetStrategy(ethx, ethXStrategy);

        // add minter role to lrtDepositPool so it mints primeETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        minAmountToDeposit = 0.0001 ether;
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function setUpByManager() private {
        // --------- callable by manager -----------
        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy1));
    }

    function run() external {
        bool isFork = vm.envOr("IS_FORK", false);
        if (isFork) {
            address mainnetProxyOwner = 0x7fbd78ae99151A3cfE46824Cd6189F28c8C45168;
            vm.startPrank(mainnetProxyOwner);
        } else {
            vm.startBroadcast();
        }

        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));
        uint256 chainId = block.chainid;

        // mainnet
        proxyAdmin = ProxyAdmin(0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758);
        proxyFactory = ProxyFactory(0x279b272E8266D2fd87e64739A8ecD4A5c94F953D);
        lrtConfigProxy = LRTConfig(0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF);

        console.log("Chain id", chainId);
        console.log("IS_FORK", isFork);
        console.log("ProxyOwner", proxyAdmin.owner());

        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        address lrtOracleImplementation = address(new LRTOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator());
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
        if (isFork) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
