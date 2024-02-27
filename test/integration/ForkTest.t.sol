// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";
import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { IWETH } from "contracts/interfaces/IWETH.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator, ValidatorStakeData } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { WETHPriceOracle } from "contracts/oracles/WETHPriceOracle.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { DeployAll } from "script/foundry-scripts/mainnet/00_deployAll.sol";

contract ForkTest is Test {
    uint256 public fork;

    LRTDepositPool public lrtDepositPool;
    PrimeStakedETH public preth;
    LRTOracle public lrtOracle;
    NodeDelegator public nodeDelegator1;
    NodeDelegator public nodeDelegator2;
    PrimeZapper public primeZapper;

    address public stWhale;
    address public xWhale;
    address public oWhale;
    address public mWhale;
    address public frxWhale;
    address public rWhale;
    address public swWhale;
    address public wWhale;
    address public wWhale2;

    string public referralId = "1234";

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        fork = vm.createSelectFork(url);

        stWhale = 0xd8d041705735cd770408AD31F883448851F2C39d;
        xWhale = 0x1a0EBB8B15c61879a8e8DA7817Bb94374A7c4007;
        oWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
        mWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
        frxWhale = 0x46782D268FAD71DaC3383Ccf2dfc44C861fb4c7D;
        rWhale = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;
        swWhale = 0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6;
        wWhale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
        // WETH whale that is not a contract
        wWhale2 = 0x267ed5f71EE47D3E45Bb1569Aa37889a2d10f91e;

        lrtDepositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
        nodeDelegator1 = NodeDelegator(payable(Addresses.NODE_DELEGATOR));
        nodeDelegator2 = NodeDelegator(payable(Addresses.NODE_DELEGATOR_NATIVE_STAKING));

        // Any pending deployments or configuration changes
        DeployAll deployer = new DeployAll();
        deployer.run();
        primeZapper = PrimeZapper(payable(deployer.primeZapper()));

        // Unpause Prime Staked if its paused
        unpausePrime();

        // Unpause all EigenLayer deposits
        unpauseAllStrategies();
    }

    function test_deposit_WETH() public {
        deposit(Addresses.WETH_TOKEN, wWhale, 20 ether);
    }

    function test_deposit_ETH() public {
        vm.prank(wWhale2);
        IWETH(Addresses.WETH_TOKEN).withdraw(20 ether);

        depositETH(wWhale2, 20 ether, false);
    }

    function test_deposit_ETH_call() public {
        vm.prank(wWhale2);
        IWETH(Addresses.WETH_TOKEN).withdraw(20 ether);

        depositETH(wWhale2, 20 ether, true);
    }

    function test_transfer_del_node_WETH() public {
        uint256 transferAmount = 18 ether;
        address asset = Addresses.WETH_TOKEN;
        deposit(asset, wWhale, 20 ether);

        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        vm.prank(Addresses.OPERATOR_ROLE);

        // Should transfer `asset` from DepositPool to the Delegator node
        vm.expectEmit(asset);
        emit Transfer(address(lrtDepositPool), address(nodeDelegator2), transferAmount);

        lrtDepositPool.transferAssetToNodeDelegator(1, asset, transferAmount);

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        // Check the asset distribution across the DepositPool, NDCs and EigenLayer
        // stETH can leave a dust amount behind so using assertApproxEqAbs
        assertEq(assetsDepositPoolAfter, assetsDepositPoolBefore - transferAmount, "assets in DepositPool");
        assertEq(assetsNDCsAfter, assetsNDCsBefore + transferAmount, "assets in NDCs");
        assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer");
    }

    function test_ETH_rewards() public {
        uint256 transferAmount = 18 ether;
        address asset = Addresses.WETH_TOKEN;
        deposit(asset, wWhale, 30 ether);

        vm.prank(Addresses.OPERATOR_ROLE);
        lrtDepositPool.transferAssetToNodeDelegator(1, asset, transferAmount);

        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        // Add ETH to the Node Delegator to simulate ETH rewards
        vm.deal(Addresses.NODE_DELEGATOR_NATIVE_STAKING, 0.01 ether);

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        assertEq(assetsDepositPoolAfter, assetsDepositPoolBefore, "assets in DepositPool");
        assertEq(assetsNDCsAfter, assetsNDCsBefore + 0.01 ether, "assets in NDCs");
        assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer");
    }

    function test_stakeETH() public {
        uint256 transferAmount = 32 ether;
        address asset = Addresses.WETH_TOKEN;
        deposit(asset, wWhale, transferAmount);

        vm.startPrank(Addresses.OPERATOR_ROLE);

        // Should transfer `asset` from DepositPool to the Delegator node
        vm.expectEmit(asset);
        emit Transfer(address(lrtDepositPool), address(nodeDelegator2), transferAmount);

        lrtDepositPool.transferAssetToNodeDelegator(1, asset, transferAmount);

        // TODO set once we have a mainnet validator
        // example from block 19230613
        ValidatorStakeData[] memory validatorStakeData = new ValidatorStakeData[](1);
        validatorStakeData[0] = ValidatorStakeData({
            pubkey: hex"a01db1511b1eda57efff93b72dbdcc4b59d498128cb1ec3bc9cd4feae00ece6085db328e62076783fe35e3db95c9820e",
            signature: hex"9689c71f8e9d146e1060f9c6a63f62b62c078b1254c0a8c36422c3ab8a9fa16f"
                hex"0c5bef3a2b0ca236c6eb09d1c7ab1016139be26747fb8e70324df3bfa4746fa0"
                hex"c5fd15a0601ad92a91346a180edce8101a8761aa7e4fe2cfc15274e58559b96a",
            depositDataRoot: 0x414008be8f8c3ef14b7a8fb4cb155f3d036f61440e0c84ba41173fdb3ff5e04b
        });

        // TODO uncomment once we have a mainnet validator
        // nodeDelegator2.stakeEth(validatorStakeData);
        vm.stopPrank();
    }

    function test_transferBackWETH() public {
        // transferBackToLRTDepositPool
        address asset = Addresses.WETH_TOKEN;
        deposit(asset, wWhale, 20 ether);

        vm.prank(Addresses.OPERATOR_ROLE);
        lrtDepositPool.transferAssetToNodeDelegator(1, asset, 20 ether);

        // Add some ETH to the Node Delegator to simulate ETH rewards
        vm.deal(Addresses.NODE_DELEGATOR_NATIVE_STAKING, 10 ether);

        vm.prank(Addresses.MANAGER_ROLE);
        nodeDelegator2.transferBackToLRTDepositPool(asset, 30 ether);
    }

    function test_revertWhenSecondCreatePod() public {
        vm.startPrank(Addresses.ADMIN_ROLE);
        vm.expectRevert("EigenPodManager.createPod: Sender already has a pod");
        nodeDelegator2.createEigenPod();
        vm.stopPrank();
    }

    function test_deposit_stETH() public {
        deposit(Addresses.STETH_TOKEN, stWhale, 0.1 ether);
    }

    function test_deposit_OETH() public {
        deposit(Addresses.OETH_TOKEN, oWhale, 1 ether);
    }

    function test_deposit_ETHx() public {
        deposit(Addresses.ETHX_TOKEN, xWhale, 2 ether);
    }

    function test_deposit_mETH() public {
        deposit(Addresses.METH_TOKEN, mWhale, 8 ether);
    }

    function test_deposit_sfrxETH() public {
        deposit(Addresses.SFRXETH_TOKEN, frxWhale, 10 ether);
    }

    function test_deposit_rETH() public {
        deposit(Addresses.RETH_TOKEN, rWhale, 10 ether);
    }

    function test_deposit_swETH() public {
        deposit(Addresses.SWETH_TOKEN, swWhale, 10 ether);
    }

    function test_transfer_del_node_stETH() public {
        deposit(Addresses.STETH_TOKEN, stWhale, 1 ether);
        transfer_DelegatorNode(Addresses.STETH_TOKEN, 0.8 ether);
    }

    function test_transfer_del_node_OETH() public {
        deposit(Addresses.OETH_TOKEN, oWhale, 1 ether);
        transfer_DelegatorNode(Addresses.OETH_TOKEN, 0.1 ether);
    }

    function test_transfer_del_node_ETHx() public {
        deposit(Addresses.ETHX_TOKEN, xWhale, 2 ether);
        transfer_DelegatorNode(Addresses.ETHX_TOKEN, 1.2 ether);
    }

    function test_transfer_del_node_mETH() public {
        deposit(Addresses.METH_TOKEN, mWhale, 5 ether);
        transfer_DelegatorNode(Addresses.METH_TOKEN, 5 ether);
    }

    function test_transfer_del_node_sfrxETH() public {
        deposit(Addresses.SFRXETH_TOKEN, frxWhale, 2 ether);
        transfer_DelegatorNode(Addresses.SFRXETH_TOKEN, 1.2 ether);
    }

    function test_transfer_del_node_rETH() public {
        deposit(Addresses.RETH_TOKEN, rWhale, 2 ether);
        transfer_DelegatorNode(Addresses.RETH_TOKEN, 1.2 ether);
    }

    function test_transfer_del_node_swETH() public {
        deposit(Addresses.SWETH_TOKEN, swWhale, 2 ether);
        transfer_DelegatorNode(Addresses.SWETH_TOKEN, 1.2 ether);
    }

    function test_update_primeETH_price() public {
        // anyone can call
        vm.prank(address(1));
        lrtOracle.updatePrimeETHPrice();
    }

    function test_bulk_transfer_all_eigen() public {
        deposit(Addresses.STETH_TOKEN, stWhale, 10 ether);
        deposit(Addresses.OETH_TOKEN, oWhale, 11 ether);
        deposit(Addresses.ETHX_TOKEN, xWhale, 12 ether);
        deposit(Addresses.METH_TOKEN, mWhale, 13 ether);
        deposit(Addresses.SFRXETH_TOKEN, frxWhale, 14 ether);
        deposit(Addresses.RETH_TOKEN, rWhale, 15 ether);
        deposit(Addresses.SWETH_TOKEN, swWhale, 16 ether);

        (address[] memory balAssets, uint256[] memory assetBalancesBefore) = nodeDelegator1.getAssetBalances();

        address[] memory assets = new address[](7);
        assets[0] = Addresses.STETH_TOKEN;
        assets[1] = Addresses.OETH_TOKEN;
        assets[2] = Addresses.ETHX_TOKEN;
        assets[3] = Addresses.METH_TOKEN;
        assets[4] = Addresses.SFRXETH_TOKEN;
        assets[5] = Addresses.RETH_TOKEN;
        assets[6] = Addresses.SWETH_TOKEN;

        uint256 nodeDelegatorIndex = 0;

        // Should transfer `asset` from DepositPool to the Delegator node
        uint256 stEthBalanceBefore = IERC20(Addresses.STETH_TOKEN).balanceOf(address(lrtDepositPool));
        uint256 oethBalanceBefore = IERC20(Addresses.OETH_TOKEN).balanceOf(address(lrtDepositPool));

        vm.expectEmit(Addresses.STETH_TOKEN);
        emit Transfer(address(lrtDepositPool), address(nodeDelegator1), stEthBalanceBefore);

        vm.expectEmit(Addresses.OETH_TOKEN);
        emit Transfer(address(lrtDepositPool), address(nodeDelegator1), oethBalanceBefore);

        vm.startPrank(Addresses.OPERATOR_ROLE);
        // Transfer assets to NodeDelegator
        lrtDepositPool.transferAssetsToNodeDelegator(nodeDelegatorIndex, assets);
        // Run again with no assets
        lrtDepositPool.transferAssetsToNodeDelegator(nodeDelegatorIndex, assets);

        // Deposit assets in EigenLayer
        nodeDelegator1.depositAssetsIntoStrategy(assets);
        // Run again with no assets
        nodeDelegator1.depositAssetsIntoStrategy(assets);
        vm.stopPrank();

        // Check balance in NodeDelegator
        (, uint256[] memory assetBalancesAfter) = nodeDelegator1.getAssetBalances();
        assertEq(balAssets[0], Addresses.STETH_TOKEN, "incorrect asset at index 0");
        assertApproxEqAbs(
            assetBalancesAfter[0] - assetBalancesBefore[0], 10 ether, 2, "incorrect index 0 asset balance"
        );
        assertEq(balAssets[6], Addresses.SWETH_TOKEN, "incorrect asset at index 6");
        assertApproxEqAbs(
            assetBalancesAfter[6] - assetBalancesBefore[6], 16 ether, 2, "incorrect index 5 asset balance"
        );
        assertEq(balAssets[7], Addresses.WETH_TOKEN, "incorrect asset at index 7");
        assertEq(assetBalancesAfter[7], 0, "incorrect index 6 asset balance");

        // Get gas costs of calling a Node Delegator that only has native ETH
        nodeDelegator2.getAssetBalances();
    }

    function test_bulk_transfer_some_eigen() public {
        // Should transfer `asset` from DepositPool to the Delegator node
        uint256 stEthBalanceBefore = IERC20(Addresses.STETH_TOKEN).balanceOf(address(lrtDepositPool));
        vm.expectEmit(Addresses.STETH_TOKEN);
        emit Transfer(address(lrtDepositPool), address(nodeDelegator1), stEthBalanceBefore);

        address[] memory assets = new address[](3);
        assets[0] = Addresses.STETH_TOKEN;
        assets[1] = Addresses.OETH_TOKEN;
        assets[2] = Addresses.METH_TOKEN;

        uint256 nodeDelegatorIndex = 0;

        vm.startPrank(Addresses.OPERATOR_ROLE);
        lrtDepositPool.transferAssetsToNodeDelegator(nodeDelegatorIndex, assets);

        nodeDelegator1.depositAssetsIntoStrategy(assets);
        nodeDelegator1.depositAssetsIntoStrategy(assets);

        vm.stopPrank();
    }

    function test_transfer_eigen_OETH() public {
        deposit(Addresses.OETH_TOKEN, oWhale, 1 ether);
        transfer_DelegatorNode(Addresses.OETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.OETH_TOKEN, Addresses.OETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_SFRX() public {
        deposit(Addresses.SFRXETH_TOKEN, frxWhale, 1 ether);
        transfer_DelegatorNode(Addresses.SFRXETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.SFRXETH_TOKEN, Addresses.SFRXETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_ETHX() public {
        deposit(Addresses.ETHX_TOKEN, xWhale, 1 ether);
        transfer_DelegatorNode(Addresses.ETHX_TOKEN, 1 ether);
        transfer_Eigen(Addresses.ETHX_TOKEN, Addresses.ETHX_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_mETH() public {
        deposit(Addresses.METH_TOKEN, mWhale, 1 ether);
        transfer_DelegatorNode(Addresses.METH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.METH_TOKEN, Addresses.METH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_STETH() public {
        deposit(Addresses.STETH_TOKEN, stWhale, 1 ether);
        transfer_DelegatorNode(Addresses.STETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.STETH_TOKEN, Addresses.STETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_RETH() public {
        deposit(Addresses.RETH_TOKEN, rWhale, 1 ether);
        transfer_DelegatorNode(Addresses.RETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.RETH_TOKEN, Addresses.RETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_SWETH() public {
        deposit(Addresses.SWETH_TOKEN, swWhale, 1 ether);
        transfer_DelegatorNode(Addresses.SWETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.SWETH_TOKEN, Addresses.SWETH_EIGEN_STRATEGY);
    }

    // TODO basic primeETH token tests. eg transfer, approve, transferFrom

    function depositETH(address whale, uint256 amountToTransfer, bool sendEthWithACall) internal {
        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(Addresses.WETH_TOKEN);

        vm.startPrank(whale);

        // Should transfer WETH from zapper to pool
        vm.expectEmit({ emitter: Addresses.WETH_TOKEN, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        emit Transfer(address(primeZapper), address(lrtDepositPool), amountToTransfer);

        // Should mint primeETH
        vm.expectEmit({
            emitter: Addresses.PRIME_STAKED_ETH,
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
        
        emit Transfer(address(0), address(primeZapper), amountToTransfer);

        if (sendEthWithACall) {
            address(primeZapper).call{ value: amountToTransfer }("");
        } else {
            primeZapper.deposit{ value: amountToTransfer }(amountToTransfer * 99 / 100, referralId);
        }

        vm.stopPrank();

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(Addresses.WETH_TOKEN);

        // Check the asset distribution across the DepositPool, NDCs and EigenLayer
        // stETH can leave a dust amount behind so using assertApproxEqAbs
        assertApproxEqAbs(
            assetsDepositPoolAfter, assetsDepositPoolBefore + amountToTransfer, 1, "assets in DepositPool"
        );
        assertEq(assetsNDCsAfter, assetsNDCsBefore, "assets in NDCs");
        assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer");
    }

    function deposit(address asset, address whale, uint256 amountToTransfer) internal {
        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        vm.startPrank(whale);
        IERC20(asset).approve(address(lrtDepositPool), amountToTransfer);

        // Should transfer `asset` from whale to pool
        vm.expectEmit({ emitter: asset, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        emit Transfer(whale, address(lrtDepositPool), amountToTransfer);

        // Should mint primeETH
        vm.expectEmit({
            emitter: Addresses.PRIME_STAKED_ETH,
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
        emit Transfer(address(0), whale, amountToTransfer);

        lrtDepositPool.depositAsset(asset, amountToTransfer, amountToTransfer * 99 / 100, referralId);
        vm.stopPrank();

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        // Check the asset distribution across the DepositPool, NDCs and EigenLayer
        // stETH can leave a dust amount behind so using assertApproxEqAbs
        assertApproxEqAbs(
            assetsDepositPoolAfter, assetsDepositPoolBefore + amountToTransfer, 1, "assets in DepositPool"
        );
        assertEq(assetsNDCsAfter, assetsNDCsBefore, "assets in NDCs");
        // TODO something weird is happening with swETH
        //   assetsElBefore  9846531018815036558
        //   assetsElAfter   9846058182313137210
        if (asset != Addresses.SWETH_TOKEN) {
            assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer");
        }
    }

    function transfer_DelegatorNode(address asset, uint256 amountToTransfer) internal {
        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        vm.prank(Addresses.OPERATOR_ROLE);

        // Should transfer `asset` from DepositPool to the Delegator node
        vm.expectEmit({ emitter: asset, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        emit Transfer(address(lrtDepositPool), address(nodeDelegator1), amountToTransfer);

        lrtDepositPool.transferAssetToNodeDelegator(0, asset, amountToTransfer);

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        // Check the asset distribution across the DepositPool, NDCs and EigenLayer
        // stETH can leave a dust amount behind so using assertApproxEqAbs
        assertApproxEqAbs(
            assetsDepositPoolAfter,
            assetsDepositPoolBefore - amountToTransfer,
            2,
            "assets in DepositPool did not decrease"
        );
        assertApproxEqAbs(assetsNDCsAfter, assetsNDCsBefore + amountToTransfer, 2, "assets in NDCs did not increase");
        assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer should not change");
    }

    function transfer_Eigen(address asset, address strategy) internal {
        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        vm.prank(Addresses.OPERATOR_ROLE);

        // Should transfer `asset` from nodeDelegator to Eigen asset strategy
        vm.expectEmit({ emitter: asset, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        emit Transfer(address(nodeDelegator1), strategy, 0);

        nodeDelegator1.depositAssetIntoStrategy(asset);

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        // Check the asset distribution across the DepositPool, NDCs and EigenLayer
        // stETH can leave a dust amount behind so using assertApproxEqAbs
        assertEq(assetsDepositPoolAfter, assetsDepositPoolBefore, "assets in DepositPool");
        assertLe(assetsNDCsAfter, 1, "assets in NDCs");
        assertApproxEqAbs(assetsElAfter, assetsElBefore + assetsNDCsBefore, 1, "assets in EigenLayer");
    }

    function test_approveSSV() public {
        vm.prank(Addresses.MANAGER_ROLE);

        vm.expectEmit(Addresses.SSV_TOKEN);
        emit Approval(address(nodeDelegator2), Addresses.SSV_NETWORK, type(uint256).max);

        nodeDelegator2.approveSSV();
    }

    function unpausePrime() internal {
        if (lrtDepositPool.paused()) {
            vm.prank(Addresses.MANAGER_ROLE);
            lrtDepositPool.unpause();
        }
    }

    /// @dev unpause an EigenLayer Strategy is currently paused
    function unpauseStrategy(address strategyAddress) internal {
        IStrategy eigenStrategy = IStrategy(strategyAddress);
        IStrategy eigenStrategyManager = IStrategy(Addresses.EIGEN_STRATEGY_MANAGER);

        vm.startPrank(Addresses.EIGEN_UNPAUSER);

        // only unpause strategy if already paused
        if (eigenStrategy.paused(0)) {
            // Unpause deposits and withdrawals
            eigenStrategy.unpause(0);
        }

        // only unpause strategy manager if already paused
        if (eigenStrategyManager.paused(0)) {
            // Unpause deposits and withdrawals
            eigenStrategyManager.unpause(0);
        }

        vm.stopPrank();
    }

    function unpauseAllStrategies() internal {
        unpauseStrategy(Addresses.STETH_EIGEN_STRATEGY);
        unpauseStrategy(Addresses.OETH_EIGEN_STRATEGY);
        unpauseStrategy(Addresses.METH_EIGEN_STRATEGY);
        unpauseStrategy(Addresses.SFRXETH_EIGEN_STRATEGY);
        unpauseStrategy(Addresses.ETHX_EIGEN_STRATEGY);
        unpauseStrategy(Addresses.RETH_EIGEN_STRATEGY);
        unpauseStrategy(Addresses.SWETH_EIGEN_STRATEGY);
    }
}
