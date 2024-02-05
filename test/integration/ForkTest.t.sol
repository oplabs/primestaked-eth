// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ForkTest is Test {
    uint256 public fork;

    LRTDepositPool public lrtDepositPool;
    LRTConfig public lrtConfig;
    PrimeStakedETH public preth;
    LRTOracle public lrtOracle;
    NodeDelegator public nodeDelegator1;
    address public admin;
    address public manager;

    address public stWhale;
    address public xWhale;
    address public oWhale;
    address public mWhale;
    address public frxWhale;
    address public rWhale;
    address public swWhale;

    string public referralId = "1234";

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        fork = vm.createSelectFork(url);

        admin = Addresses.ADMIN_ROLE;
        manager = Addresses.MANAGER_ROLE;

        stWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        xWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        oWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
        mWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
        frxWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        rWhale = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;
        swWhale = 0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6;

        lrtDepositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        nodeDelegator1 = NodeDelegator(payable(Addresses.NODE_DELEGATOR));
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

    function test_bulk_transfer_del_node() public {
        // TODO remove this once the Deposit Pool contract is upgraded
        // Need to upgrade the deposit pool contract first
        upgradeDepositPool();

        // // Should transfer `asset` from DepositPool to the Delegator node
        // vm.expectEmit({ emitter: asset, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        // emit Transfer(address(lrtDepositPool), address(nodeDelegator1), amountToTransfer);

        address[] memory assets = new address[](7);
        assets[0] = Addresses.STETH_TOKEN;
        assets[1] = Addresses.OETH_TOKEN;
        assets[2] = Addresses.ETHX_TOKEN;
        assets[3] = Addresses.METH_TOKEN;
        assets[4] = Addresses.SFRXETH_TOKEN;
        assets[5] = Addresses.RETH_TOKEN;
        assets[6] = Addresses.SWETH_TOKEN;

        vm.startPrank(manager);
        lrtDepositPool.transferAssetsToNodeDelegator(indexOfNodeDelegator, assets);

        // Run again with no assets
        lrtDepositPool.transferAssetsToNodeDelegator(indexOfNodeDelegator, assets);
        vm.stopPrank();
    }

    function test_transfer_eigen_OETH() public {
        unpauseStrategy(Addresses.OETH_EIGEN_STRATEGY);

        deposit(Addresses.OETH_TOKEN, oWhale, 1 ether);
        transfer_DelegatorNode(Addresses.OETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.OETH_TOKEN, Addresses.OETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_SFRX() public {
        unpauseStrategy(Addresses.SFRXETH_EIGEN_STRATEGY);

        deposit(Addresses.SFRXETH_TOKEN, frxWhale, 1 ether);
        transfer_DelegatorNode(Addresses.SFRXETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.SFRXETH_TOKEN, Addresses.SFRXETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_ETHX() public {
        unpauseStrategy(Addresses.ETHX_EIGEN_STRATEGY);

        deposit(Addresses.ETHX_TOKEN, xWhale, 1 ether);
        transfer_DelegatorNode(Addresses.ETHX_TOKEN, 1 ether);
        transfer_Eigen(Addresses.ETHX_TOKEN, Addresses.ETHX_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_mETH() public {
        unpauseStrategy(Addresses.METH_EIGEN_STRATEGY);

        deposit(Addresses.METH_TOKEN, mWhale, 1 ether);
        transfer_DelegatorNode(Addresses.METH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.METH_TOKEN, Addresses.METH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_STETH() public {
        unpauseStrategy(Addresses.STETH_EIGEN_STRATEGY);

        deposit(Addresses.STETH_TOKEN, stWhale, 1 ether);
        transfer_DelegatorNode(Addresses.STETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.STETH_TOKEN, Addresses.STETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_RETH() public {
        unpauseStrategy(Addresses.RETH_EIGEN_STRATEGY);

        deposit(Addresses.RETH_TOKEN, rWhale, 1 ether);
        transfer_DelegatorNode(Addresses.RETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.RETH_TOKEN, Addresses.RETH_EIGEN_STRATEGY);
    }

    function test_transfer_eigen_SWETH() public {
        unpauseStrategy(Addresses.SWETH_EIGEN_STRATEGY);

        deposit(Addresses.SWETH_TOKEN, swWhale, 1 ether);
        transfer_DelegatorNode(Addresses.SWETH_TOKEN, 1 ether);
        transfer_Eigen(Addresses.SWETH_TOKEN, Addresses.SWETH_EIGEN_STRATEGY);
    }

    // TODO basic primeETH token tests. eg transfer, approve, transferFrom

    function deposit(address asset, address whale, uint256 amountToTransfer) internal {
        vm.startPrank(whale);
        ERC20(asset).approve(address(lrtDepositPool), amountToTransfer);

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
    }

    function transfer_DelegatorNode(address asset, uint256 amountToTransfer) internal {
        vm.prank(manager);

        // Should transfer `asset` from DepositPool to the Delegator node
        vm.expectEmit({ emitter: asset, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        emit Transfer(address(lrtDepositPool), address(nodeDelegator1), amountToTransfer);

        lrtDepositPool.transferAssetToNodeDelegator(0, asset, amountToTransfer);
    }

    function transfer_Eigen(address asset, address strategy) internal {
        vm.prank(manager);

        // Should transfer `asset` from nodeDelegator to Eigen asset strategy
        vm.expectEmit({ emitter: asset, checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: false });
        emit Transfer(address(nodeDelegator1), strategy, 0);

        nodeDelegator1.depositAssetIntoStrategy(asset);
    }

    function unpauseStrategy(address strategyAddress) internal {
        vm.startPrank(Addresses.EIGEN_UNPAUSER);

        IStrategy eigenStrategy = IStrategy(strategyAddress);
        IStrategy eigenStrategyManager = IStrategy(Addresses.EIGEN_STRATEGY_MANAGER);

        // Unpause deposits and withdrawals
        eigenStrategyManager.unpause(0);
        eigenStrategy.unpause(0);

        vm.stopPrank();
    }

    function upgradeDepositPool() internal {
        LRTDepositPool newLrtDepositPool = new LRTDepositPool();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.LRT_DEPOSIT_POOL), address(newLrtDepositPool)
        );
    }

    function upgradeNodeDelegator() internal {
        NodeDelegator newNodeDelegator = new NodeDelegator();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(Addresses.PROXY_ADMIN).upgrade(
            ITransparentUpgradeableProxy(Addresses.NODE_DELEGATOR), address(newNodeDelegator)
        );
    }
}
