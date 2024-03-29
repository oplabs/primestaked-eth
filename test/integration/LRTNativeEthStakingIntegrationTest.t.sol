// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { LRTConfig, ILRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { OneETHPriceOracle } from "contracts/oracles/OneETHPriceOracle.sol";
import { NodeDelegator, ValidatorStakeData } from "contracts/NodeDelegator.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract SkipLRTNativeEthStakingIntegrationTest is Test {
    uint256 public fork;
    address public admin;
    address public manager;
    address public operator;

    ProxyAdmin proxyAdmin;
    LRTDepositPool public lrtDepositPool;
    LRTConfig public lrtConfig;
    PrimeStakedETH public preth;
    LRTOracle public lrtOracle;
    NodeDelegator public nodeDelegator1;
    address public WETHAddress;

    function _upgradeAllContracts() internal {
        vm.startPrank(admin);

        // Goerli WETH
        WETHAddress = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

        // upgrade lrtConfig
        address proxyAddress = address(lrtConfig);
        address newImplementation = address(new LRTConfig());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);

        // upgrade lrtDepositPool
        proxyAddress = address(lrtDepositPool);
        newImplementation = address(new LRTDepositPool());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);

        // remove faulty ndcs
        lrtDepositPool.removeNodeDelegatorContractFromQueue(0xAb96EB807c9dFE59E9d52f7F428A6D35f12728c6);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(0x2107EA068FD85E125Be422AFC86d2E57A6d085d8);

        // upgrade all ndcs
        address[] memory ndcs = lrtDepositPool.getNodeDelegatorQueue();
        assertEq(ndcs.length, 5, "Incorrect number of ndcs");
        newImplementation = address(new NodeDelegator(WETHAddress));
        for (uint256 i = 0; i < ndcs.length; i++) {
            proxyAddress = address(ndcs[i]);
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);
        }

        vm.stopPrank();

        // Add eth as supported asset
        vm.startPrank(manager);
        lrtConfig.addNewSupportedAsset(WETHAddress, 100_000 ether);

        // add oracle for ETH
        address oneETHOracle = address(new OneETHPriceOracle());
        lrtOracle.updatePriceOracleFor(WETHAddress, oneETHOracle);

        vm.stopPrank();
    }

    function setUp() public {
        string memory ethMainnetRPC = vm.envString("MAINNET_RPC_URL");
        fork = vm.createSelectFork(ethMainnetRPC);

        admin = 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2;
        manager = 0xCbcdd778AA25476F203814214dD3E9b9c46829A1;
        operator = makeAddr("operator");

        proxyAdmin = ProxyAdmin(0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78);
        lrtDepositPool = LRTDepositPool(payable(0x036676389e48133B63a802f8635AD39E752D375D));
        lrtConfig = LRTConfig(0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7);
        preth = PrimeStakedETH(0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7);
        lrtOracle = LRTOracle(0x349A73444b1a310BAe67ef67973022020d70020d);
        nodeDelegator1 = NodeDelegator(payable(0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473));

        // set eigen pod manager in lrt config
        address eigenPodManager = 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
        vm.startPrank(admin);
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, eigenPodManager);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, operator);
        vm.stopPrank();

        _upgradeAllContracts();
    }

    function test_completeNativeEthFlow() external {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);

        // deposit by user alice
        uint256 aliceBalanceBefore = alice.balance;
        uint256 depositPoolBalanceBefore = address(lrtDepositPool).balance;
        (
            uint256 assetLyingInDepositPoolInitially,
            uint256 assetLyingInNDCsInitially,
            uint256 assetStakedInEigenLayerInitially
        ) = lrtDepositPool.getAssetDistributionData(WETHAddress);

        uint256 depositAmount = 66 ether;
        vm.prank(alice);
        lrtDepositPool.depositAsset(WETHAddress, depositAmount, 0, "");

        uint256 aliceBalanceAfter = alice.balance;
        uint256 depositPoolBalanceAfter = address(lrtDepositPool).balance;
        (uint256 assetLyingInDepositPoolNow, uint256 assetLyingInNDCsNow, uint256 assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(WETHAddress);

        assertEq(aliceBalanceAfter, aliceBalanceBefore - depositAmount);
        assertEq(depositPoolBalanceAfter, depositPoolBalanceBefore + depositAmount);
        assertEq(
            assetLyingInDepositPoolNow,
            assetLyingInDepositPoolInitially + depositAmount,
            "eth not transferred to deposit pool"
        );
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially);
        assertEq(assetStakedInEigenLayerNow, assetStakedInEigenLayerInitially);

        // move eth from deposit pool to ndc
        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(0, WETHAddress, depositAmount);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(WETHAddress);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially + depositAmount, "eth not transferred to ndc 0");
        assertEq(assetStakedInEigenLayerNow, assetStakedInEigenLayerInitially);

        // create eigen pod
        vm.prank(manager);
        nodeDelegator1.createEigenPod();

        address eigenPod = address(nodeDelegator1.eigenPod());
        // same eigenPod address should be created
        assertEq(eigenPod, 0xf7483e448c1B94Ea557A53d99ebe7b4feE0c91df, "Wrong eigenPod address");

        // stake 32 eth for validator1
        ValidatorStakeData[] memory singleValidators = new ValidatorStakeData[](1);
        singleValidators[0] = ValidatorStakeData({
            pubkey: hex"8ff0088bf2bc73a41c74d1b1c6c997e4963ceffde55a09fef27596016d919b74b45372e8aa69fda5aac38a0c1a38dfd5",
            signature: hex"95e07ee28de0316ecdf9b528c222d81242898ee0095e284582bb453d331b7760"
                hex"6d8dca23ab8980459ea8a9b9710e2f740fceb1a1c221a7fd75eb3ef4a6b68809"
                hex"f3e76387f01f5d31718e6306375b20b29cb08d1374c7fb125d50c1b2f5a5cc0b",
            depositDataRoot: hex"6f30f44f0d8dada6ba5d8fd617c727020c01c697587d1a04ff6661be656198bc"
        });

        vm.prank(operator);
        nodeDelegator1.stakeEth(singleValidators);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(WETHAddress);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially + depositAmount - 32 ether);
        assertEq(
            assetStakedInEigenLayerNow,
            assetStakedInEigenLayerInitially + 32 ether,
            "eth not staked at eigen layer for val1"
        );

        // stake 32 eth for validator2
        singleValidators[0] = ValidatorStakeData({
            pubkey: hex"8f943ad38a85397243a5b2805cad3956f6bc46bcf001f58415ec9a14260fa449b1597a917393560f4a21d59852df30cc",
            signature: hex"88fda50f5197b4d3fc497bcabcd86f5d3c76ad67ff8e752bec96b74fc589ad27"
                hex"3eee3aa72e836a26447680966f5d70900eff7eaaa4d047fe6da5c3d6093aa63c"
                hex"614b443a82c74c9ebc1837efe2bef59e600e3f8008c7aac6bd2eacbffdbae6c4",
            depositDataRoot: hex"fb0f1cf653ff793cd5973b3847e2f91c8cbab3dd22d1c59a8cf86fc5879dc592"
        });

        vm.prank(operator);
        nodeDelegator1.stakeEth(singleValidators);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(WETHAddress);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially + depositAmount - 64 ether);
        assertEq(
            assetStakedInEigenLayerNow,
            assetStakedInEigenLayerInitially + 64 ether,
            "eth not staked at eigen layer for val2"
        );

        // transfer 2 ether back to deposit pool
        vm.prank(manager);
        nodeDelegator1.transferBackToLRTDepositPool(WETHAddress, 2 ether);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(WETHAddress);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially + 2 ether);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially);
        assertEq(
            assetStakedInEigenLayerNow,
            assetStakedInEigenLayerInitially + 64 ether,
            "eth not transferred back to deposit pool"
        );
    }
}
