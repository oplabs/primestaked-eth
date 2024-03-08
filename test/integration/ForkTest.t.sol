// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTDepositPool, ILRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";
import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { IWETH } from "contracts/interfaces/IWETH.sol";
import { IEigenPod } from "contracts/interfaces/IEigenPod.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator, INodeDelegator, ValidatorStakeData } from "contracts/NodeDelegator.sol";
import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { WETHPriceOracle } from "contracts/oracles/WETHPriceOracle.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { DeployAll } from "script/foundry-scripts/mainnet/00_deployAll.sol";

contract ForkTestBase is Test {
    LRTDepositPool public lrtDepositPool;
    PrimeStakedETH public preth;
    LRTOracle public lrtOracle;
    LRTConfig public lrtConfig;
    NodeDelegator public nodeDelegator1;

    address internal constant stWhale = 0xd8d041705735cd770408AD31F883448851F2C39d;
    address internal constant xWhale = 0x1a0EBB8B15c61879a8e8DA7817Bb94374A7c4007;
    address internal constant oWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
    address internal constant mWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
    address internal constant frxWhale = 0x46782D268FAD71DaC3383Ccf2dfc44C861fb4c7D;
    address internal constant rWhale = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;
    address internal constant swWhale = 0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6;

    string public referralId = "1234";

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Zap(address indexed minter, address indexed asset, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        vm.createSelectFork(url);

        lrtDepositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        nodeDelegator1 = NodeDelegator(payable(Addresses.NODE_DELEGATOR));

        // Any pending deployments or configuration changes
        DeployAll deployer = new DeployAll();
        deployer.run();
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
}

// TODO basic primeETH token tests. eg transfer, approve, transferFrom

contract ForkTestNative is ForkTestBase {
    NodeDelegator public nodeDelegator2;
    PrimeZapper public primeZapper;

    address internal constant wWhale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
    // WETH whale that is not a contract
    address internal constant wWhale2 = 0x267ed5f71EE47D3E45Bb1569Aa37889a2d10f91e;

    // Get the result.validatorRegistrationTxs[0].data from the P2P Check Status Request
    // removed the 0x06e8fb9c function signature (4 bytes) from the validatorRegistrationTxs.data
    bytes internal validatorRegistrationTx =
    // solhint-disable-next-line max-line-length
        hex"0000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000001da247dd09839800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030873a2ca88b927811a0aca4998899802c10cc04cea344ddbf6682ea9b08890af131c0c708512ac631fa13a0cf6c3afa5200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000c300000000000000000000000000000000000000000000000000000000000000c600000000000000000000000000000000000000000000000000000000000000c9000000000000000000000000000000000000000000000000000000000000052098eef29c28418655939ab445d4055469758378d55dda16379334b6d0a6b6a08f7ab7f157cf48dbb0c157a93a308368cd18af9253a3ec4795a2aa9d54f7363b7e26594b2387308c9a17cf006cf20eaa6200d33ed7551c2ffa59c7bc46d73968f48a0ee942559518d6a975173656c32a75e274b1f8dbc996d7f9a756da3efc5aa57a36243b642c751674cf769c101e3388b385a358034921f979d566da8129ae1897839863912e9f34c13299c5d761cd5695572df0b51e62eca2f55b5d0b16e06792eb1dabf157f619be81921f2aa29445d2a55db8e81f5f982ab955476dbc5e8ed2e70843fe1d929ea8b15aadeb0522a49089c01266dfc97c1aa47ed72df79e1e71c194dd3c60a83319771574159fb64f6a6ba6dac16f52e0a65472b1d90d34e09977690fd96cfed424190313a7adbb195f0f1ad97913d2419933800d05ee2cf0e3088cfee25df6d51640aaba4a1028d4e6885fae080985cc7d8ff24a7409b1493e1c9f09df1419bac0f1d0ebf0c7cf1f151becfb660bc0e6430cd783b6ccb7bf20b49611ded65cf6e59809b7c6e895fd5e35e4d24d1b7a03e189246985f99607f9f5bbcdea9f2cf32ebcb369a9d6ca6134cd0ef296e69453031764d3cfed7f8f503bbcca4621761e3c4fbd6c1b7e2d020d53b8c72b6f0642d59a9287e2ee684b51b0f00b123373c683a4d6e958866e84083ab95d13ef8f1abe6bc27635a97c5b3e5ec2148513e58c5b6cf8a553ba3f12bd1c77c322e5b3040014124ee3d3a25ea0fad90b05d3261a03fa036548b29ab4fe5065b08514be6753388c3a3805636210d2307d4855aad180f6069f45d79e11cb4e8da79dd09c092b2fd70f0bfde45c00d65d2cc2369bd48af6c808c1cd1971e83a123dafd2e12dce5ac3d655e9b9a6fa8338f12abc06de1ceb6846e09de88d2e287342c8e2d2b9a5a8b292babbf2dc3fa052db41436fb0cb988b662897668c158d201e733510c6b6bdb6124d59f5a3464c9d585a4006d119a64eda827f663d8ca89384ed933b2a0d3b69048e65dbaf10a937cd0f9b020cddfba930f34db72d96f0bb8e7555b01e4f6b5f79a72f78d95dbd96f2ff5b96c1736756b0e237104c0cee4ad6e270dcb2f2c765a6e2688c7389681b88c8df4d14ba84dd3310b3f5d65dc5960b9a3895e60c4d8767871fce22dbdd4fb0e6aa3b466f3530992b3a60b91f62ecc0bf2a1ee57ab3d2a6c94ad438e28e0430708351f04bdf600ec3e4e1f6b9058413d3c383554c12a8aafd6ec28d40b0a4f35b5b697eb9344f6a0b358fa01e822c0f3974dd5d9b8ece1ac3514ad2f9df0a8092c1975df1e992d4963283d320ac8029c018c2156487e4226eddd22070a9421fc09b6fd21059cd47f72b065e5bbc79f31013b8d556b9a135e63a3c2b570c87de2b31180438024b196febb78babe13e3e7c364ea6cafe55182d0a0d6fa358379f8f2c00c62240d9811b03d4fcf2b80ff73aa290f2891f8346cd8f11dd6fa4ecef2da3da0ab47548fb6d77e61a83eea90aec59dabc35768e5165ca4b8f54800a382640bb3b11024efe28d15512665ce5f748d6b32466eda2d8dfed7fce3e0ca28d8f8859de4cd85afed13fb609999ce5dde1f1d0664c613d2fd42d0478fee82cd071572977137f95c390897065778a07377f54094a6885c7ffd23d0f12f5b1bd66cea8547953600ad88dfc86a25aecd9b2a74dd9c477821e3c77321e9f6a29d8377763b7ab84d8504d1df8355d8c870ffb2319c8b06baa1006c236c51970f70ddab21934af1e5450487628dea636e0039863df035a022fcce2a8df311fde9e4322b9651154238bdd99c9d73ae3535827c66561231a32ec8879f68fbe9c";
    ValidatorStakeData[] internal validatorStakeData;

    function setUp() public override {
        super.setUp();

        nodeDelegator2 = NodeDelegator(payable(Addresses.NODE_DELEGATOR_NATIVE_STAKING));
        primeZapper = PrimeZapper(payable(Addresses.PRIME_ZAPPER));

        validatorStakeData.push(
            ValidatorStakeData({
                pubkey: hex"873a2ca88b927811a0aca4998899802c10cc04cea344ddbf6682ea9b08890af131c0c708512ac631fa13a0cf6c3afa52",
                signature: hex"a9757db51dc91096840ecefc801da6b6691aeb8fd806ff838d4001264a765f3c"
                    hex"9224e38d1eb86bab57e62ef5e1c65ab811c305cba81e87887978191118713fd3"
                    hex"8e96e94b12c7c9f9f0b175da873b943abd592dfce83e998d3dde5595d289b249",
                depositDataRoot: 0xbff953046f19698fc3ae1ca8b50e1a03c2af2f899057a47fd5a655a9a6501e42
            })
        );
    }

    function test_approveSSV() public {
        vm.prank(Addresses.MANAGER_ROLE);

        vm.expectEmit(Addresses.SSV_TOKEN);
        emit Approval(address(nodeDelegator2), Addresses.SSV_NETWORK, type(uint256).max);

        nodeDelegator2.approveSSV();
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

    function test_registerValidator() public {
        uint256 transferAmount = 32 ether;
        address asset = Addresses.WETH_TOKEN;
        deposit(asset, wWhale, transferAmount);

        vm.startPrank(Addresses.OPERATOR_ROLE);

        lrtDepositPool.transferAssetToNodeDelegator(1, asset, transferAmount);

        (uint256 ndcEthBefore, uint256 eigenEthBefore) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);

        (
            bytes memory publicKey,
            uint64[] memory operatorIds,
            bytes memory sharesData,
            uint256 amount,
            Cluster memory cluster
        ) = abi.decode(validatorRegistrationTx, (bytes, uint64[], bytes, uint256, Cluster));
        console.log("publicKey:");
        console.logBytes(publicKey);
        console.log("operator id: 0 %s", operatorIds[0]);
        console.log("operator id: 1 %s", operatorIds[1]);
        console.log("operator id: 2 %s", operatorIds[2]);
        console.log("operator id: 3 %s", operatorIds[3]);
        console.log("SSV amount: %e", amount);

        nodeDelegator2.registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

        (uint256 ndcEthAfter, uint256 eigenEthAfter) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
        assertEq(ndcEthAfter, ndcEthBefore, "WETH/ETH in NodeDelegator after");
        assertEq(eigenEthAfter, eigenEthBefore, "WETH/ETH in EigenLayer after");

        vm.stopPrank();
    }

    function test_stakeETH() public {
        address asset = Addresses.WETH_TOKEN;
        deposit(asset, wWhale, 65 ether);

        vm.startPrank(Addresses.OPERATOR_ROLE);

        lrtDepositPool.transferAssetToNodeDelegator(1, asset, 65 ether);

        (
            bytes memory publicKey,
            uint64[] memory operatorIds,
            bytes memory sharesData,
            uint256 amount,
            Cluster memory cluster
        ) = abi.decode(validatorRegistrationTx, (bytes, uint64[], bytes, uint256, Cluster));

        nodeDelegator2.registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

        (uint256 ndcEthBefore, uint256 eigenEthBefore) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);

        vm.expectEmit(Addresses.NODE_DELEGATOR_NATIVE_STAKING);
        emit ETHStaked(publicKey, 32 ether);

        nodeDelegator2.stakeEth(validatorStakeData);

        (uint256 ndcEthAfter, uint256 eigenEthAfter) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
        assertEq(ndcEthAfter, ndcEthBefore - 32 ether, "WETH/ETH in NodeDelegator after");
        assertEq(eigenEthAfter, eigenEthBefore + 32 ether, "WETH/ETH in EigenLayer after");

        // Deposit some ETH in the EigenPod
        vm.deal(Addresses.EIGEN_POD, 0.1 ether);

        (uint256 ndcEthAfterRewards, uint256 eigenEthAfterRewards) =
            nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
        assertEq(ndcEthAfterRewards, ndcEthBefore - 32 ether, "WETH/ETH in NodeDelegator after consensus rewards");
        assertEq(eigenEthAfterRewards, eigenEthBefore + 32 ether, "WETH/ETH in EigenLayer after consensus rewards");

        // Should fail to register a second time
        vm.expectRevert(
            abi.encodeWithSelector(INodeDelegator.ValidatorAlreadyStaked.selector, validatorStakeData[0].pubkey)
        );
        nodeDelegator2.stakeEth(validatorStakeData);

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

        vm.expectEmit(Addresses.WETH_TOKEN);
        emit Transfer(address(nodeDelegator2), address(lrtDepositPool), 30 ether);

        nodeDelegator2.transferBackToLRTDepositPool(asset, 30 ether);
    }

    function test_revertWhenSecondCreatePod() public {
        vm.startPrank(Addresses.ADMIN_ROLE);
        vm.expectRevert("EigenPodManager.createPod: Sender already has a pod");
        nodeDelegator2.createEigenPod();
        vm.stopPrank();
    }

    function depositETH(address whale, uint256 amountToTransfer, bool sendEthWithACall) internal {
        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(Addresses.WETH_TOKEN);

        vm.startPrank(whale);

        vm.expectEmit({
            emitter: address(primeZapper),
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
        emit Zap(whale, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, amountToTransfer);

        // Should transfer WETH from zapper to pool
        vm.expectEmit({
            emitter: Addresses.WETH_TOKEN,
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
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

    function test_revertWhenDepositLST() public {
        address[] memory assets = new address[](7);
        assets[0] = Addresses.OETH_TOKEN;
        assets[1] = Addresses.STETH_TOKEN;
        assets[2] = Addresses.ETHX_TOKEN;
        assets[3] = Addresses.METH_TOKEN;
        assets[4] = Addresses.SFRXETH_TOKEN;
        assets[5] = Addresses.RETH_TOKEN;
        assets[6] = Addresses.SWETH_TOKEN;

        address[] memory whales = new address[](7);
        whales[0] = oWhale;
        whales[1] = stWhale;
        whales[2] = xWhale;
        whales[3] = mWhale;
        whales[4] = frxWhale;
        whales[5] = rWhale;
        whales[6] = swWhale;

        for (uint256 i = 0; i < assets.length; i++) {
            vm.startPrank(whales[i]);

            IERC20(assets[i]).approve(address(lrtDepositPool), 1e18);
            vm.expectRevert(ILRTDepositPool.MaximumDepositLimitReached.selector);
            lrtDepositPool.depositAsset(assets[i], 1e18, 0, referralId);
            vm.stopPrank();
        }
    }
}

contract ForkTestLST is ForkTestBase {
    function setUp() public override {
        super.setUp();

        // Increase LST limits so they can be deposited
        allowLSTDeposits();

        // Unpause all EigenLayer deposits
        unpauseAllStrategies();
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

    function allowLSTDeposits() internal {
        vm.startPrank(Addresses.MANAGER_ROLE);
        lrtConfig.updateAssetDepositLimit(Addresses.OETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.STETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.ETHX_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.SWETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.RETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.SFRXETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.METH_TOKEN, 100e21);
        vm.stopPrank();
    }
}
