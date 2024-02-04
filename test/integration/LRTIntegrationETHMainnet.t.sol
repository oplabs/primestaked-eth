// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/console.sol";

import {
    LRTIntegrationTest,
    ERC20,
    NodeDelegator,
    LRTOracle,
    PrimeStakedETH,
    LRTConfig,
    LRTDepositPool
} from "./LRTIntegrationTest.t.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

contract SkipLRTIntegrationTestETHMainnet is LRTIntegrationTest {
    function setUp() public override {
        string memory ethMainnetRPC = vm.envString("MAINNET_RPC_URL");
        fork = vm.createSelectFork(ethMainnetRPC);

        admin = Addresses.ADMIN_ROLE;
        manager = Addresses.MANAGER_ROLE;

        stWhale = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        ethXWhale = 0x1a0EBB8B15c61879a8e8DA7817Bb94374A7c4007;

        lrtConfig = LRTConfig(0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF);
        preth = PrimeStakedETH(0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615);

        // TODO update below addresses with deployed versions
        lrtDepositPool = LRTDepositPool(payable(0x551125a39bCf4E85e9B62467DfD2c1FeF3998f19));
        lrtOracle = LRTOracle(0xDE2336F1a4Ed7749F08F994785f61b5995FcD560);
        nodeDelegator1 = NodeDelegator(payable(0xfFEB12Eb6C339E1AAD48A7043A98779F6bF03Cfd));

        //stEthOracle = 0x46E6D75E5784200F21e4cCB7d8b2ff8e20996f52;
        //ethxPriceOracle = 0x4df5Cea2954CEafbF079c2d23a9271681D15cf67;

        EIGEN_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
        EIGEN_STETH_STRATEGY = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
        EIGEN_ETHX_STRATEGY = 0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d;

        stETHAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        ethXAddress = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;

        amountToTransfer = 0.11 ether;

        vm.startPrank(ethXWhale);
        ERC20(ethXAddress).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(ethXAddress, amountToTransfer, minPrimeAmount, referralId);
        vm.stopPrank();

        uint256 indexOfNodeDelegator = 0;

        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, ethXAddress, amountToTransfer);
    }
}
