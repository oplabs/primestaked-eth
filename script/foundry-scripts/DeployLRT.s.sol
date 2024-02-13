// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

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

contract DeployLRT is Script {
    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    PrimeStakedETH public PRETHProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    ChainlinkPriceOracle public chainlinkPriceOracleProxy;
    EthXPriceOracle public ethXPriceOracleProxy;
    NodeDelegator public nodeDelegatorProxy1;
    NodeDelegator public nodeDelegatorProxy2;
    NodeDelegator public nodeDelegatorProxy3;
    NodeDelegator public nodeDelegatorProxy4;
    NodeDelegator public nodeDelegatorProxy5;
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
        returns (address strategyManager, address stETHStrategy, address ethXStrategy)
    {
        uint256 chainId = block.chainid;
        // https://github.com/Layr-Labs/eigenlayer-contracts#deployments
        if (chainId == 1) {
            // mainnet
            strategyManager = Addresses.EIGEN_STRATEGY_MANAGER;
            stETHStrategy = Addresses.STETH_EIGEN_STRATEGY;
            ethXStrategy = Addresses.ETHX_EIGEN_STRATEGY;
        } else {
            // testnet
            strategyManager = AddressesGoerli.EIGEN_STRATEGY_MANAGER;
            stETHStrategy = AddressesGoerli.STETH_EIGEN_STRATEGY;
            ethXStrategy = AddressesGoerli.ETHX_EIGEN_STRATEGY;
        }
    }

    function getPriceFeeds() private returns (address stETHPriceFeed, address ethxPriceFeed) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // mainnet
            stETHPriceFeed = Addresses.STETH_ORACLE;
            ethxPriceFeed = address(ethXPriceOracleProxy);
        } else {
            // testnet
            stETHPriceFeed = address(new MockPriceAggregator());
            ethxPriceFeed = address(ethXPriceOracleProxy);
        }
    }

    function setUpByAdmin() private {
        (address stETH,) = getLSTs();
        // ----------- callable by admin ----------------

        // add primeETH to LRT config
        lrtConfigProxy.setPrimeETH(address(PRETHProxy));
        // add oracle to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));
        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address stETHStrategy,) = getAssetStrategies();
        lrtConfigProxy.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);
        lrtConfigProxy.updateAssetStrategy(stETH, stETHStrategy);
        // TODO: NEED TO HAVE ETHX STRATEGY
        // lrtConfigProxy.updateAssetStrategy(ethx, ethXStrategy);

        // grant MANAGER_ROLE to an address in LRTConfig
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, deployerAddress);
        // add minter role to lrtDepositPool so it mints primeETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy2));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy3));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy4));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy5));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        lrtDepositPoolProxy.setMinAmountToDeposit(minAmountToDeposit);
    }

    function setUpByManager() private {
        (address stETH, address ethx) = getLSTs();
        // --------- callable by manager -----------

        (address stETHPriceFeed, address ethxPriceFeed) = getPriceFeeds();

        // Add chainlink oracles for supported assets in ChainlinkPriceOracle
        chainlinkPriceOracleProxy.updatePriceFeedFor(stETH, stETHPriceFeed);

        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracleProxy.updatePriceOracleFor(address(stETH), address(chainlinkPriceOracleProxy));
        lrtOracleProxy.updatePriceOracleFor(address(ethx), address(ethxPriceFeed));

        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy1));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy2));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy3));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy4));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy5));
    }

    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked("Prime-Staked"));
        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();
        minAmountToDeposit = 0.0001 ether;

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

        // deploy implementation contracts
        address lrtConfigImplementation = address(new LRTConfig());
        address primeETHImplementation = address(new PrimeStakedETH());
        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        address lrtOracleImplementation = address(new LRTOracle());
        address chainlinkPriceOracleImplementation = address(new ChainlinkPriceOracle());
        address ethxPriceOracleImplementation = address(new EthXPriceOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTConfig implementation deployed at: ", lrtConfigImplementation);
        console.log("PrimeStakedETH implementation deployed at: ", primeETHImplementation);
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("LRTOracle implementation deployed at: ", lrtOracleImplementation);
        console.log("ChainlinkPriceOracle implementation deployed at: ", chainlinkPriceOracleImplementation);
        console.log("EthXPriceOracle implementation deployed at: ", ethxPriceOracleImplementation);
        console.log("NodeDelegator implementation deployed at: ", nodeDelegatorImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them
        lrtConfigProxy = LRTConfig(proxyFactory.create(address(lrtConfigImplementation), address(proxyAdmin), salt));

        // set up LRTConfig init params
        (address stETH, address ethx) = getLSTs();
        address predictedPRETHAddress = proxyFactory.computeAddress(primeETHImplementation, address(proxyAdmin), salt);
        console.log("predictedPRETHAddress: ", predictedPRETHAddress);
        // init LRTConfig
        // TODO: the initialize config supports only 2 LSTs. we need to alter this to
        // the number of LSTS we are planning to launch with
        lrtConfigProxy.initialize(deployerAddress, stETH, ethx, predictedPRETHAddress);

        PRETHProxy = PrimeStakedETH(proxyFactory.create(address(primeETHImplementation), address(proxyAdmin), salt));
        // init PrimeStakedETH
        PRETHProxy.initialize(address(lrtConfigProxy));

        lrtDepositPoolProxy = LRTDepositPool(
            payable(proxyFactory.create(address(lrtDepositPoolImplementation), address(proxyAdmin), salt))
        );
        // init LRTDepositPool
        lrtDepositPoolProxy.initialize(address(lrtConfigProxy));

        lrtOracleProxy = LRTOracle(proxyFactory.create(address(lrtOracleImplementation), address(proxyAdmin), salt));
        // init LRTOracle
        lrtOracleProxy.initialize(address(lrtConfigProxy));

        chainlinkPriceOracleProxy = ChainlinkPriceOracle(
            proxyFactory.create(address(chainlinkPriceOracleImplementation), address(proxyAdmin), salt)
        );
        // init ChainlinkPriceOracle
        chainlinkPriceOracleProxy.initialize(address(lrtConfigProxy));

        ethXPriceOracleProxy =
            EthXPriceOracle(proxyFactory.create(address(ethxPriceOracleImplementation), address(proxyAdmin), salt));

        // init EthXPriceOracle
        if (block.chainid == 1) {
            address staderStakingPoolManager = Addresses.STADER_STAKING_POOL_MANAGER;
            // mainnet
            ethXPriceOracleProxy.initialize(staderStakingPoolManager);
        } else {
            address staderStakingPoolManager = AddressesGoerli.STADER_STAKING_POOL_MANAGER;
            // testnet
            ethXPriceOracleProxy.initialize(staderStakingPoolManager);
        }

        nodeDelegatorProxy1 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));
        bytes32 saltForNodeDelegator2 = keccak256(abi.encodePacked("Prime-Staked-nodeDelegator2"));
        nodeDelegatorProxy2 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator2)
            )
        );
        bytes32 saltForNodeDelegator3 = keccak256(abi.encodePacked("Prime-Staked-nodeDelegator3"));
        nodeDelegatorProxy3 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator3)
            )
        );
        bytes32 saltForNodeDelegator4 = keccak256(abi.encodePacked("Prime-Staked-nodeDelegator4"));
        nodeDelegatorProxy4 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator4)
            )
        );
        bytes32 saltForNodeDelegator5 = keccak256(abi.encodePacked("Prime-Staked-nodeDelegator5"));
        nodeDelegatorProxy5 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator5)
            )
        );
        // init NodeDelegator
        nodeDelegatorProxy1.initialize(address(lrtConfigProxy));
        nodeDelegatorProxy2.initialize(address(lrtConfigProxy));
        nodeDelegatorProxy3.initialize(address(lrtConfigProxy));
        nodeDelegatorProxy4.initialize(address(lrtConfigProxy));
        nodeDelegatorProxy5.initialize(address(lrtConfigProxy));

        console.log("LRTConfig proxy deployed at: ", address(lrtConfigProxy));
        console.log("PrimeStakedETH proxy deployed at: ", address(PRETHProxy));
        console.log("LRTDepositPool proxy deployed at: ", address(lrtDepositPoolProxy));
        console.log("LRTOracle proxy deployed at: ", address(lrtOracleProxy));
        console.log("ChainlinkPriceOracle proxy deployed at: ", address(chainlinkPriceOracleProxy));
        console.log("EthXPriceOracle proxy deployed at: ", address(ethXPriceOracleProxy));
        console.log("NodeDelegator proxy 1 deployed at: ", address(nodeDelegatorProxy1));
        console.log("NodeDelegator proxy 2 deployed at: ", address(nodeDelegatorProxy2));
        console.log("NodeDelegator proxy 3 deployed at: ", address(nodeDelegatorProxy3));
        console.log("NodeDelegator proxy 4 deployed at: ", address(nodeDelegatorProxy4));
        console.log("NodeDelegator proxy 5 deployed at: ", address(nodeDelegatorProxy5));

        // setup
        setUpByAdmin();
        setUpByManager();

        // update prETHPrice
        lrtOracleProxy.updatePrimeETHPrice();

        // // We will transfer the ownership once all of the deploys are done
        // uint256 chainId = block.chainid;
        // address manager;
        // address admin;

        // if (chainId == 1) {
        //     // mainnet
        //     manager = Addresses.MANAGER_ROLE;
        //     admin = Addresses.ADMIN_ROLE;
        // } else if (chainId == 5) {
        //     // goerli
        //     manager = deployerAddress;
        //     admin = deployerAddress;
        // } else {
        //     revert("Unsupported network");
        // }

        // lrtConfigProxy.grantRole(LRTConstants.MANAGER, manager);
        // console.log("Manager permission granted to: ", manager);

        // lrtConfigProxy.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin);
        // lrtConfigProxy.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, deployerAddress);
        // proxyAdmin.transferOwnership(admin);

        // console.log("ProxyAdmin ownership transferred to: ", admin);

        vm.stopBroadcast();
    }
}
