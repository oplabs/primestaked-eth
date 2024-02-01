// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { OETHPriceOracle } from "contracts/oracles/OETHPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

function getLSTs() view returns (address stETH, address oeth) {
    uint256 chainId = block.chainid;

    if (chainId == 1) {
        // mainnet
        stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        oeth = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
    } else if (chainId == 5) {
        // goerli
        stETH = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
        // No OETH on Goerli
        oeth = 0x0000000000000000000000000000000000000000;
    } else {
        revert("Unsupported network");
    }
}

contract DeployLRT is Script {
    address public proxyAdminOwner;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    PrimeStakedETH public PRETHProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    LRTOracle public lrtOracleProxy;
    ChainlinkPriceOracle public chainlinkPriceOracleProxy;
    OETHPriceOracle public oethPriceOracleProxy;
    NodeDelegator public nodeDelegatorProxy1;
    NodeDelegator public nodeDelegatorProxy2;
    NodeDelegator public nodeDelegatorProxy3;
    NodeDelegator public nodeDelegatorProxy4;
    NodeDelegator public nodeDelegatorProxy5;
    address[] public nodeDelegatorContracts;

    uint256 public minAmountToDeposit;

    function maxApproveToEigenStrategyManager(address nodeDel) private {
        (address stETH, address oeth) = getLSTs();
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(stETH);
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(oeth);
    }

    function getAssetStrategies()
        private
        view
        returns (address strategyManager, address stETHStrategy, address oethStrategy)
    {
        uint256 chainId = block.chainid;
        // https://github.com/Layr-Labs/eigenlayer-contracts#deployments
        if (chainId == 1) {
            // mainnet
            strategyManager = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
            stETHStrategy = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
            // TODO: NEED TO HAVE OETH STRATEGY
            oethStrategy = 0x0000000000000000000000000000000000000000;
        } else {
            // testnet
            strategyManager = 0x779d1b5315df083e3F9E94cB495983500bA8E907;
            stETHStrategy = 0xB613E78E2068d7489bb66419fB1cfa11275d14da;
            // TODO: NEED TO HAVE OETH STRATEGY
            oethStrategy = 0x0000000000000000000000000000000000000000;
        }
    }

    function getPriceFeeds() private returns (address stETHPriceFeed, address oethPriceFeed) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // mainnet
            stETHPriceFeed = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
            oethPriceFeed = address(oethPriceOracleProxy);
        } else {
            // testnet
            stETHPriceFeed = address(new MockPriceAggregator());
            oethPriceFeed = address(oethPriceOracleProxy);
        }
    }

    function setUpByAdmin() private {
        (address stETH, address oeth) = getLSTs();
        // ----------- callable by admin ----------------

        // add prETH to LRT config
        lrtConfigProxy.setPRETH(address(PRETHProxy));
        // add oracle to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleProxy));
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));
        // call updateAssetStrategy for each asset in LRTConfig
        (address strategyManager, address stETHStrategy, address oethStrategy) = getAssetStrategies();
        lrtConfigProxy.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, strategyManager);
        lrtConfigProxy.updateAssetStrategy(stETH, stETHStrategy);
        // TODO: NEED TO HAVE OETH STRATEGY
        // lrtConfigProxy.updateAssetStrategy(oeth, oethStrategy);

        // grant MANAGER_ROLE to an address in LRTConfig
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, proxyAdminOwner);
        // add minter role to lrtDepositPool so it mints prETH
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
        (address stETH, address oeth) = getLSTs();
        // --------- callable by manager -----------

        (address stETHPriceFeed, address oethPriceFeed) = getPriceFeeds();

        // Add chainlink oracles for supported assets in ChainlinkPriceOracle
        chainlinkPriceOracleProxy.updatePriceFeedFor(stETH, stETHPriceFeed);

        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracleProxy.updatePriceOracleFor(address(oeth), address(chainlinkPriceOracleProxy));
        lrtOracleProxy.updatePriceOracleFor(address(stETH), address(oethPriceFeed));

        // maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy1));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy2));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy3));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy4));
        maxApproveToEigenStrategyManager(address(nodeDelegatorProxy5));
    }

    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked("LRT-Origin"));
        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        proxyAdminOwner = proxyAdmin.owner();
        minAmountToDeposit = 0.0001 ether;

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Owner of ProxyAdmin: ", proxyAdminOwner);

        // deploy implementation contracts
        address lrtConfigImplementation = address(new LRTConfig());
        address PRETHImplementation = address(new PrimeStakedETH());
        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        address lrtOracleImplementation = address(new LRTOracle());
        address chainlinkPriceOracleImplementation = address(new ChainlinkPriceOracle());
        address oethPriceOracleImplementation = address(new OETHPriceOracle());
        address nodeDelegatorImplementation = address(new NodeDelegator());

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        console.log("LRTConfig implementation deployed at: ", lrtConfigImplementation);
        console.log("PrimeStakedETH implementation deployed at: ", PRETHImplementation);
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("LRTOracle implementation deployed at: ", lrtOracleImplementation);
        console.log("ChainlinkPriceOracle implementation deployed at: ", chainlinkPriceOracleImplementation);
        console.log("OETHPriceOracle implementation deployed at: ", oethPriceOracleImplementation);
        console.log("NodeDelegator implementation deployed at: ", nodeDelegatorImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        // deploy proxy contracts and initialize them
        lrtConfigProxy = LRTConfig(proxyFactory.create(address(lrtConfigImplementation), address(proxyAdmin), salt));

        // set up LRTConfig init params
        (address stETH, address oeth) = getLSTs();
        address predictedPRETHAddress = proxyFactory.computeAddress(PRETHImplementation, address(proxyAdmin), salt);
        console.log("predictedPRETHAddress: ", predictedPRETHAddress);
        // init LRTConfig
        lrtConfigProxy.initialize(proxyAdminOwner, stETH, oeth, predictedPRETHAddress);

        PRETHProxy = PrimeStakedETH(proxyFactory.create(address(PRETHImplementation), address(proxyAdmin), salt));
        // init PrimeStakedETH
        PRETHProxy.initialize(proxyAdminOwner, address(lrtConfigProxy));

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

        oethPriceOracleProxy =
            OETHPriceOracle(proxyFactory.create(address(oethPriceOracleImplementation), address(proxyAdmin), salt));

        nodeDelegatorProxy1 =
            NodeDelegator(payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt)));
        bytes32 saltForNodeDelegator2 = keccak256(abi.encodePacked("LRT-Origin-nodeDelegator2"));
        nodeDelegatorProxy2 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator2)
            )
        );
        bytes32 saltForNodeDelegator3 = keccak256(abi.encodePacked("LRT-Origin-nodeDelegator3"));
        nodeDelegatorProxy3 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator3)
            )
        );
        bytes32 saltForNodeDelegator4 = keccak256(abi.encodePacked("LRT-Origin-nodeDelegator4"));
        nodeDelegatorProxy4 = NodeDelegator(
            payable(
                proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltForNodeDelegator4)
            )
        );
        bytes32 saltForNodeDelegator5 = keccak256(abi.encodePacked("LRT-Origin-nodeDelegator5"));
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
        console.log("OETHPriceOracle proxy deployed at: ", address(oethPriceOracleProxy));
        console.log("NodeDelegator proxy 1 deployed at: ", address(nodeDelegatorProxy1));
        console.log("NodeDelegator proxy 2 deployed at: ", address(nodeDelegatorProxy2));
        console.log("NodeDelegator proxy 3 deployed at: ", address(nodeDelegatorProxy3));
        console.log("NodeDelegator proxy 4 deployed at: ", address(nodeDelegatorProxy4));
        console.log("NodeDelegator proxy 5 deployed at: ", address(nodeDelegatorProxy5));

        // setup
        setUpByAdmin();
        setUpByManager();

        // update prETHPrice
        lrtOracleProxy.updatePRETHPrice();

        // TODO: Check for the correct multisig addresses
        address manager = 0xFc015a866aA06dDcaD27Fe425bdd362a8927544D;
        lrtConfigProxy.grantRole(LRTConstants.MANAGER, manager);
        lrtConfigProxy.revokeRole(LRTConstants.MANAGER, proxyAdminOwner);
        address admin = 0xA65E2f72930219C4ce846FB245Ae18700296C328;
        lrtConfigProxy.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin);
        lrtConfigProxy.revokeRole(LRTConstants.DEFAULT_ADMIN_ROLE, proxyAdminOwner);
        proxyAdmin.transferOwnership(admin);

        vm.stopBroadcast();
    }
}
