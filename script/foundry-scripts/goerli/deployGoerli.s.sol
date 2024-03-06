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
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { ConfigLib } from "contracts/libraries/ConfigLib.sol";
import { PrimeStakedETHLib } from "contracts/libraries/PrimeStakedETHLib.sol";
import { DepositPoolLib } from "contracts/libraries/DepositPoolLib.sol";
import { OraclesLib } from "contracts/libraries/OraclesLib.sol";
import { NodeDelegatorLib } from "contracts/libraries/NodeDelegatorLib.sol";
import { PrimeZapperLib } from "contracts/libraries/PrimeZapperLib.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

contract DeployGoerli is Script {
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
    address public ethXPriceOracleAddress;
    NodeDelegator public node1;
    NodeDelegator public node2;
    address[] public nodeDelegatorContracts;

    address stETHPriceFeed;
    address ethxPriceFeed;

    uint256 public minAmountToDeposit;

    function maxApproveToEigenStrategyManager(address nodeDel) internal {
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(AddressesGoerli.STETH_TOKEN);
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(AddressesGoerli.ETHX_TOKEN);
    }

    function setUpByAdmin() internal {
        // add primeETH to LRT config
        lrtConfig.setPrimeETH(address(primeETH));

        // add oracle to LRT config
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(lrtOracle));

        // add contracts to LRT config
        lrtConfig.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(depositPool));
        lrtConfig.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, AddressesGoerli.EIGEN_STRATEGY_MANAGER);
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, AddressesGoerli.EIGEN_POD_MANAGER);

        // call updateAssetStrategy for each asset in LRTConfig
        lrtConfig.updateAssetStrategy(AddressesGoerli.STETH_TOKEN, AddressesGoerli.STETH_EIGEN_STRATEGY);
        lrtConfig.updateAssetStrategy(AddressesGoerli.ETHX_TOKEN, AddressesGoerli.ETHX_EIGEN_STRATEGY);

        // Set SSV contract addresses in LRTConfig
        lrtConfig.setContract(LRTConstants.SSV_TOKEN, AddressesGoerli.SSV_TOKEN);
        lrtConfig.setContract(LRTConstants.SSV_NETWORK, AddressesGoerli.SSV_NETWORK);

        // grant MANAGER_ROLE to deployer and Goerli Defender Relayer
        lrtConfig.grantRole(LRTConstants.MANAGER, deployerAddress);
        lrtConfig.grantRole(LRTConstants.MANAGER, AddressesGoerli.RELAYER);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, deployerAddress);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, AddressesGoerli.RELAYER);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, deployerAddress);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, AddressesGoerli.RELAYER);

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
            AddressesGoerli.STETH_TOKEN, stETHPriceFeed
        );

        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracle.updatePriceOracleFor(AddressesGoerli.STETH_TOKEN, chainlinkPriceOracleAddress);
        lrtOracle.updatePriceOracleFor(AddressesGoerli.ETHX_TOKEN, ethXPriceOracleAddress);

        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(node1));
        maxApproveToEigenStrategyManager(address(node2));

        // Create and EigenPod for the 2nd NodeDelegator
        node2.createEigenPod();
    }

    function run() external {
        if (block.chainid != 5) {
            revert("Not Goerli");
        }

        isForked = vm.envOr("IS_FORK", false);
        if (isForked) {
            address mainnetProxyOwner = AddressesGoerli.PROXY_OWNER;
            console.log("Running script on Goerli fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            uint256 deployerPrivateKey = vm.envUint("GOERLI_DEPLOYER_PRIVATE_KEY");
            address deployer = vm.rememberKey(deployerPrivateKey);
            vm.startBroadcast(deployer);
            console.log("Deploying on Goerli with deployer: %s", deployer);
        }

        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();
        minAmountToDeposit = 0.0001 ether;

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

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
        ethXPriceOracleAddress = OraclesLib.deployInitEthXPriceOracle(proxyAdmin, proxyFactory);
        address wethOracleProxy = OraclesLib.deployInitWETHOracle(proxyAdmin, proxyFactory);

        // DelegatorNode
        address nodeImpl = NodeDelegatorLib.deployImpl();
        node1 = NodeDelegatorLib.deployProxy(nodeImpl, proxyAdmin, proxyFactory, 1);
        NodeDelegatorLib.initialize(node1, lrtConfig);

        node2 = NodeDelegatorLib.deployProxy(nodeImpl, proxyAdmin, proxyFactory, 2);
        NodeDelegatorLib.initialize(node2, lrtConfig);

        // Transfer SSV tokens to the native staking NodeDelegator
        // SSV Faucet https://faucet.ssv.network/
        IERC20(AddressesGoerli.SSV_TOKEN).transfer(address(node2), 30 ether);

        // Mock aggregators
        stETHPriceFeed = address(new MockPriceAggregator());

        // Deploy new Prime Zapper
        PrimeZapperLib.deploy();

        // setup
        setUpByAdmin();
        setUpByManager();

        // WETH asset setup
        lrtConfig.addNewSupportedAsset(AddressesGoerli.WETH_TOKEN, MAX_DEPOSITS);
        lrtConfig.setToken(LRTConstants.WETH_TOKEN, AddressesGoerli.WETH_TOKEN);
        lrtOracle.updatePriceOracleFor(AddressesGoerli.WETH_TOKEN, wethOracleProxy);

        // update prETHPrice
        lrtOracle.updatePrimeETHPrice();

        proxyAdmin.transferOwnership(AddressesGoerli.PROXY_OWNER);
        console.log("ProxyAdmin ownership transferred to: ", AddressesGoerli.PROXY_OWNER);

        // Approve deposit of WETH into the DepositPool
        IERC20(AddressesGoerli.WETH_TOKEN).approve(address(depositPool), MAX_DEPOSITS);

        if (isForked) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
