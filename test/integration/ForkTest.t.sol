// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTDepositPool, ILRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";
import { IDelegationManager } from "contracts/eigen/interfaces/IDelegationManager.sol";
import { IPausable } from "contracts/eigen/interfaces/IPausable.sol";
import { IStrategy } from "contracts/eigen/interfaces/IStrategy.sol";
import { IWETH } from "contracts/interfaces/IWETH.sol";
import { IEigenPod } from "contracts/eigen/interfaces/IEigenPod.sol";
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

    address internal constant stWhale = 0xE53FFF67f9f384d20Ebea36F43b93DC49Ed22753;
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

    modifier assertAssetsInLayers(
        address asset,
        int256 depositPoolDiff,
        int256 nodeDelegatorDiff,
        int256 eigenLayerDiff
    ) {
        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        _;

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        assertEq(
            int256(assetsInDepositPoolAfter), int256(assetsInDepositPoolBefore) + depositPoolDiff, "deposit pool assets"
        );
        assertEq(int256(assetsInNDCsAfter), int256(assetsInNDCsBefore) + nodeDelegatorDiff, "NodeDelegators assets");
        assertEq(
            int256(assetsInEigenLayerAfter), int256(assetsInEigenLayerBefore) + eigenLayerDiff, "EigenLayer assets"
        );
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

    // WETH whales that are not contracts
    address internal constant wWhale = 0x57757E3D981446D585Af0D9Ae4d7DF6D64647806;
    address internal constant wWhale2 = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28;

    // Get the result.validatorRegistrationTxs[0].data from the P2P Check Status Request.
    // removed the 0x22f18bf5 function signature (4 bytes) from the validatorRegistrationTxs.data
    // which calls bulkRegisterValidator on the SSVNetwork
    // function bulkRegisterValidator(bytes[] calldata publicKeys, uint64[] calldata operatorIds,
    // bytes[] calldata sharesData, uint256 amount, ISSVNetworkCore.Cluster memory cluster)
    bytes internal validatorRegistrationTx =
    // solhint-disable-next-line max-line-length
        hex"000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000016df54bd9cf8e40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030935cb617cf9bbebcf1db99efd1f87d9126d9e64321411451f0bb00776b0793a228f798a070263f6b90d70eb5d6810fb500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000c100000000000000000000000000000000000000000000000000000000000000c400000000000000000000000000000000000000000000000000000000000000c700000000000000000000000000000000000000000000000000000000000000ca000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000520a3e3a7a9a8f39c0cea6a2bfdc0a7822d6c21f65e61214b8a791323e937f9743b53b5f326f03315b125aa5b9df84f15d8189b1013c3738e22f1aa450b4dd6ecef979effb34a648b3391b7039201eda0bb81cedd1caf570ed2660a403c0258f314a030146e4ad22ea33e5dd7d0a9bf1059da8fadf36dc5e05b97c40997d1e76e122adb10b426d8af50a7f669af73ce7d1ea6b381409b3c780cccc0cf62a7510c9938dc4e524dc672404132e7b260bd161c96b6b85a8f3ca8058286fbd79b30de828001e919540188ff5276431554604ef4c1301d1350e24ec8074699b10c2970df4e15a56b0068e5552d442b4534d1e15a81826891a3e87286ad94ec8252bb3305655d3d8e40f0ae85c2bab29a1afd8996e2976e6e58411f5dd21a59d3c0cb76cd049631abf46115030ed1ce041ce3c8a51c411c597728cd794551e88a924f014e850986107a7b15cdcfcfc14f3c449cda7c231e977b5eedf2fa50b28c3e0e471c920a122399855cc9b36de0672ecb8fd78bbe36bd46eb155e03405515cf5a580201c5d74d63097d6c780ec94dfcc1c4b8193409360219b12e7dc9d75454c06608fe158694362b3b5c315ddd51dbc1b2aaede888fbe43acd3e3ff1634f245501ed7ba5d873ba6625500f8e0fde1f6cc65bfa6853b2a405b8f64624940aff61986fc5ccde199a438641fc9ae6df0885ab64fd02342583ad5ba91466a8cbe4dc43b7178f3b06d3bbc5d4cfe33e313497d1aabcf59b738ed3dc0eb3da53ae3635055dd6750ae68d65a7c74915d5485067bd66bc82c90e1afed93ee03767a9c6aff53a42cee80354fd33c534a70d31fff3d89e6bd23d922e5cbc0accb6bb22a1548dad2e43903afa6a94970b846e6718d10c94aacaff3369c69a1f51dda7d51ffc8c63954e51abe01430900e0c9bb2a34572211068cbe462e97fd43d26563e87c6289f509336a240cc49c1a8ed3832c64a548f7dc147f63938e9747640a12839d33f2e897ff627c031e45c3a7da256724e41268a387dce0c369f4c223bf7ef9b43087e4462f69fa7ca23eef7e75109a2cb372be8cce78d4677fd163b70b9e4883c4bd6ac221c0823b3fb3ad08e46c628e6f820cd42d58138ab48b90e68fa1bf625a88c82a1e1f99d9b2e6d571c134e23ee394469c9e01b113224ceb3368fb346c3a55a7122ed1d4fcdcabb123e3f7a98edecee8e4ac62b42ad865adaf3a96e45be3b8b12749b6f63cd14d1184dd5a10230d591a284b3ba03eadd4f1ef15ded1fd458b408e26219a18090147abbf8e84d8fbddcee0e025a7ef1538c0e16c74f54acb6cfdee8f8185f75836dcf4182127ed199dd15318821709be21d511834bebb91411e18ec825c8e94e754526fc53462bb3aa25931f570722c57dd492c5821630914934d0b63a0883b6fa71cc0d10c905d7858f59adfe81362d414317d6321e02bc65072e2a0869bc53d76368830803a9efdd72131951da6f782fba9530cfd3b51ce6dc5f4a00bdd3bfa6114d8989287d01c4d0cc7516bbcd88a02734dba2dbb089d64b3a409ee339c232b218f714151301b1d315b5a6139d8311fbe9213228442872f66f2d1dffb47ae15155f556a1596b6ea7e223d85e7bebd80d6e384fc30c8a223fd1f845cb38bf802a9cdf3ada68312132827278589df7689849ade2fd01bdbd8021988acf38def6f34dd0edb82a1b9f62c24b1e6c758188cb53c433b0f09b7d62adab5eba999dde3cc90fd4838a44da0e3d978a6f974f1f101ad19978a2c2cb5d7d42b488e292c6e349f49716021b366ee0640edbee60cb1716aa5c5f5be22b0d69a0500dd30bb792ed5931fa86d7244d72494d551d629439897c18f428fab46";
    ValidatorStakeData[] internal validatorStakeData;

    function setUp() public override {
        super.setUp();

        nodeDelegator2 = NodeDelegator(payable(Addresses.NODE_DELEGATOR_NATIVE_STAKING));
        primeZapper = PrimeZapper(payable(Addresses.PRIME_ZAPPER));

        validatorStakeData.push(
            ValidatorStakeData({
                pubkey: hex"935cb617cf9bbebcf1db99efd1f87d9126d9e64321411451f0bb00776b0793a228f798a070263f6b90d70eb5d6810fb5",
                signature: hex"816f185cfd5456172dcdec88b1cb7dcc3e098954581cb0e91ef6d413a4c1f915f5353f3aa01b5853e05dde088072f57914096fec93f58c4a990454d15a01157ab45e2f54c64767a6bc8dd99f8ed56d35083e2cbca55cde42572afd8fe82f7efe",
                depositDataRoot: 0x7897c6b4bc0fa28dbb5c92b5a00b5ef24b7a1b89e5c1591ad75fdc732e61cb98
            })
        );
    }

    function addEther(address target, uint256 rewards) internal {
        vm.startPrank(wWhale);
        IWETH(Addresses.WETH_TOKEN).withdraw(rewards);
        target.call{ value: rewards }("");
        vm.stopPrank();
    }

    function test_approveSSV() public {
        vm.prank(Addresses.MANAGER_ROLE);

        vm.expectEmit(Addresses.SSV_TOKEN);
        emit Approval(address(nodeDelegator2), Addresses.SSV_NETWORK, type(uint256).max);

        nodeDelegator2.approveSSV();
    }

    // This test will probably have to be removed as balance will change and can't simply be queried from the SSV
    // Network contract
    // Use the following to get the latest cluster SSV balance
    // npx hardhat getClusterInfo --network local --operatorids 63.65.157.198
    function test_depositSSV() public {
        uint256 amount = 3e18;
        deal(address(Addresses.SSV_TOKEN), Addresses.MANAGER_ROLE, amount);

        vm.prank(Addresses.MANAGER_ROLE);

        Cluster memory cluster = Cluster({
            validatorCount: 1,
            networkFeeIndex: 60_025_270_074,
            index: 291_898_093_718,
            active: true,
            balance: 4_747_140_052_000_000_000
        });

        // These are the operatorIds for the first SSV Cluster. These will not be used going forward
        uint64[] memory operatorIds = new uint64[](4);
        operatorIds[0] = 63;
        operatorIds[1] = 65;
        operatorIds[2] = 157;
        operatorIds[3] = 198;

        vm.expectEmit(Addresses.SSV_TOKEN);
        emit Transfer(address(nodeDelegator2), Addresses.SSV_NETWORK, amount);

        nodeDelegator2.depositSSV(operatorIds, amount, cluster);
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
        uint256 rewards = 0.01 ether;
        addEther(Addresses.NODE_DELEGATOR_NATIVE_STAKING, rewards);

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        assertEq(assetsDepositPoolAfter, assetsDepositPoolBefore, "assets in DepositPool");
        assertEq(assetsNDCsAfter, assetsNDCsBefore + rewards, "assets in NDCs");
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
            bytes[] memory publicKeys,
            uint64[] memory operatorIds,
            bytes[] memory sharesData,
            uint256 amount,
            Cluster memory cluster
        ) = abi.decode(validatorRegistrationTx, (bytes[], uint64[], bytes[], uint256, Cluster));
        console.log("publicKey:");
        console.logBytes(publicKeys[0]);
        console.log("sharesData:");
        console.logBytes(sharesData[0]);
        console.log("operator id: 0 %s", operatorIds[0]);
        console.log("operator id: 1 %s", operatorIds[1]);
        console.log("operator id: 2 %s", operatorIds[2]);
        console.log("operator id: 3 %s", operatorIds[3]);
        console.log("SSV deposit amount: %e", amount);
        console.log("SSV cluster validators: %d", cluster.validatorCount);
        console.log("SSV cluster networkFeeIndex: %d", cluster.networkFeeIndex);
        console.log("SSV cluster index: %d", cluster.index);
        console.log("SSV cluster active: ", cluster.active);
        console.log("SSV cluster balance: %e", cluster.balance);

        nodeDelegator2.registerSsvValidator(publicKeys[0], operatorIds, sharesData[0], amount, cluster);

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

        vm.stopPrank();

        // Deposit some ETH in the EigenPod
        addEther(Addresses.EIGEN_POD, 0.1 ether);

        (uint256 ndcEthAfterRewards, uint256 eigenEthAfterRewards) =
            nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
        assertEq(ndcEthAfterRewards, ndcEthBefore - 32 ether, "WETH/ETH in NodeDelegator after consensus rewards");
        assertEq(eigenEthAfterRewards, eigenEthBefore + 32 ether, "WETH/ETH in EigenLayer after consensus rewards");

        vm.startPrank(Addresses.OPERATOR_ROLE);

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
        address[] memory assets = new address[](6);
        assets[0] = Addresses.STETH_TOKEN;
        assets[1] = Addresses.ETHX_TOKEN;
        assets[2] = Addresses.METH_TOKEN;
        assets[3] = Addresses.SFRXETH_TOKEN;
        assets[4] = Addresses.RETH_TOKEN;
        assets[5] = Addresses.SWETH_TOKEN;
        // assets[6] = Addresses.OETH_TOKEN;

        address[] memory whales = new address[](6);
        whales[0] = stWhale;
        whales[1] = xWhale;
        whales[2] = mWhale;
        whales[3] = frxWhale;
        whales[4] = rWhale;
        whales[5] = swWhale;
        // whales[6] = oWhale;

        for (uint256 i = 0; i < assets.length; i++) {
            vm.startPrank(whales[i]);

            IERC20(assets[i]).approve(address(lrtDepositPool), 1e18);
            vm.expectRevert(ILRTDepositPool.MaximumDepositLimitReached.selector);
            lrtDepositPool.depositAsset(assets[i], 1e18, 0, referralId);
            vm.stopPrank();
        }
    }

    // undelegate from the P2P EigenLayer Operator on Native Node Delegator
    function test_undelegateFromNativeNodeDelegator()
        public
        assertAssetsInLayers(Addresses.STETH_TOKEN, 0, 0, 0)
        assertAssetsInLayers(Addresses.RETH_TOKEN, 0, 0, 0)
        assertAssetsInLayers(Addresses.WETH_TOKEN, 0, 0, 0)
    {
        vm.startPrank(Addresses.MANAGER_ROLE);

        nodeDelegator2.delegateTo(Addresses.EIGEN_OPERATOR_P2P);
        nodeDelegator2.undelegate();

        vm.stopPrank();
    }

    // TODO add test for undelegate and claim the withdrawn ETH when Native ETH withdrawals are supported
}

contract ForkTestLST is ForkTestBase {
    function setUp() public override {
        super.setUp();

        // Increase LST limits so they can be deposited
        allowLSTDeposits();

        // Unpause all EigenLayer deposits
        // unpauseAllStrategies();
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

    // staker withdrawal of LST
    function test_staker_lst_withdrawal() public {
        address asset = Addresses.OETH_TOKEN;
        deposit(asset, oWhale, 1 ether);
        transfer_DelegatorNode(asset, 1 ether);
        transfer_Eigen(asset, Addresses.OETH_EIGEN_STRATEGY);

        uint256 whaleAssetsBefore = IERC20(asset).balanceOf(oWhale);

        uint256 withdrawAssetAmount = 0.9 ether;
        uint256 primeAmount = withdrawAssetAmount;

        vm.recordLogs();

        vm.startPrank(oWhale);

        // Staker requests an OETH withdrawal
        lrtDepositPool.requestWithdrawal(asset, withdrawAssetAmount, primeAmount);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManager.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[1].data, (bytes32, IDelegationManager.Withdrawal));

        // Move forward 50,400 blocks (~7 days)
        vm.roll(block.number + 50_400);

        // Claim the previously requested withdrawal
        lrtDepositPool.claimWithdrawal(withdrawal);

        assertApproxEqAbs(
            IERC20(asset).balanceOf(oWhale), whaleAssetsBefore + withdrawAssetAmount, 1, "whale OETH after within 1 wei"
        );

        vm.stopPrank();
    }

    // Prime Operator withdraws all non OETH LSTs from Eigen Layer
    function test_operator_internal_withdrawal() public {
        withdrawAllFromEigenLayer(Addresses.SFRXETH_TOKEN, Addresses.SFRXETH_EIGEN_STRATEGY);
        withdrawAllFromEigenLayer(Addresses.METH_TOKEN, Addresses.METH_EIGEN_STRATEGY);
        withdrawAllFromEigenLayer(Addresses.STETH_TOKEN, Addresses.STETH_EIGEN_STRATEGY);
        withdrawAllFromEigenLayer(Addresses.RETH_TOKEN, Addresses.RETH_EIGEN_STRATEGY);
        withdrawAllFromEigenLayer(Addresses.SWETH_TOKEN, Addresses.SWETH_EIGEN_STRATEGY);
        withdrawAllFromEigenLayer(Addresses.ETHX_TOKEN, Addresses.ETHX_EIGEN_STRATEGY);
    }

    function withdrawAllFromEigenLayer(address asset, address strategy) internal {
        // Withdraw all the NodeDelegator's strategy shares
        uint256 shares = IStrategy(strategy).shares(address(nodeDelegator1));

        vm.recordLogs();

        vm.startPrank(Addresses.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(strategy, shares);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManager.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[1].data, (bytes32, IDelegationManager.Withdrawal));

        // Move forward 50,400 blocks (~7 days)
        vm.roll(block.number + 50_400);

        nodeDelegator1.claimInternalWithdrawal(withdrawal);

        vm.stopPrank();

        assertEq(IStrategy(strategy).shares(address(nodeDelegator1)), 0, "shares after");
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
        IPausable eigenStrategy = IPausable(strategyAddress);
        IPausable eigenStrategyManager = IPausable(Addresses.EIGEN_STRATEGY_MANAGER);

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

    // undelegate from the P2P EigenLayer Operator on LST Node Delegator
    function test_undelegateFromLSTNodeDelegator()
        public
        assertAssetsInLayers(Addresses.STETH_TOKEN, 0, 0, 0)
        assertAssetsInLayers(Addresses.RETH_TOKEN, 0, 0, 0)
        assertAssetsInLayers(Addresses.WETH_TOKEN, 0, 0, 0)
    {
        vm.startPrank(Addresses.MANAGER_ROLE);

        nodeDelegator1.undelegate();

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
        // OETH has since been enabled
        // lrtConfig.updateAssetDepositLimit(Addresses.OETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.STETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.ETHX_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.SWETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.RETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.SFRXETH_TOKEN, 100e21);
        lrtConfig.updateAssetDepositLimit(Addresses.METH_TOKEN, 100e21);
        vm.stopPrank();
    }
}
