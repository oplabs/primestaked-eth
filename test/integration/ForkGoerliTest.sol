// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator, ValidatorStakeData } from "contracts/NodeDelegator.sol";
import { AddressesGoerli } from "contracts/utils/Addresses.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";

contract ForkGoerliTest is Test {
    uint256 public fork;

    LRTDepositPool public lrtDepositPool;
    PrimeStakedETH public preth;
    LRTOracle public lrtOracle;
    NodeDelegator public nodeDelegator1;
    NodeDelegator public nodeDelegator2;

    address public stWhale;
    address public xWhale;
    address public oWhale;
    address public mWhale;
    address public frxWhale;
    address public rWhale;
    address public swWhale;
    address public wWhale;

    string public referralId = "1234";

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        fork = vm.createSelectFork(url);

        lrtDepositPool = LRTDepositPool(payable(AddressesGoerli.LRT_DEPOSIT_POOL));
        lrtOracle = LRTOracle(AddressesGoerli.LRT_ORACLE);
        nodeDelegator1 = NodeDelegator(payable(AddressesGoerli.NODE_DELEGATOR));
        nodeDelegator2 = NodeDelegator(payable(AddressesGoerli.NODE_DELEGATOR_NATIVE_STAKING));
    }

    function test_registerSsvValidator() public {
        vm.prank(AddressesGoerli.RELAYER);

        Cluster memory cluster = Cluster(0, 0, 0, true, 0);
        uint64[] memory operatorIds = new uint64[](4);
        operatorIds[0] = 60;
        operatorIds[1] = 79;
        operatorIds[2] = 220;
        operatorIds[3] = 349;

        nodeDelegator2.registerSsvValidator(
            hex"896b5102d5f600aa30687c5cd0088d2e43c3afa7f643600edb12e31cd4b0b2b23e556b33de0168ab94abd4730a18225f",
            operatorIds,
            hex"aebf72c2bd0899798a4fe51235f669debe4bc59dd49df29394ae2adf1e585e45bdee7c0f462ec9c6d531ff36c98e2e9712149e5ecd20365848073e93ad8550fe"
            hex"178c8ebbee9b924351533d869e63a08707ee12309b499ff3452597aca0336e4c80f04654a67fccc2e3e349608819195829a44b21a836a75836f639babd14b6aa"
            hex"46a49e26f02632ed13678f730d4f2ed08612225c95aca932fd0813cd605b9a61c1e0504917c94eab588ba2d619e89f339e9b804f6fffc9ad4ead1fcaa4706dca"
            hex"97a56d2efeefab016832d143b160aed03307ad12f83d91fe50cd1a3e3b80f4cdd91a660657c0fea9259014331dfce1759330bc9a1aae91f3c64511f937a64859"
            hex"5757b692895b6eeb7a886551c8b1990ee9a820a412e2d1ba79e2e6b200d990153ea459cc20c1ed030c9aa5635130b583f356e81fc48db7e76e99f7eeb646449e"
            hex"05524d3e6377f68c8a4e4c235cce3baf566ca94f46278d144ca6f0d8c0fb692dcb1e40cc5d1727c94948381df3f52b1b7a517322063000a964714cbfa4b00935"
            hex"33b00c041e0693e56bcce55d03908dd3419797477cbc7240964d8a7566c02739564f7f48fec29d19e7c00a63bdd49432230cb7bc1ef6075c43d9d081157c1455"
            hex"4bcc7551999eba0fd0531af488601c21603fd285a89ef1478fb52ed6b8d3ab811602df305543a44cd698abb6ca6e067bf1573007f4e67ca8c3ecc35b56679d3e"
            hex"a8798efbe3d7074f7da1305596eb17c8c1adbfc408f1edab9985cacd9475ffee1cd64cec8a9f1b10fdc0ed2334fddf0b1f89c5781c9d8f38f6778f002d63bd32"
            hex"5b7414d7a604dd3df8e1ddaf896d1de9ea9f803eef0557f186fef7cba29d2d6d85f4cd0ec62fb768f66b626a48198916b75e8f85e14c43e8ed8ef5870895cd68"
            hex"bbcafdcd3a4cce352088daf59180cd44352f490415d97636fb8a646cca38bf001d2d813d9a819f9d717bd44b52c0a2405f25a6dc56d508cc2a74db28189f428c"
            hex"f776f64421c55a30092cd4786d1ba30984e2571911f0b54c1f92f68a706c8a28607ff648b010b25df19a8ed69e5be864a8e0447a5771eaa17cb8abc250e83b72"
            hex"8707f8a5ea113862c2d1c3cde561d9ff6250e163db18f02cc741aaabebba1de8053e30c248b81ae6148ed3866d29f4df06e86ef8cde1beb89631b1e67620895c"
            hex"29d48bb89cd81e05773c32d3d6ede945ae0f3e3d3eac5bcb08806aec9935caa118edb9aa7f3f7ef9cef3ce4e064b18492bd82224c10d56b1ffb1072751cffe8d"
            hex"eb61a6dd06c0046ffc7392a6d76499b593182543251399dc59327934cd8013b02434cd586f75ccbacea3c36fc0d71318a1db057a7a47bda9eb9c38f6cfbe2ca1"
            hex"72b5619dfb9118edc6bea2906802b18668e9bec8a3acf196df592fe4c000f516fd330645af1d06740d03aa309863d6d68fb8202c31bd8d8f7ddb80e541f573e9"
            hex"ba6a0e4965e15b9e9ea83e7bcc9cf9fd06ae99fe4aaae5820498393dd29f5b7ba57e6e39f7bd077279912653fbbf8f54d9d8401c79e2582f0f0fc0cd176ad500"
            hex"3a1d8fd20583f50efd51c11a902c83215ac5518f974d699c01febaee637bf9129a15fc4abaf983165f70c8ad584a41e0c04b2c15afafd04b69b3c188fae14656"
            hex"7791e92a339bbfa6397202345ce0b8a34ca012dfbc0711699208bfa3c9e9377ed676e3a63088dfa61c8dced0dc26c485d1507a659e14ce3eb7ca620aa31289c2"
            hex"658f3b479f72598cb3310afbdd1b55022553fab4e45f4a7bee9ca232b862e092d77cac486fed8d4006aa68d7abd71381e0208aa6b5c1dfb335c3ad91cf05324e"
            hex"498a6fb519967e907da608faed80c71448e056b234bb95c851fe4dc15e25dae3",
            2_002_546_440_000_000_000,
            cluster
        );
    }

    function test_stakeETH() public {
        vm.prank(AddressesGoerli.RELAYER);

        ValidatorStakeData[] memory validators = new ValidatorStakeData[](1);
        validators[0] = ValidatorStakeData({
            pubkey: hex"896b5102d5f600aa30687c5cd0088d2e43c3afa7f643600edb12e31cd4b0b2b23e556b33de0168ab94abd4730a18225f",
            signature: hex"b2f24a0115546169976cdd8784d6c896febefd58964158f81ab9427e577d5eb055b40f384f4a09b5ff8d2b834277fa861632758a3fcb564dae759922f466a8ea"
                hex"a2af9d2406906646adda22baa86967a4a90b616527c0c077794657da9076b198",
            depositDataRoot: 0xc9d1dd6024731da7ab57d15c20a3b6f2b14e15337684f73f3e96ff5c962f369a
        });

        nodeDelegator2.stakeEth(validators);
    }
}
