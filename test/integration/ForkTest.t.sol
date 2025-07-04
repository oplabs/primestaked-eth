// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTDepositPool, ILRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";
import { IDelegationManager, IDelegationManagerTypes } from "contracts/eigen/interfaces/IDelegationManager.sol";
import { IDelayedWithdrawalRouter } from "contracts/eigen/interfaces/IDelayedWithdrawalRouter.sol";
import { IPausable } from "contracts/eigen/interfaces/IPausable.sol";
import { IStrategy } from "contracts/eigen/interfaces/IStrategy.sol";
import { IWETH } from "contracts/interfaces/IWETH.sol";
import { IEigenPod } from "contracts/eigen/interfaces/IEigenPod.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegatorLST, INodeDelegatorLST } from "contracts/NodeDelegatorLST.sol";
import { NodeDelegatorETH, INodeDelegatorETH, ValidatorStakeData } from "contracts/NodeDelegatorETH.sol";
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
    NodeDelegatorLST public nodeDelegator1;

    address internal constant primeWhale = 0xDac393866d9dB115C11200324F36235A8Ff04919;
    address internal constant stWhale = 0xE53FFF67f9f384d20Ebea36F43b93DC49Ed22753;
    address internal constant xWhale = 0xF6f09B50a9009127731963AF6272d526b83F69d8;
    address internal constant oWhale = 0xA7c82885072BADcF3D0277641d55762e65318654;
    address internal constant mWhale = 0xf89d7b9c864f589bbF53a82105107622B35EaA40;
    address internal constant frxWhale = 0xEADB3840596cabF312F2bC88A4Bb0b93A4E1FF5F;
    address internal constant rWhale = 0xCc9EE9483f662091a1de4795249E24aC0aC2630f;
    address internal constant swWhale = 0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6;

    string public referralId = "1234";

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Zap(address indexed minter, address indexed asset, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ConsensusRewards(uint256 amount);
    event WithdrawnValidators(uint256 fullyWithdrawnValidators, uint256 stakedButNotVerifiedEth);
    event WithdrawalRequested(
        address indexed withdrawer,
        address indexed asset,
        address indexed strategy,
        uint256 primeETHAmount,
        uint256 assetAmount,
        uint256 sharesAmount
    );
    event WithdrawalClaimed(address indexed withdrawer, address indexed asset, uint256 assets);

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        vm.createSelectFork(url);

        lrtDepositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        nodeDelegator1 = NodeDelegatorLST(payable(Addresses.NODE_DELEGATOR));

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

        lrtDepositPool.depositAsset(asset, amountToTransfer, amountToTransfer * 95 / 100, referralId);
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
    NodeDelegatorETH public nodeDelegator2;
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
        hex"000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000001731ef08f035d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003089535bb35adad8f1fc023d03dc724923a4e765f531b58428c348175cff56a23cf3f482c2d0c9caef90f0591a6425f024000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000015c000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001690000000000000000000000000000000000000000000000000000000000000179000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000520837954075577abc2e7c04c7d4221c88d5f85d067cdd68a788c6c73696d4913c2c94d63a46d72dab85eff64347346eaed16675de56476413d9cbab145dc87ff1891c5743bfe216270af49cf9ec0f4969f90608bc97e2ebeff597e73577b75e1b2930e5a17461e1d68b1400c4e33f925428d990014f89d6973bb92ad24ffb4e0731622c3910afc2f10d2edbf93f18358dfa60635f8a77d63fc2ed00fb8bcc66328a4eff4494005a0d56840b8fe9fabe89e38b19d4fe687001591f6ce5a62db6fa694d5d4f583f341765330486cc9abad8272d71e699792be3354c265d58b6b7e567a5ac47f7e20fe87efe23ecc3fc431eb9229a80dbb2ede331bf989f2315a6ea139b3f480cd46f68c855fbf9136df82e4bc43d7f679ac145d53c100d656e7bc643f3c9701efaca27aab7105eea7062a2b2417918b90fed3babe7168ef13af098992e8f64c445dc95e6c9a2f1c3a545772048222c92dd3336e23315c8a11a08ede569726097c7627e2bcd7a83d176d315a20263acd43b64e810e3873a264be4e3f9f475b137a2e821dba303755812f546639a211c47d331c84001d1b87628cbee31adefbcddadfb7a25e636e8f9810265e1eedf93d14a4ecd37758a2812c6238423a9377a6dce42d575e77d4bc7c39f3693be239311975726f2488b36b6d9776a715a7aaf61bac5c05edc487cbcea76195dfb5bbc601fa07e0d353af9846ec997cdcbbc4b8d89773818f6f1be8b4568654226ab493482563aa8c61b9985b65be989e8ed8430288da363945888d5ce4273babcd5b7c8aa008b7ef35ece0ade513f5505e22fb9ce8f4e1517648d1679dd12aff8c64ebfffe3be562fd34bc84385d0fcb7323449ec719ab26c6c37340e3f09ca7cd56134653ff4baf046dfc1e90d97b3ea38577a746fafef4c5057c9a6c6a2626296adce28aedd38a4d107786242716227950908ffcfed1ba0777f4f273b6e6add74a75c132578228378cb32664d35c4b55069794ffe037f72f1dfee6bf7c860dd5abdaf02ef49e4c8dc64dca7bf98eefcfe2078990e4aebdd2cbea3ecc787f3c9af161d2df93cc9fb1b3883ab57406061d03cb8ab4bd019390968f0e94564be96ebaa90bc0ddc5f02cc8f266db3ed788fbe8963664fca3deec9afc004b17c4d5af91c4d643a435332339d113c5c3ec67ecc1e52a03e8e9994c09354b539e049980d5a80a239ac8eb5a2c006806ed750377176af878b21d894f093a5bafa7e72dc749d5d1ee36c0496c582488393b210348c66a9a42e44f04a4faa1e122f393ae1247d74b22200972342597db768d65494cf861234bf1d1cd72ea16a7f128092e7e90122a308cdb457bada97e4c5a16dbbc1a36bbb1d346212cc9b842daa7448bbf008277d1beefef02bc93493052a9d368b4c0211ffebe6c9fa5368b99eb12a51efb7882b5237d29bb8e51065e644514073a9d0c4dbd1d530c147d8bebfe7be830cdbb6169066b5bc7fc8c7b20a4e82f9d325ba0b5ed4590de6b5f08f80d07f9af54445136c3040e9a63c2df130df336f2a764e35e68dc3d6a714c80b8780d1dd3819a7786497aa0bb3327da449efce04549b9b3a79a29d32d1ce88d8acfbd76ff8ae9bf077f53f66f7f6b5155accfedc6d26d65f61af0a25e43f1839b1169210ab1a06dcbb02df9f9e4d5dceb4e8f1d040ce387ed42ef5164c1530913a7fb9689f0d59bc3b4f455ef49c9de08a5c19998151d07e96c1f9b856c993291b50a0a5844a8bcf28ef246455a46c505499bd498cf6ff86b20d660500d844cf95dcd771b95f85ad0143133ba068bbd0465959d2c3440eaeaf82d3bf3476f25ab506f964a72f437cdee9a6259d3de5abf258f";
    ValidatorStakeData[] internal validatorStakeData;

    function setUp() public override {
        super.setUp();

        nodeDelegator2 = NodeDelegatorETH(payable(Addresses.NODE_DELEGATOR_NATIVE_STAKING));
        primeZapper = PrimeZapper(payable(Addresses.PRIME_ZAPPER));

        validatorStakeData.push(
            ValidatorStakeData({
                pubkey: hex"89535bb35adad8f1fc023d03dc724923a4e765f531b58428c348175cff56a23cf3f482c2d0c9caef90f0591a6425f024",
                // solhint-disable-next-line max-line-length
                signature: hex"b4ca3495c75c52e13a2c4e6544a7bede58b0decc904376d76311a8577db0cc3beab7444ef9a11517bb0f3758a0a289c305ad3813393b93e5792611da8f35229fba0e25d5156702bdb851d42a26f7e4638d87f7a1ffc339c9613c88f9cff7493f",
                depositDataRoot: 0x4741601b5977fa2afefe3d28e6614a107758d5c4e5a5eaa187d3e7216b9407b0
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
    // npx hardhat getClusterInfo --network mainnet --operatorids 63.65.157.198
    function test_depositSSV() public {
        uint256 amount = 3e18;
        deal(address(Addresses.SSV_TOKEN), Addresses.MANAGER_ROLE, amount);

        vm.startPrank(Addresses.MANAGER_ROLE);

        Cluster memory cluster = Cluster({
            validatorCount: 0,
            networkFeeIndex: 83_179_900_729,
            index: 823_537_463_402,
            active: true,
            balance: 0
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

        cluster.balance += amount;
        nodeDelegator2.withdrawSSV(operatorIds, amount, cluster);
        vm.stopPrank();
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
            bytes[] memory publicKeys,
            uint64[] memory operatorIds,
            bytes[] memory sharesDatas,
            uint256 amount,
            Cluster memory cluster
        ) = abi.decode(validatorRegistrationTx, (bytes[], uint64[], bytes[], uint256, Cluster));

        nodeDelegator2.registerSsvValidator(publicKeys[0], operatorIds, sharesDatas[0], amount, cluster);

        (uint256 ndcEthBefore, uint256 eigenEthBefore) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);

        vm.expectEmit(Addresses.NODE_DELEGATOR_NATIVE_STAKING);
        emit ETHStaked(publicKeys[0], 32 ether);

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
            abi.encodeWithSelector(INodeDelegatorETH.ValidatorAlreadyStaked.selector, validatorStakeData[0].pubkey)
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

    // Removing as this is not needed anymore
    // function test_revertWhenSecondCreatePod() public {
    //     vm.startPrank(Addresses.ADMIN_ROLE);
    //     vm.expectRevert("EigenPodManager.createPod: Sender already has a pod");
    //     nodeDelegator2.createEigenPod();
    //     vm.stopPrank();
    // }

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
            primeZapper.deposit{ value: amountToTransfer }(amountToTransfer * 95 / 100, referralId);
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
    function test_revertDelegateNativeNodeDelegator() public {
        vm.prank(Addresses.MANAGER_ROLE);

        vm.expectRevert("Unsupported");
        nodeDelegator2.delegateTo(Addresses.EIGEN_OPERATOR_P2P);
    }

    // undelegate from the P2P EigenLayer Operator on Native Node Delegator
    function test_revertUndelegateNativeNodeDelegator() public {
        vm.prank(Addresses.MANAGER_ROLE);

        vm.expectRevert("Unsupported");
        nodeDelegator2.undelegate();
    }

    // Removing as all the primeETH validators have exited and removed
    // function test_exitSsvValidators() public {
    //     vm.startPrank(Addresses.OPERATOR_ROLE);

    //     uint64[] memory operatorIds = new uint64[](4);
    //     operatorIds[0] = 193;
    //     operatorIds[1] = 196;
    //     operatorIds[2] = 199;
    //     operatorIds[3] = 202;

    //     bytes[] memory publicKeys = new bytes[](2);
    //     publicKeys[0] =
    //         hex"b9070f2ace492a4022aaa216f1f1bda17187327ee3ecc4e982e56877d3e8419a02c43b03a9af5acc145bdc45277fc49c";
    //     publicKeys[1] =
    //         hex"b8d135d959f6216ce818860a7608a023dbd0057f9250dfa2fb6b7734be99b32804282d635074cbe241d8720c6352fdda";

    //     nodeDelegator2.exitSsvValidators(publicKeys, operatorIds);

    //     vm.stopPrank();
    // }

    // function test_removeSsvValidators() public {
    //     vm.startPrank(Addresses.OPERATOR_ROLE);

    //     Cluster memory cluster = Cluster({
    //         validatorCount: 28,
    //         networkFeeIndex: 63_459_958_614,
    //         index: 62_030_899_188,
    //         active: true,
    //         balance: 45_461_840_401_950_000_000
    //     });
    //     uint64[] memory operatorIds = new uint64[](4);
    //     operatorIds[0] = 193;
    //     operatorIds[1] = 196;
    //     operatorIds[2] = 199;
    //     operatorIds[3] = 202;

    //     bytes[] memory publicKeys = new bytes[](2);
    //     publicKeys[0] =
    //         hex"b9070f2ace492a4022aaa216f1f1bda17187327ee3ecc4e982e56877d3e8419a02c43b03a9af5acc145bdc45277fc49c";
    //     publicKeys[1] =
    //         hex"b8d135d959f6216ce818860a7608a023dbd0057f9250dfa2fb6b7734be99b32804282d635074cbe241d8720c6352fdda";

    //     nodeDelegator2.removeSsvValidators(publicKeys, operatorIds, cluster);

    //     vm.stopPrank();
    // }

    // All the consensus rewards have been claimed
    // function test_requestEthWithdrawalConsensusRewards() public {
    //     vm.startPrank(Addresses.OPERATOR_ROLE);

    //     uint256 eigenPodBalanceBefore = address(Addresses.EIGEN_POD).balance;
    //     uint256 nodeDelegatorBalanceBefore = address(nodeDelegator2).balance;
    //     assertGt(eigenPodBalanceBefore, 0, "EigenPod balance before");
    //     (uint256 ndcAssetBalanceBeforeRequest, uint256 eigenAssetBeforeRequest) =
    //         nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);

    //     nodeDelegator2.requestEthWithdrawal();

    //     (uint256 ndcAssetBalanceAfterRequest, uint256 eigenAssetAfterRequest) =
    //         nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
    //     assertEq(ndcAssetBalanceAfterRequest, ndcAssetBalanceBeforeRequest, "ND WETH after request");
    //     assertEq(eigenAssetAfterRequest, eigenAssetBeforeRequest, "EL WETH after request");

    //     vm.roll(block.number + 50_400);

    //     // Check the last withdrawal request can be claimed
    //     uint256 withdrawalRequests = IDelayedWithdrawalRouter(Addresses.EIGEN_DELAYED_WITHDRAWAL_ROUTER)
    //         .userWithdrawalsLength(address(nodeDelegator2));
    //     assertTrue(
    //         IDelayedWithdrawalRouter(Addresses.EIGEN_DELAYED_WITHDRAWAL_ROUTER).canClaimDelayedWithdrawal(
    //             address(nodeDelegator2), withdrawalRequests - 1
    //         ),
    //         "can claim withdrawal"
    //     );

    //     vm.expectEmit();
    //     emit ConsensusRewards(eigenPodBalanceBefore);

    //     nodeDelegator2.claimEthWithdrawal();

    //     (uint256 ndcAssetBalanceAfterClaim, uint256 eigenAssetAfterClaim) =
    //         nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
    //     assertEq(ndcAssetBalanceAfterClaim, ndcAssetBalanceBeforeRequest + eigenPodBalanceBefore, "ND WETH after
    // claim");
    //     assertEq(eigenAssetAfterClaim, eigenAssetBeforeRequest, "EL WETH after claim");

    //     assertEq(address(Addresses.EIGEN_POD).balance, 0, "EigenPod balance after");
    //     assertEq(
    //         address(nodeDelegator2).balance,
    //         nodeDelegatorBalanceBefore + eigenPodBalanceBefore,
    //         "NodeDelegator balance after"
    //     );

    //     vm.stopPrank();
    // }

    // All the consensus rewards have been claimed
    // function test_requestEthWithdrawalValidatorExits() public {
    //     vm.startPrank(Addresses.OPERATOR_ROLE);

    //     nodeDelegator2.requestEthWithdrawal();
    //     vm.roll(block.number + 50_400);
    //     nodeDelegator2.claimEthWithdrawal();

    //     // Simulate 3 validators exiting with some consensus rewards
    //     uint256 exitAmount = 96.5 ether;
    //     vm.deal(Addresses.EIGEN_POD, exitAmount);

    //     uint256 ethInValidatorsBefore = nodeDelegator2.stakedButNotVerifiedEth();
    //     uint256 eigenPodBalanceBefore = address(Addresses.EIGEN_POD).balance;
    //     uint256 nodeDelegatorBalanceBefore = address(nodeDelegator2).balance;
    //     assertGt(eigenPodBalanceBefore, 0, "EigenPod balance before");
    //     (uint256 ndcAssetBalanceBeforeRequest, uint256 eigenAssetBeforeRequest) =
    //         nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);

    //     nodeDelegator2.requestEthWithdrawal();

    //     (uint256 ndcAssetBalanceAfterRequest, uint256 eigenAssetAfterRequest) =
    //         nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
    //     assertEq(ndcAssetBalanceAfterRequest, ndcAssetBalanceBeforeRequest, "ND WETH after request");
    //     assertEq(eigenAssetAfterRequest, eigenAssetBeforeRequest, "EL WETH after request");

    //     vm.roll(block.number + 50_400);

    //     // Check the last withdrawal request can be claimed
    //     uint256 withdrawalRequests = IDelayedWithdrawalRouter(Addresses.EIGEN_DELAYED_WITHDRAWAL_ROUTER)
    //         .userWithdrawalsLength(address(nodeDelegator2));
    //     assertTrue(
    //         IDelayedWithdrawalRouter(Addresses.EIGEN_DELAYED_WITHDRAWAL_ROUTER).canClaimDelayedWithdrawal(
    //             address(nodeDelegator2), withdrawalRequests - 1
    //         ),
    //         "can claim withdrawal"
    //     );

    //     vm.expectEmit();
    //     emit WithdrawnValidators(3, ethInValidatorsBefore - 96 ether);
    //     vm.expectEmit();
    //     emit ConsensusRewards(0.5 ether);

    //     nodeDelegator2.claimEthWithdrawal();

    //     (uint256 ndcAssetBalanceAfterClaim, uint256 eigenAssetAfterClaim) =
    //         nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
    //     assertEq(ndcAssetBalanceAfterClaim, ndcAssetBalanceBeforeRequest + exitAmount, "ND WETH after claim");
    //     assertEq(eigenAssetAfterClaim, eigenAssetBeforeRequest - 96 ether, "EL WETH after claim");

    //     assertEq(address(Addresses.EIGEN_POD).balance, 0, "EigenPod balance after");
    //     assertEq(
    //         address(nodeDelegator2).balance,
    //         nodeDelegatorBalanceBefore + eigenPodBalanceBefore,
    //         "NodeDelegator balance after"
    //     );

    //     vm.stopPrank();
    // }
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
        uint256 priceBefore = lrtOracle.primeETHPrice();
        lrtOracle.updatePrimeETHPrice();
        uint256 priceAfter = lrtOracle.primeETHPrice();
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
    function test_staker_lst_withdrawal_partial() public {
        address asset = Addresses.OETH_TOKEN;
        deposit(asset, oWhale, 6 ether);
        transfer_DelegatorNode(asset, 6 ether);
        transfer_Eigen(asset, Addresses.OETH_EIGEN_STRATEGY);

        uint256 whaleAssetsBefore = IERC20(asset).balanceOf(oWhale);

        uint256 primeAmount = 5 ether;
        uint256 primeETHPrice = lrtOracle.primeETHPrice();
        uint256 withdrawAssetAmount = primeAmount * primeETHPrice / 1e18;

        vm.recordLogs();

        vm.startPrank(oWhale);

        // Staker requests an OETH withdrawal
        lrtDepositPool.requestWithdrawal(asset, withdrawAssetAmount, primeAmount + 1);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManagerTypes.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[2].data, (bytes32, IDelegationManagerTypes.Withdrawal));

        // Move forward 100,801 blocks (~14 days)
        vm.roll(block.number + 100_801);

        // Claim the previously requested withdrawal
        lrtDepositPool.claimWithdrawal(withdrawal);

        assertApproxEqAbs(
            IERC20(asset).balanceOf(oWhale), whaleAssetsBefore + withdrawAssetAmount, 2, "whale OETH after within 2 wei"
        );

        vm.stopPrank();
    }

    function test_staker_lst_withdrawal_full() public {
        address asset = Addresses.OETH_TOKEN;

        uint256 whaleAssetsBefore = IERC20(asset).balanceOf(primeWhale);

        uint256 primeAmount = IERC20(Addresses.PRIME_STAKED_ETH).balanceOf(primeWhale);

        uint256 primeETHPrice = lrtOracle.primeETHPrice();
        uint256 withdrawAssetAmount = primeAmount * primeETHPrice / 1e18;

        vm.recordLogs();

        vm.startPrank(primeWhale);

        // Staker requests an OETH withdrawal
        lrtDepositPool.requestWithdrawal(asset, withdrawAssetAmount, primeAmount);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManagerTypes.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[2].data, (bytes32, IDelegationManagerTypes.Withdrawal));

        // Move forward 100,801 blocks (~14 days)
        vm.roll(block.number + 100_801);

        // Claim the previously requested withdrawal
        lrtDepositPool.claimWithdrawal(withdrawal);

        assertApproxEqAbs(
            IERC20(asset).balanceOf(primeWhale),
            whaleAssetsBefore + withdrawAssetAmount,
            1,
            "whale OETH after within 1 wei"
        );

        vm.stopPrank();
    }

    // staker withdrawal of LST
    function test_staker_lst_withdrawal_partial_yield_nest() public {
        address asset = Addresses.OETH_TOKEN;

        uint256 whaleYnLSDeBefore = IERC20(Addresses.YN_LSD_E).balanceOf(primeWhale);

        uint256 primeAmount = 5 ether;
        uint256 primeETHPrice = lrtOracle.primeETHPrice();
        uint256 withdrawAssetAmount = primeAmount * primeETHPrice / 1e18;

        vm.recordLogs();

        vm.startPrank(primeWhale);

        // Staker requests an OETH withdrawal
        lrtDepositPool.requestWithdrawal(asset, withdrawAssetAmount, primeAmount + 1);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManagerTypes.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[2].data, (bytes32, IDelegationManagerTypes.Withdrawal));

        // Move forward 100,801 blocks (~14 days)
        vm.roll(block.number + 100_801);

        // Should emit WithdrawalClaimed event
        vm.expectEmit({
            emitter: address(lrtDepositPool),
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
        emit WithdrawalClaimed(primeWhale, Addresses.YN_LSD_E, 0);

        // Claim the previously requested withdrawal but receive ynLSDe instead of OETH
        uint256 ynLSDeAmount = lrtDepositPool.claimWithdrawalYn(withdrawal);

        console.log("%s OETH was converted to %s ynLSDe", withdrawAssetAmount, ynLSDeAmount);

        assertApproxEqRel(
            IERC20(Addresses.YN_LSD_E).balanceOf(primeWhale),
            whaleYnLSDeBefore + withdrawAssetAmount,
            5e16,
            "whale ynLSDe after within 5% of OETH amount"
        );

        vm.stopPrank();
    }

    function test_staker_lst_withdrawal_full_yield_nest() public {
        address asset = Addresses.OETH_TOKEN;

        uint256 whaleYnLSDeBefore = IERC20(Addresses.YN_LSD_E).balanceOf(primeWhale);

        uint256 primeAmount = IERC20(Addresses.PRIME_STAKED_ETH).balanceOf(primeWhale);

        uint256 primeETHPrice = lrtOracle.primeETHPrice();
        uint256 withdrawAssetAmount = primeAmount * primeETHPrice / 1e18;

        vm.recordLogs();

        vm.startPrank(primeWhale);

        // Staker requests an OETH withdrawal
        lrtDepositPool.requestWithdrawal(asset, withdrawAssetAmount, primeAmount);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManagerTypes.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[2].data, (bytes32, IDelegationManagerTypes.Withdrawal));

        // Move forward 100,801 blocks (~14 days)
        vm.roll(block.number + 100_801);

        // Should emit WithdrawalClaimed event
        vm.expectEmit({
            emitter: address(lrtDepositPool),
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
        emit WithdrawalClaimed(primeWhale, Addresses.YN_LSD_E, 0);

        // Claim the previously requested withdrawal
        uint256 ynLSDeAmount = lrtDepositPool.claimWithdrawalYn(withdrawal);

        assertApproxEqRel(
            IERC20(Addresses.YN_LSD_E).balanceOf(primeWhale),
            whaleYnLSDeBefore + withdrawAssetAmount,
            5e16,
            "whale ynLSDe after within 5% of OETH amount"
        );

        vm.stopPrank();
    }

    // staker with withdrawal request before upgrade
    // from requestWithdrawal tx
    // https://etherscan.io/tx/0x75ab10b9f7287e9ff6661c4e7dbe0bdb1df6aed0e1b85064a5d34a8bdd65e86c#eventlog
    function test_staker_claim_after_upgrade() public {
        address asset = Addresses.OETH_TOKEN;

        address staker = 0xc9D4Ac5B09A7B9f9258089d09563B7AFb67bCe16;

        vm.startPrank(staker);

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(Addresses.OETH_EIGEN_STRATEGY);
        uint256[] memory scaledShares = new uint256[](1);
        scaledShares[0] = 11_540_344_205_946_929_570; // 11.540344205946929570 OETH shares

        IDelegationManagerTypes.Withdrawal memory withdrawal = IDelegationManagerTypes.Withdrawal({
            staker: Addresses.NODE_DELEGATOR,
            delegatedTo: 0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5,
            withdrawer: Addresses.NODE_DELEGATOR,
            nonce: 299,
            startBlock: 22_634_706,
            strategies: strategies,
            scaledShares: scaledShares
        });

        assertEq(
            keccak256(abi.encode(withdrawal)),
            0xf59b7bd2dbd6b7c747bb4bfc194e09df7c40440b8c7568f78b39ce24f630e66a,
            "withdrawal root mismatch"
        );

        // Claim the previously requested withdrawal
        lrtDepositPool.claimWithdrawal(withdrawal);

        vm.stopPrank();
    }

    // Prime Operator withdraws LSTs from Eigen Layer
    function test_operator_internal_withdrawal() public {
        withdrawAllFromEigenLayer(Addresses.OETH_TOKEN, Addresses.OETH_EIGEN_STRATEGY);
        // These have already been withdrawn
        //     withdrawAllFromEigenLayer(Addresses.SFRXETH_TOKEN, Addresses.SFRXETH_EIGEN_STRATEGY);
        //     withdrawAllFromEigenLayer(Addresses.METH_TOKEN, Addresses.METH_EIGEN_STRATEGY);
        //     withdrawAllFromEigenLayer(Addresses.STETH_TOKEN, Addresses.STETH_EIGEN_STRATEGY);
        //     withdrawAllFromEigenLayer(Addresses.RETH_TOKEN, Addresses.RETH_EIGEN_STRATEGY);
        //     withdrawAllFromEigenLayer(Addresses.SWETH_TOKEN, Addresses.SWETH_EIGEN_STRATEGY);
        //     withdrawAllFromEigenLayer(Addresses.ETHX_TOKEN, Addresses.ETHX_EIGEN_STRATEGY);
    }

    function withdrawAllFromEigenLayer(address asset, address strategy) internal {
        // Withdraw all the NodeDelegator's strategy shares
        uint256 shares = IStrategy(strategy).shares(address(nodeDelegator1));

        vm.recordLogs();

        vm.startPrank(Addresses.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(strategy, shares);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawal data from the Withdrawal event emitted from EigenLayer's DelegationManager
        (bytes32 withdrawalRoot, IDelegationManagerTypes.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[2].data, (bytes32, IDelegationManagerTypes.Withdrawal));

        // Move forward 100,801 blocks (~14 days)
        vm.roll(block.number + 100_801);

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
        assertApproxEqAbs(assetsElAfter, assetsElBefore + assetsNDCsBefore, 2, "assets in EigenLayer");
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
