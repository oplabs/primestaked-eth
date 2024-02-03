// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";
import { LRTDepositPool, ILRTDepositPool, LRTConstants } from "contracts/LRTDepositPool.sol";
import { LRTConfig, ILRTConfig } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";
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

    address public stETHAddress;
    address public ethXAddress;
    address public oethAddress;
    address public methAddress;
    address public sfrxEthAddress;

    address public stWhale;
    address public xWhale;
    address public oWhale;
    address public mWhale;
    address public frxWhale;

    string public referralId = "1234";

    uint256 indexOfNodeDelegator;

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        fork = vm.createSelectFork(url);

        admin = 0x7fbd78ae99151A3cfE46824Cd6189F28c8C45168;
        manager = 0x7fbd78ae99151A3cfE46824Cd6189F28c8C45168;

        stWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        xWhale = 0x036676389e48133B63a802f8635AD39E752D375D;
        oWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
        mWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
        frxWhale = 0x036676389e48133B63a802f8635AD39E752D375D;

        lrtDepositPool = LRTDepositPool(payable(0xA479582c8b64533102F6F528774C536e354B8d32));
        lrtOracle = LRTOracle(0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32);
        nodeDelegator1 = NodeDelegator(payable(0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2));

        stETHAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        ethXAddress = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
        oethAddress = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
        methAddress = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
        sfrxEthAddress = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    }

    function test_deposit_stETH() public {
        deposit(stETHAddress, stWhale, 0.1 ether);
    }

    function test_deposit_OETH() public {
        deposit(oethAddress, oWhale, 1 ether);
    }

    function test_deposit_ETHx() public {
        deposit(ethXAddress, xWhale, 2 ether);
    }

    function test_deposit_mETH() public {
        deposit(methAddress, mWhale, 8 ether);
    }

    function test_deposit_sfrxETH() public {
        deposit(sfrxEthAddress, frxWhale, 10 ether);
    }

    function test_transfer_stETH_Eigen() public {
        deposit(stETHAddress, stWhale, 1 ether);
        transfer_Eigen(stETHAddress, 0.8 ether);
    }

    function test_transfer_OETH_Eigen() public {
        deposit(oethAddress, oWhale, 1 ether);
        transfer_Eigen(oethAddress, 0.1 ether);
    }

    function test_transfer_ETHx_Eigen() public {
        deposit(ethXAddress, xWhale, 2 ether);
        transfer_Eigen(ethXAddress, 1.2 ether);
    }

    function test_transfer_mETH_Eigen() public {
        deposit(methAddress, mWhale, 5 ether);
        transfer_Eigen(methAddress, 5 ether);
    }

    function test_transfer_sfrxETH_Eigen() public {
        deposit(sfrxEthAddress, frxWhale, 2 ether);
        transfer_Eigen(sfrxEthAddress, 1.2 ether);
    }

    function test_update_primeETH_price() public {
        // anyone can call
        lrtOracle.updatePrimeETHPrice();
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

    function transfer_Eigen(address asset, uint256 amountToTransfer) public {
        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, asset, amountToTransfer);

        // TODO check asset was transferred from nodeDelegator to Eigen asset strategy
    }
}
