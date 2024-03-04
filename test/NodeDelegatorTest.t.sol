// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { LRTConfigTest, ILRTConfig, LRTConstants, UtilLib, MockStrategy, IERC20 } from "./LRTConfigTest.t.sol";
import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";
import { NodeDelegator, INodeDelegator, ValidatorStakeData } from "contracts/NodeDelegator.sol";
import { MockToken } from "contracts/mocks/MockToken.sol";

import { BeaconChainProofs } from "contracts/interfaces/IEigenPod.sol";

contract MockEigenStrategyManager {
    mapping(address depositor => mapping(address strategy => uint256 shares)) public depositorStrategyShareBalances;

    address[] public strategies;

    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares) {
        token.transferFrom(msg.sender, address(strategy), amount);

        shares = amount;

        depositorStrategyShareBalances[msg.sender][address(strategy)] += shares;

        strategies.push(address(strategy));

        return shares;
    }

    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory) {
        uint256[] memory shares = new uint256[](strategies.length);
        IStrategy[] memory strategies_ = new IStrategy[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            strategies_[i] = IStrategy(strategies[i]);
            shares[i] = depositorStrategyShareBalances[depositor][strategies[i]];
        }

        return (strategies_, shares);
    }
}

contract MockSSVNetwork {
    address public ssvToken;

    constructor(address _ssvToken) {
        ssvToken = _ssvToken;
    }

    function deposit(
        address clusterOwner,
        uint64[] memory operatorIds,
        uint256 amount,
        Cluster memory cluster
    )
        public
    {
        IERC20(ssvToken).transferFrom(msg.sender, address(this), amount);
    }

    function registerValidator(
        bytes memory publicKey,
        uint64[] memory operatorIds,
        bytes memory sharesData,
        uint256 amount,
        Cluster memory cluster
    )
        external
    {
        IERC20(ssvToken).transferFrom(msg.sender, address(this), amount);
    }
}

contract MockEigenPodManager {
    mapping(address => address) public ownerToPod;

    function createPod() external {
        if (ownerToPod[msg.sender] != address(0)) {
            return;
        }
        ownerToPod[msg.sender] = address(new MockEigenPod());
    }

    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable {
        // do nothing
    }
}

contract MockEigenPod {
    function verifyWithdrawalCredentialsAndBalance(
        uint64 oracleBlockNumber,
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs memory proofs,
        bytes32[] calldata validatorFields
    )
        external
        view
        returns (uint256)
    {
        return 32 gwei;
    }

    receive() external payable { }
}

contract NodeDelegatorTest is LRTConfigTest {
    NodeDelegator public nodeDel;
    address public operator;

    MockEigenStrategyManager public mockEigenStrategyManager;

    MockStrategy public stETHMockStrategy;
    MockStrategy public ethXMockStrategy;
    address public mockLRTDepositPool;

    MockEigenPodManager public mockEigenPodManager;

    event UpdatedLRTConfig(address indexed lrtConfig);
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);

    uint256 public mockUserUnderlyingViewBalance;

    function setUp() public virtual override {
        super.setUp();

        operator = makeAddr("operator");

        // initialize LRTConfig
        lrtConfig.initialize(admin, address(stETH), address(ethX), prethMock);

        // add mockEigenStrategyManager to LRTConfig
        mockEigenStrategyManager = new MockEigenStrategyManager();
        vm.startPrank(admin);
        lrtConfig.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, address(mockEigenStrategyManager));

        mockEigenPodManager = new MockEigenPodManager();
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, address(mockEigenPodManager));

        // add WETH token
        lrtConfig.setToken(LRTConstants.WETH_TOKEN, address(weth));

        // add manager role
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);

        // add operator role
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, operator);

        // add mockStrategy to LRTConfig
        mockUserUnderlyingViewBalance = 10 ether;
        ethXMockStrategy = new MockStrategy(address(ethX), mockUserUnderlyingViewBalance);
        stETHMockStrategy = new MockStrategy(address(stETH), mockUserUnderlyingViewBalance);

        lrtConfig.updateAssetStrategy(address(ethX), address(ethXMockStrategy));
        lrtConfig.updateAssetStrategy(address(stETH), address(stETHMockStrategy));

        // add mockLRTDepositPool to LRTConfig
        mockLRTDepositPool = makeAddr("mockLRTDepositPool");
        lrtConfig.setContract(LRTConstants.LRT_DEPOSIT_POOL, mockLRTDepositPool);
        vm.stopPrank();

        // deploy NodeDelegator
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        NodeDelegator nodeDelImpl = new NodeDelegator(address(weth));
        TransparentUpgradeableProxy nodeDelProxy =
            new TransparentUpgradeableProxy(address(nodeDelImpl), address(proxyAdmin), "");

        nodeDel = NodeDelegator(payable(nodeDelProxy));

        // Add WETH as a supported asset
        vm.prank(manager);
        lrtConfig.addNewSupportedAsset(address(weth), 100_000 ether);
    }
}

contract NodeDelegatorInitialize is NodeDelegatorTest {
    function test_RevertInitializeIfAlreadyInitialized() external {
        nodeDel.initialize(address(lrtConfig));

        vm.startPrank(admin);
        // cannot initialize again
        vm.expectRevert("Initializable: contract is already initialized");
        nodeDel.initialize(address(lrtConfig));
        vm.stopPrank();
    }

    function test_RevertInitializeIfLRTConfigIsZero() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        nodeDel.initialize(address(0));
        vm.stopPrank();
    }

    function test_SetInitializableValues() external {
        expectEmit();
        emit UpdatedLRTConfig(address(lrtConfig));
        nodeDel.initialize(address(lrtConfig));

        assertEq(address(nodeDel.lrtConfig()), address(lrtConfig));
    }
}

contract NodeDelegatorCreateEigenPod is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.createEigenPod();
        vm.stopPrank();
    }

    function test_CreateEigenPod() external {
        assertEq(address(nodeDel.eigenPod()), address(0));

        vm.startPrank(manager);
        nodeDel.createEigenPod();
        vm.stopPrank();

        assertFalse(address(nodeDel.eigenPod()) == address(0));
    }
}

contract NodeDelegatorMaxApproveToEigenStrategyManager is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAddress = address(0x123);
        vm.startPrank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDel.maxApproveToEigenStrategyManager(randomAddress);
        vm.stopPrank();
    }

    function test_MaxApproveToEigenStrategyManager() external {
        vm.startPrank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
        vm.stopPrank();

        // check that the nodeDelegator has max approved the eigen strategy manager
        assertEq(ethX.allowance(address(nodeDel), address(mockEigenStrategyManager)), type(uint256).max);
    }
}

contract NodeDelegatorDepositAssetIntoStrategy is NodeDelegatorTest {
    uint256 public amountDeposited;

    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        // sends token to nodeDelegator so it can deposit it into the strategy
        amountDeposited = 10 ether;
        vm.prank(bob);
        ethX.transfer(address(nodeDel), amountDeposited);

        // max approve nodeDelegator to deposit into strategy
        vm.prank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
    }

    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.expectRevert("Pausable: paused");
        nodeDel.depositAssetIntoStrategy(address(ethX));

        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAddress = address(0x123);
        vm.startPrank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDel.depositAssetIntoStrategy(randomAddress);
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTOperator() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        vm.stopPrank();
    }

    function test_RevertWhenAnStrategyIsNotSetForAsset() external {
        address randomAddress = address(0x123);
        uint256 depositLimit = 100 ether;
        vm.prank(manager);
        lrtConfig.addNewSupportedAsset(randomAddress, depositLimit);

        vm.startPrank(operator);
        vm.expectRevert(INodeDelegator.StrategyIsNotSetForAsset.selector);
        nodeDel.depositAssetIntoStrategy(randomAddress);
        vm.stopPrank();
    }

    function test_DepositAssetIntoStrategy() external {
        vm.startPrank(operator);
        expectEmit();
        emit AssetDepositIntoStrategy(address(ethX), address(ethXMockStrategy), amountDeposited);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        vm.stopPrank();

        // check that strategy received LST via the eigen strategy manager
        assertEq(ethX.balanceOf(address(ethXMockStrategy)), amountDeposited);
    }
}

contract NodeDelegatorTransferBackToLRTDepositPool is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();

        nodeDel.initialize(address(lrtConfig));

        // transfer ethX to NodeDelegator
        vm.prank(bob);
        ethX.transfer(address(nodeDel), 10 ether);
    }

    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.expectRevert("Pausable: paused");
        nodeDel.transferBackToLRTDepositPool(address(ethX), 10 ether);

        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.transferBackToLRTDepositPool(address(ethX), 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAddress = address(0x123);
        vm.startPrank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDel.transferBackToLRTDepositPool(randomAddress, 10 ether);
        vm.stopPrank();
    }

    function test_TransferBackToLRTDepositPool() external {
        uint256 amountToDeposit = 3 ether;

        uint256 nodeDelBalanceBefore = ethX.balanceOf(address(nodeDel));

        // transfer funds in NodeDelegator to to LRTDepositPool
        vm.startPrank(manager);
        nodeDel.transferBackToLRTDepositPool(address(ethX), amountToDeposit);
        vm.stopPrank();

        uint256 nodeDelBalanceAfter = ethX.balanceOf(address(nodeDel));

        assertEq(nodeDelBalanceAfter, nodeDelBalanceBefore - amountToDeposit, "NodeDelegator balance did not increase");

        assertEq(ethX.balanceOf(mockLRTDepositPool), amountToDeposit, "LRTDepositPool balance did not increase");
    }

    function test_TransferWETHBackToLRTDepositPool() external {
        uint256 amountToDeposit = 3 ether;

        // mint some WETH to NodeDelegator
        weth.mint(address(nodeDel), 100 ether);
        uint256 nodeDelBalanceBefore = weth.balanceOf(address(nodeDel));

        // transfer funds in NodeDelegator to to LRTDepositPool
        vm.prank(manager);
        nodeDel.transferBackToLRTDepositPool(address(weth), amountToDeposit);

        uint256 nodeDelBalanceAfter = weth.balanceOf(address(nodeDel));

        assertEq(nodeDelBalanceAfter, nodeDelBalanceBefore - amountToDeposit, "NodeDelegator balance did not decrease");

        assertEq(
            weth.balanceOf(address(mockLRTDepositPool)), amountToDeposit, "LRTDepositPool balance did not increase"
        );
    }
}

contract NodeDelegatorGetAssetBalances is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        // sends token to nodeDelegator so it can deposit it into the strategy
        vm.startPrank(bob);
        ethX.transfer(address(nodeDel), 10 ether);
        stETH.transfer(address(nodeDel), 5 ether);
        weth.transfer(address(nodeDel), 2 ether);
        vm.stopPrank();

        // max approve nodeDelegator to deposit into strategy
        vm.startPrank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
        nodeDel.maxApproveToEigenStrategyManager(address(stETH));
        vm.stopPrank();
    }

    function test_GetAssetBalances() external {
        // deposit NodeDelegator balance into strategy
        vm.startPrank(operator);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        nodeDel.depositAssetIntoStrategy(address(stETH));
        vm.stopPrank();

        // get asset balances in strategies
        (address[] memory assets, uint256[] memory assetBalances) = nodeDel.getAssetBalances();

        assertEq(assets.length, 3, "Incorrect number of assets");
        assertEq(assets[0], address(stETH), "stETH not asset 0");
        assertEq(assets[1], address(ethX), "ethX not asset 1");
        assertEq(assets[2], address(weth), "WETH not asset 2");
        assertEq(assetBalances.length, 3, "Incorrect number of asset balances");
        assertEq(assetBalances[0], mockUserUnderlyingViewBalance, "Incorrect asset balance for stETH");
        assertEq(assetBalances[1], mockUserUnderlyingViewBalance, "Incorrect asset balance for ethX");
        assertEq(assetBalances[2], 2e18, "Incorrect asset balance for WETH");
    }
}

contract NodeDelegatorGetAssetBalance is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        // sends token to nodeDelegator so it can deposit it into the strategy
        vm.prank(bob);
        ethX.transfer(address(nodeDel), 6 ether);

        // max approve nodeDelegator to deposit into strategy
        vm.prank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
    }

    function test_GetAssetBalance() external {
        // deposit NodeDelegator balance into strategy
        vm.startPrank(operator);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        vm.stopPrank();

        // get asset balances in strategies
        (uint256 ethXInNDC, uint256 ethXInEigenLayer) = nodeDel.getAssetBalance(address(ethX));

        assertEq(ethXInNDC, 0, "ETHx in NodeDelegator");
        assertEq(ethXInEigenLayer, mockUserUnderlyingViewBalance, "ETHx in EigenLayer");
    }
}

contract NodeDelegatorGetWETHEigenPodBalance is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        vm.prank(manager);
        nodeDel.createEigenPod();

        // add WETH to nodeDelegator so it can deposit it into the EigenPodManager
        uint256 amount = 1000 ether;
        weth.mint(address(nodeDel), amount);
        vm.deal(address(weth), amount);

        // stake ETH in EigenPodManager
        vm.prank(operator);
        ValidatorStakeData[] memory blankValidator = new ValidatorStakeData[](1);
        blankValidator[0] = ValidatorStakeData(hex"", hex"", hex"");
        nodeDel.stakeEth(blankValidator);
    }

    function test_GetWTHEigenPodBalance() external {
        (uint256 wethInNDC, uint256 wethInEigenLayer) = nodeDel.getAssetBalance(address(weth));
        assertEq(wethInNDC, 968 ether, "WETH in Node Delegator");
        assertEq(wethInEigenLayer, 32 ether, "ETH in EigenPod");
    }
}

contract NodeDelegatorStakeETH is NodeDelegatorTest {
    uint256 public amount;

    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        vm.prank(manager);
        nodeDel.createEigenPod();

        // add WETH to nodeDelegator so it can deposit it into the EigenPodManager
        amount = 96 ether;
        weth.mint(address(nodeDel), amount);
        vm.deal(address(weth), amount);
    }

    function test_revertWhenCallerIsNotLRTOperator() external {
        ValidatorStakeData[] memory validators = new ValidatorStakeData[](0);
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        nodeDel.stakeEth(validators);
        vm.stopPrank();
    }

    function test_stakeETH() external {
        // add WETH to nodeDelegator so it can deposit it into 3 validators
        weth.mint(address(nodeDel), amount);
        vm.deal(address(weth), amount);

        (uint256 nodeDelWethBefore, uint256 ethEigenPodBalanceBefore) = nodeDel.getAssetBalance(address(weth));

        vm.prank(operator);
        ValidatorStakeData memory someValidator = ValidatorStakeData(new bytes(1), hex"", hex"");
        ValidatorStakeData memory someValidator1 = ValidatorStakeData(new bytes(2), hex"", hex"");
        ValidatorStakeData memory someValidator2 = ValidatorStakeData(new bytes(3), hex"", hex"");
        ValidatorStakeData[] memory validators = new ValidatorStakeData[](3);
        validators[0] = someValidator;
        validators[1] = someValidator1;
        validators[2] = someValidator2;
        nodeDel.stakeEth(validators);

        (uint256 nodeDelWethAfter, uint256 ethEigenPodBalance) = nodeDel.getAssetBalance(address(weth));

        assertEq(nodeDelWethAfter, nodeDelWethBefore - amount, "NodeDelegator balance did not decrease");

        assertEq(ethEigenPodBalance, amount + ethEigenPodBalanceBefore, "Incorrect ETH balance in EigenPod");

        uint256 stakedButNotVerifiedEth = nodeDel.stakedButNotVerifiedEth();
        assertEq(stakedButNotVerifiedEth, amount, "Incorrect staked but not verified ETH");
    }

    function test_revertStakeETH() external {
        // add WETH to nodeDelegator so it can deposit it into 2 validators
        weth.mint(address(nodeDel), amount);
        vm.deal(address(weth), amount);

        (uint256 nodeDelWethBefore, uint256 ethEigenPodBalanceBefore) = nodeDel.getAssetBalance(address(weth));

        vm.prank(operator);
        ValidatorStakeData memory someValidator = ValidatorStakeData(new bytes(1), hex"", hex"");
        ValidatorStakeData[] memory validators = new ValidatorStakeData[](3);
        // not allowed to stake the same validator twice
        validators[0] = someValidator;
        validators[1] = someValidator;

        bytes4 selector = bytes4(keccak256("ValidatorAlreadyStaked(bytes)"));
        vm.expectRevert(abi.encodeWithSelector(selector, new bytes(1)));
        nodeDel.stakeEth(validators);
    }
}

contract NodeDelegatorPause is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.pause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsAlreadyPaused() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.expectRevert("Pausable: paused");
        nodeDel.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.stopPrank();

        assertTrue(nodeDel.paused(), "Contract is not paused");
    }
}

contract NodeDelegatorUnpause is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        vm.startPrank(manager);
        nodeDel.pause();
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTAdmin() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        nodeDel.unpause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsNotPaused() external {
        vm.startPrank(admin);
        nodeDel.unpause();

        vm.expectRevert("Pausable: not paused");
        nodeDel.unpause();

        vm.stopPrank();
    }

    function test_Unpause() external {
        vm.startPrank(admin);
        nodeDel.unpause();

        vm.stopPrank();

        assertFalse(nodeDel.paused(), "Contract is still paused");
    }
}

contract NodeDelegatorSSV is NodeDelegatorTest {
    MockToken ssvToken;
    address ssvNetwork;
    uint64[] operatorIds;
    Cluster cluster;

    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
        ssvToken = new MockToken("SSV", "SSV");
        ssvToken.mint(manager, 1000 ether);

        ssvNetwork = address(new MockSSVNetwork(address(ssvToken)));

        operatorIds = new uint64[](3);
        operatorIds[0] = 10;
        operatorIds[1] = 100;
        operatorIds[2] = 200;
        cluster = Cluster(0, 0, 0, false, 0);

        vm.startPrank(admin);
        lrtConfig.setContract(LRTConstants.SSV_TOKEN, address(ssvToken));
        lrtConfig.setContract(LRTConstants.SSV_NETWORK, ssvNetwork);
        vm.stopPrank();
    }

    function test_approveRevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.approveSSV();
        vm.stopPrank();
    }

    function test_depositRevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);

        nodeDel.depositSSV(operatorIds, 10 ether, cluster);
        vm.stopPrank();
    }

    function test_registerValidatorRevertWhenCallerIsNotLRTOperator() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);

        nodeDel.registerSsvValidator(hex"", operatorIds, hex"", 10 ether, cluster);
        vm.stopPrank();
    }

    function test_approveSSV() external {
        vm.prank(manager);

        expectEmit();
        emit IERC20.Approval(address(nodeDel), ssvNetwork, type(uint256).max);

        nodeDel.approveSSV();
    }

    function test_depositSSV() external {
        vm.startPrank(manager);

        nodeDel.approveSSV();
        ssvToken.transfer(address(nodeDel), 10 ether);

        nodeDel.depositSSV(operatorIds, 10 ether, cluster);
        vm.stopPrank();
    }

    function test_registerValidator() external {
        vm.startPrank(manager);

        nodeDel.approveSSV();
        ssvToken.transfer(address(nodeDel), 10 ether);
        vm.stopPrank();

        vm.prank(operator);
        nodeDel.registerSsvValidator(hex"", operatorIds, hex"", 10 ether, cluster);
    }
}
