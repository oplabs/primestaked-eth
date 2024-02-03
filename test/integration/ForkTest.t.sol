// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";
import { LRTDepositPool, ILRTDepositPool, LRTConstants } from "contracts/LRTDepositPool.sol";
import { LRTConfig, ILRTConfig } from "contracts/LRTConfig.sol";
import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { getLSTs } from "script/foundry-scripts/DeployLRT.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
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
    address public rethWhale;
    address public swethWhale;

    string public referralId = "1234";

    uint256 indexOfNodeDelegator;

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        fork = vm.createSelectFork(url);

        admin = Addresses.PROXY_OWNER;
        manager = Addresses.PROXY_OWNER;

        stWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        xWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        oWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
        mWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
        frxWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        rethWhale = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;
        swethWhale = 0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6;

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

    // function test_deposit_rETH() public {
    //     deposit(Addresses.RETH_TOKEN, rethWhale, 10 ether);
    // }

    // function test_deposit_swETH() public {
    //     deposit(Addresses.SWETH_TOKEN, swethWhale, 10 ether);
    // }

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

    function test_update_primeETH_price() public {
        // anyone can call
        lrtOracle.updatePrimeETHPrice();
    }

    function test_transfer_eigen_ETHX() public {
        unpauseStrategy(Addresses.ETHX_EIGEN_STRATEGY);

        deposit(Addresses.ETHX_TOKEN, xWhale, 1 ether);
        transfer_DelegatorNode(Addresses.ETHX_TOKEN, 1 ether);
        transfer_Eigen(Addresses.ETHX_TOKEN);
    }

    // TODO basic primeETH token tests. eg transfer, approve, transferFrom

    function deposit(address asset, address whale, uint256 amountToTransfer) internal {
        vm.startPrank(whale);
        ERC20(asset).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(asset, amountToTransfer, amountToTransfer * 99 / 100, referralId);

        // TODO check primeETH was minted
        // TODO check deposit pool balance increased

        vm.stopPrank();
    }

    function transfer_DelegatorNode(address asset, uint256 amountToTransfer) public {
        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, asset, amountToTransfer);

        // TODO check asset was transferred from DepositPool to Delegator Node
    }

    function transfer_Eigen(address asset) public {
        vm.prank(manager);
        nodeDelegator1.depositAssetIntoStrategy(asset);

        // TODO check asset was transferred from nodeDelegator to Eigen asset strategy
    }

    function unpauseStrategy(address strategyAddress) private {
        vm.startPrank(Addresses.EIGEN_UNPAUSER);

        IStrategy eigenStrategy = IStrategy(strategyAddress);
        IStrategy eigenStrategyManager = IStrategy(Addresses.EIGEN_STRATEGY_MANAGER);

        // Unpause deposits and withdrawals
        eigenStrategyManager.unpause(0);
        eigenStrategy.unpause(0);

        vm.stopPrank();
    }
}
