// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";
import { ConfigLib } from "contracts/libraries/ConfigLib.sol";
import { PrimeStakedETHLib } from "contracts/libraries/PrimeStakedETHLib.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { OraclesLib } from "contracts/libraries/OraclesLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { PrimeZapperLib } from "contracts/libraries/PrimeZapperLib.sol";
import { ProxyLib } from "contracts/libraries/ProxyLib.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

contract DeployHolesky is Script {
    uint256 internal constant MAX_DEPOSITS = 1000 ether;

    bool isForked;

    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfig;
    PrimeStakedETH public primeETH;
    LRTDepositPool public depositPool;
    LRTOracle public lrtOracle;
    address public chainlinkPriceOracleAddress;
    NodeDelegator public node1;
    NodeDelegator public node2;
    address[] public nodeDelegatorContracts;

    address stETHPriceFeed;
    address rETHPriceFeed;

    uint256 public minAmountToDeposit;

    function maxApproveToEigenStrategyManager(address nodeDel) internal {
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(AddressesHolesky.STETH_TOKEN);
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(AddressesHolesky.RETH_TOKEN);
    }

    function setUpByAdmin() internal {
        // add primeETH to LRT config
        lrtConfig.setPrimeETH(address(primeETH));

        // add oracle to LRT config
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(lrtOracle));

        // add contracts to LRT config
        lrtConfig.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(depositPool));
        lrtConfig.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, AddressesHolesky.EIGEN_STRATEGY_MANAGER);
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, AddressesHolesky.EIGEN_POD_MANAGER);

        // call updateAssetStrategy for each asset in LRTConfig
        lrtConfig.updateAssetStrategy(AddressesHolesky.STETH_TOKEN, AddressesHolesky.STETH_EIGEN_STRATEGY);
        lrtConfig.updateAssetStrategy(AddressesHolesky.RETH_TOKEN, AddressesHolesky.RETH_EIGEN_STRATEGY);

        // Set SSV contract addresses in LRTConfig
        lrtConfig.setContract(LRTConstants.SSV_TOKEN, AddressesHolesky.SSV_TOKEN);
        lrtConfig.setContract(LRTConstants.SSV_NETWORK, AddressesHolesky.SSV_NETWORK);

        // grant roles to Holesky Defender Relayer
        lrtConfig.grantRole(LRTConstants.MANAGER, AddressesHolesky.RELAYER);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, AddressesHolesky.RELAYER);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, AddressesHolesky.RELAYER);

        // add minter role to lrtDepositPool so it mints primeETH
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, address(depositPool));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(node1));
        nodeDelegatorContracts.push(address(node2));
        depositPool.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        depositPool.setMinAmountToDeposit(minAmountToDeposit);

        // Approve 2nd NodeDelegator to transfer SSV tokens
        node2.approveSSV();
    }

    function setUpByManager() internal {
        // Add chainlink oracles for supported assets in ChainlinkPriceOracle
        ChainlinkPriceOracle(chainlinkPriceOracleAddress).updatePriceFeedFor(
            AddressesHolesky.STETH_TOKEN, stETHPriceFeed
        );
        ChainlinkPriceOracle(chainlinkPriceOracleAddress).updatePriceFeedFor(AddressesHolesky.RETH_TOKEN, rETHPriceFeed);

        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracle.updatePriceOracleFor(AddressesHolesky.STETH_TOKEN, chainlinkPriceOracleAddress);
        lrtOracle.updatePriceOracleFor(AddressesHolesky.RETH_TOKEN, chainlinkPriceOracleAddress);

        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(node1));
        maxApproveToEigenStrategyManager(address(node2));

        // Create and EigenPod for the 2nd NodeDelegator
        node2.createEigenPod();
    }

    function run() external {
        if (block.chainid != 17_000) {
            revert("Not Holesky");
        }

        isForked = vm.envOr("IS_FORK", false);
        if (isForked) {
            address mainnetProxyOwner = AddressesHolesky.PROXY_OWNER;
            console.log("Running script on Holesky fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            uint256 deployerPrivateKey = vm.envUint("HOLESKY_DEPLOYER_PRIVATE_KEY");
            address deployer = vm.rememberKey(deployerPrivateKey);
            vm.startBroadcast(deployer);
            console.log("Deploying on Holesky with deployer: %s", deployer);
        }

        proxyFactory = ProxyLib.getProxyFactory();
        proxyAdmin = ProxyLib.getProxyAdmin();

        deployerAddress = proxyAdmin.owner();
        minAmountToDeposit = 0.0001 ether;

        // LRTConfig
        address lrtConfigImplementation = ConfigLib.deployImpl();
        lrtConfig = ConfigLib.deployProxy(lrtConfigImplementation, proxyAdmin, proxyFactory);

        // PrimeStakedETH
        address primeETHImplementation = PrimeStakedETHLib.deployImpl();
        primeETH = PrimeStakedETHLib.deployProxy(primeETHImplementation, proxyAdmin, proxyFactory);

        // Initialize LRTConfig
        address primeETHProxyAddress =
            proxyFactory.computeAddress(primeETHImplementation, address(proxyAdmin), LRTConstants.SALT);
        console.log("predicted primeETH proxy address: ", primeETHProxyAddress);
        ConfigLib.initialize(lrtConfig, deployerAddress, primeETHProxyAddress);

        // Initialize PrimeStakedETH
        PrimeStakedETHLib.initialize(primeETH, lrtConfig);

        // LRTDepositPool
        address lrtDepositPoolImplementation = DepositPoolLib.deployImpl();
        depositPool = DepositPoolLib.deployProxy(lrtDepositPoolImplementation, proxyAdmin, proxyFactory);
        DepositPoolLib.initialize(depositPool, lrtConfig);

        // LRTOracle
        address lrtOracleImplementation = OraclesLib.deployLRTOracleImpl();
        lrtOracle = OraclesLib.deployLRTOracleProxy(lrtOracleImplementation, proxyAdmin, proxyFactory);
        OraclesLib.initializeLRTOracle(lrtOracle, lrtConfig);

        // ChainlinkPriceOracle
        chainlinkPriceOracleAddress = OraclesLib.deployInitChainlinkOracle(proxyAdmin, proxyFactory, lrtConfig);
        address wethOracleProxy = OraclesLib.deployInitWETHOracle(proxyAdmin, proxyFactory);

        // DelegatorNode
        address nodeImpl = NodeDelegatorLib.deployImpl();
        node1 = NodeDelegatorLib.deployProxy(nodeImpl, proxyAdmin, proxyFactory, 1);
        NodeDelegatorLib.initialize(node1, lrtConfig);

        node2 = NodeDelegatorLib.deployProxy(nodeImpl, proxyAdmin, proxyFactory, 2);
        NodeDelegatorLib.initialize(node2, lrtConfig);

        // Transfer SSV tokens to the native staking NodeDelegator
        // SSV Faucet https://faucet.ssv.network/
        IERC20(AddressesHolesky.SSV_TOKEN).transfer(address(node2), 30 ether);

        // Mock aggregators
        stETHPriceFeed = address(new MockPriceAggregator());
        console.log("Mock stETH Oracle: %s", stETHPriceFeed);
        rETHPriceFeed = address(new MockPriceAggregator());
        console.log("Mock rETH Oracle: %s", rETHPriceFeed);

        // Deploy new Prime Zapper
        PrimeZapperLib.deploy(address(primeETH), address(depositPool));

        // setup
        setUpByAdmin();
        setUpByManager();

        // WETH asset setup
        lrtConfig.addNewSupportedAsset(AddressesHolesky.WETH_TOKEN, MAX_DEPOSITS);
        lrtConfig.setToken(LRTConstants.WETH_TOKEN, AddressesHolesky.WETH_TOKEN);
        lrtOracle.updatePriceOracleFor(AddressesHolesky.WETH_TOKEN, wethOracleProxy);

        // update prETHPrice
        lrtOracle.updatePrimeETHPrice();

        proxyAdmin.transferOwnership(AddressesHolesky.PROXY_OWNER);
        console.log("ProxyAdmin ownership transferred to: ", AddressesHolesky.PROXY_OWNER);

        // transfer Admin role to Relayer
        // grant MANAGER_ROLE to deployer and Goerli Defender Relayer
        lrtConfig.grantRole(LRTConstants.MANAGER, AddressesHolesky.RELAYER);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, AddressesHolesky.RELAYER);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, AddressesHolesky.RELAYER);

        // transfer Manager role to Relayer

        // transfer Operator role to Relayer

        if (isForked) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
