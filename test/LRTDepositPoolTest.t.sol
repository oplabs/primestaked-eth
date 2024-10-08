// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { BaseTest } from "./BaseTest.t.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeStakedETHTest, ILRTConfig, UtilLib, LRTConstants } from "./PrimeStakedETHTest.t.sol";
import { ILRTDepositPool } from "contracts/interfaces/ILRTDepositPool.sol";
import { MockStrategy } from "contracts/eigen/mocks/MockStrategy.sol";
import { MockToken } from "contracts/mocks/MockToken.sol";
import { MockWOETH } from "contracts/mocks/MockWOETH.sol";
import { MockYnEigen } from "contracts/mocks/MockYnEigen.sol";
import { MockNodeDelegator } from "contracts/mocks/MockNodeDelegator.sol";
import { IDelegationManager } from "contracts/eigen/interfaces/IDelegationManager.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract LRTOracleMock {
    mapping(address => uint256) public assetPrice;

    function getAssetPrice(address asset) external view returns (uint256) {
        return assetPrice[asset];
    }

    function primeETHPrice() external pure returns (uint256) {
        // primeETH has grown 1% in value
        return 1.01e18;
    }

    function setAssetPrice(address asset, uint256 price) external {
        assetPrice[asset] = price;
    }
}

contract LRTDepositPoolTest is BaseTest, PrimeStakedETHTest {
    LRTDepositPool public lrtDepositPool;
    LRTOracleMock public lrtOracle;

    uint256 public minimunAmountOfPRETHToReceive;
    string public referralId;

    MockWOETH public wOETH;
    MockYnEigen public ynLSDe;

    event ETHDeposit(address indexed depositor, uint256 depositAmount, uint256 prethMintAmount, string referralId);

    function setUp() public virtual override(PrimeStakedETHTest, BaseTest) {
        super.setUp();

        wOETH = new MockWOETH(oeth);
        ynLSDe = new MockYnEigen("Yield Nest LSD for Ether", "ynLSDe");

        vm.label(address(wOETH), "wOETH");
        vm.label(address(ynLSDe), "ynLSDe");

        // deploy LRTDepositPool
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        LRTDepositPool contractImpl = new LRTDepositPool(address(weth), address(ethX), address(wOETH), address(ynLSDe));
        TransparentUpgradeableProxy contractProxy =
            new TransparentUpgradeableProxy(address(contractImpl), address(proxyAdmin), "");

        lrtDepositPool = LRTDepositPool(payable(contractProxy));

        // initialize PrimeStakedETHTest. LRTCOnfig is already initialized in PrimeStakedETHTest
        preth.initialize(address(lrtConfig));
        vm.startPrank(admin);
        // add prETH to LRT config
        lrtConfig.setPrimeETH(address(preth));
        // add oracle to LRT config
        lrtOracle = new LRTOracleMock();
        lrtOracle.setAssetPrice(address(weth), 1e18);
        lrtOracle.setAssetPrice(address(stETH), 0.9997e18);
        lrtOracle.setAssetPrice(address(ethX), 1.0324e18);
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(lrtOracle));

        // add minter role for preth to lrtDepositPool
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPool));

        vm.stopPrank();

        minimunAmountOfPRETHToReceive = 0;
        referralId = "42";

        // add manager role within LRTConfig
        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        vm.stopPrank();

        vm.startPrank(manager);
        // set ETH as supported token
        lrtConfig.addNewSupportedAsset(address(weth), 100_000 ether);
        vm.stopPrank();
    }
}

contract LRTDepositPoolInitialize is LRTDepositPoolTest {
    function test_RevertWhenLRTConfigIsZeroAddress() external {
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        lrtDepositPool.initialize(address(0));
    }

    function test_InitializeContractsVariables() external {
        lrtDepositPool.initialize(address(lrtConfig));

        assertEq(lrtDepositPool.maxNodeDelegatorLimit(), 10, "Max node delegator count is not set");
        assertEq(address(lrtConfig), address(lrtDepositPool.lrtConfig()), "LRT config address is not set");
    }
}

contract LRTDepositPoolDepositAsset is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_RevertWhenDepositAmountIsZero() external {
        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);
        lrtDepositPool.depositAsset(ethXAddress, 0, minimunAmountOfPRETHToReceive, referralId);
    }

    function test_RevertWhenDepositAmountIsLessThanMinAmountToDeposit() external {
        vm.startPrank(admin);
        lrtDepositPool.setMinAmountToDeposit(1 ether);
        vm.stopPrank();

        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);
        lrtDepositPool.depositAsset(ethXAddress, 0.5 ether, minimunAmountOfPRETHToReceive, referralId);
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAsset = makeAddr("randomAsset");

        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        lrtDepositPool.depositAsset(randomAsset, 1 ether, minimunAmountOfPRETHToReceive, referralId);
    }

    function test_RevertWhenDepositAmountExceedsLimit() external {
        vm.prank(manager);
        lrtConfig.updateAssetDepositLimit(ethXAddress, 1 ether);

        vm.expectRevert(ILRTDepositPool.MaximumDepositLimitReached.selector);
        lrtDepositPool.depositAsset(ethXAddress, 2 ether, minimunAmountOfPRETHToReceive, referralId);
    }

    function test_RevertWhenMinAmountToReceiveIsNotMet() external {
        vm.startPrank(alice);

        ethX.approve(address(lrtDepositPool), 2 ether);

        // increase the minimum amount of prETH to receive to an amount that is not met
        minimunAmountOfPRETHToReceive = 100 ether;

        vm.expectRevert(ILRTDepositPool.MinimumAmountToReceiveNotMet.selector);
        lrtDepositPool.depositAsset(ethXAddress, 0.5 ether, minimunAmountOfPRETHToReceive, referralId);

        vm.stopPrank();
    }

    function test_DepositAsset() external {
        vm.startPrank(alice);

        // alice balance of prETH before deposit
        uint256 aliceBalanceBefore = preth.balanceOf(address(alice));

        minimunAmountOfPRETHToReceive = lrtDepositPool.getMintAmount(ethXAddress, 2 ether);

        ethX.approve(address(lrtDepositPool), 2 ether);
        lrtDepositPool.depositAsset(ethXAddress, 2 ether, minimunAmountOfPRETHToReceive, referralId);

        // alice balance of prETH after deposit
        uint256 aliceBalanceAfter = preth.balanceOf(address(alice));
        vm.stopPrank();

        assertEq(lrtDepositPool.getTotalAssetDeposits(ethXAddress), 2 ether, "Total asset deposits is not set");
        assertGt(aliceBalanceAfter, aliceBalanceBefore, "Alice balance is not set");
    }

    function test_FuzzDepositAsset(uint256 amountDeposited) external {
        uint256 stETHDepositLimit = lrtConfig.depositLimitByAsset(address(stETH));
        // The asset price is < 1 so amountDeposited = 1 will mint zero primeETH
        vm.assume(amountDeposited > 1 && amountDeposited <= stETHDepositLimit);

        uint256 aliceBalanceBefore = preth.balanceOf(address(alice));

        vm.startPrank(alice);
        stETH.approve(address(lrtDepositPool), amountDeposited);
        lrtDepositPool.depositAsset(address(stETH), amountDeposited, minimunAmountOfPRETHToReceive, referralId);
        vm.stopPrank();

        uint256 aliceBalanceAfter = preth.balanceOf(address(alice));

        assertEq(
            lrtDepositPool.getTotalAssetDeposits(address(stETH)), amountDeposited, "Total asset deposits is not set"
        );
        assertGt(aliceBalanceAfter, aliceBalanceBefore, "Alice balance is not set");
    }
}

contract LRTDepositPoolGetRsETHAmountToMint is LRTDepositPoolTest {
    address public ethXAddress;
    uint256 public primeEthPrice = 1.01e18;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_GetRsETHAmountToMintWhenAssetIsLST() external {
        uint256 amountToDeposit = 1 ether;
        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(ethXAddress, amountToDeposit);
        vm.stopPrank();

        uint256 assetPrice = lrtOracle.getAssetPrice(ethXAddress);

        assertEq(
            lrtDepositPool.getMintAmount(ethXAddress, amountToDeposit),
            amountToDeposit * assetPrice / primeEthPrice,
            "RsETH amount to mint is incorrect"
        );
    }

    function test_GetRsETHAmountToMintWhenAssetisNativeETH() external {
        uint256 amountToDeposit = 1 ether;

        uint256 assetPrice = 1e18;

        assertEq(
            lrtDepositPool.getMintAmount(address(weth), amountToDeposit),
            amountToDeposit * assetPrice / primeEthPrice,
            "RsETH amount to mint is incorrect"
        );
    }
}

contract LRTDepositPoolGetAssetCurrentLimit is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_GetAssetCurrentLimit() external {
        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(address(stETH), 1 ether);
        vm.stopPrank();

        assertEq(lrtDepositPool.getAssetCurrentLimit(address(stETH)), 1 ether, "Asset current limit is not set");
    }

    function test_GetAssetCurrentLimitAfterAssetIsDeposited() external {
        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(address(stETH), 10 ether);
        vm.stopPrank();

        // deposit 1 ether stETH
        vm.startPrank(alice);
        stETH.approve(address(lrtDepositPool), 6 ether);
        lrtDepositPool.depositAsset(address(stETH), 6 ether, minimunAmountOfPRETHToReceive, referralId);
        vm.stopPrank();

        assertEq(lrtDepositPool.getAssetCurrentLimit(address(stETH)), 4 ether, "Asset current limit is not set");
    }
}

contract LRTDepositPoolGetNodeDelegatorQueue is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetNodeDelegatorQueue() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        assertEq(lrtDepositPool.getNodeDelegatorQueue(), nodeDelegatorQueue, "Node delegator queue is not set");
    }
}

contract LRTDepositPoolGetTotalAssetDeposits is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetTotalAssetDeposits() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        uint256 amountToDeposit = 1 ether;

        uint256 totalDepositsBefore = lrtDepositPool.getTotalAssetDeposits(address(ethX));

        // deposit ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), amountToDeposit);
        lrtDepositPool.depositAsset(address(ethX), amountToDeposit, minimunAmountOfPRETHToReceive, referralId);
        vm.stopPrank();

        assertEq(
            lrtDepositPool.getTotalAssetDeposits(address(ethX)),
            totalDepositsBefore + amountToDeposit,
            "Incorrect total asset deposits amount"
        );
    }
}

contract LRTDepositPoolGetAssetDistributionData is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_GetAssetDistributionData() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        // deposit 3 ether ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 3 ether);
        lrtDepositPool.depositAsset(ethXAddress, 3 ether, minimunAmountOfPRETHToReceive, referralId);
        vm.stopPrank();

        (uint256 assetLyingInDepositPool, uint256 assetLyingInNDCs, uint256 assetStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(ethXAddress);

        assertEq(assetLyingInDepositPool, 3 ether, "Asset lying in deposit pool is not set");
        assertEq(assetLyingInNDCs, 0, "Asset lying in NDCs is not set");
        assertEq(assetStakedInEigenLayer, 3 ether, "Asset staked in eigen layer is not set");
    }
}

contract LRTDepositPoolGetETHDistributionData is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetETHDistributionData() external {
        address[] memory assets = new address[](3);
        assets[0] = address(stETH);
        assets[1] = address(ethX);
        assets[2] = address(weth);

        uint256[] memory assetBalances = new uint256[](3);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;
        assetBalances[2] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtConfig.setToken(LRTConstants.WETH_TOKEN, address(weth));
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        // vm.startPrank(manager);
        // lrtConfig.addNewSupportedAsset(address(weth), 10_000 ether);
        // vm.stopPrank();

        // deposit 3 WETH
        vm.startPrank(alice);
        weth.approve(address(lrtDepositPool), 5 ether);
        lrtDepositPool.depositAsset(address(weth), 5 ether, 0, referralId);
        vm.stopPrank();

        (uint256 wethLyingInDepositPool, uint256 wethLyingInNDCs, uint256 ethStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(address(weth));

        assertEq(wethLyingInDepositPool, 5 ether, "WETH lying in deposit pool is not set");
        assertEq(wethLyingInNDCs, 0, "WETH lying in NDCs is not set");
        assertEq(ethStakedInEigenLayer, 3 ether, "ETH staked in Eigen Layer is not set");

        // check using getAssetDistributionData
        (wethLyingInDepositPool, wethLyingInNDCs, ethStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(address(weth));

        assertEq(wethLyingInDepositPool, 5 ether, "WETH lying in deposit pool is not set");
        assertEq(wethLyingInNDCs, 0, "WETH lying in NDCs is not set");
        assertEq(ethStakedInEigenLayer, 3 ether, "ETH staked in Eigen Layer is not set");
    }
}

contract LRTDepositPoolAddNodeDelegatorContractToQueue is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        vm.stopPrank();
    }

    function test_RevertWhenNodeDelegatorLimitExceedsLimit() external {
        vm.startPrank(admin);

        uint256 maxDelegatorCount = lrtDepositPool.maxNodeDelegatorLimit();

        for (uint256 i = 0; i < maxDelegatorCount; i++) {
            address madeUpNodeDelegatorAddress = makeAddr(string(abi.encodePacked("nodeDelegatorContract", i)));

            address[] memory nodeDelegatorContractArray = new address[](1);
            nodeDelegatorContractArray[0] = madeUpNodeDelegatorAddress;

            lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorContractArray);
        }

        // add one more node delegator contract to go above limit
        vm.expectRevert(ILRTDepositPool.MaximumNodeDelegatorLimitReached.selector);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        vm.stopPrank();
    }

    function test_AddNodeDelegatorContractToQueue() external {
        // get node delegator queue length before adding node delegator contracts
        uint256 nodeDelegatorQueueLengthBefore = lrtDepositPool.getNodeDelegatorQueue().length;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        // assert node delegator queue length is the same as nodeDelegatorQueueProspectives length
        assertEq(
            lrtDepositPool.getNodeDelegatorQueue().length,
            nodeDelegatorQueueProspectives.length + nodeDelegatorQueueLengthBefore,
            "Node delegator queue length is not set"
        );

        assertEq(
            lrtDepositPool.nodeDelegatorQueue(0),
            nodeDelegatorQueueProspectives[0],
            "Node delegator index 0 contract is not added"
        );
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(1),
            nodeDelegatorQueueProspectives[1],
            "Node delegator index 1 contract is not added"
        );
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(2),
            nodeDelegatorQueueProspectives[2],
            "Node delegator index 2 contract is not added"
        );

        // if we add the same node delegator contract again, it should not be added
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        assertEq(
            lrtDepositPool.getNodeDelegatorQueue().length,
            nodeDelegatorQueueProspectives.length + nodeDelegatorQueueLengthBefore,
            "Node delegator queue length is not set"
        );
        vm.stopPrank();
    }
}

contract LTRRemoveNodeDelegatorFromQueue is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);

        // add node delegator contracts to queue
        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(address(nodeDelegatorContractOne));

        vm.stopPrank();
    }

    function test_RevertWhenNodeDelegatorIndexIsNotValid() external {
        address nodeDelegatorContractFour = address(new MockNodeDelegator(new address[](0), new uint256[](0)));

        vm.startPrank(admin);

        vm.expectRevert(ILRTDepositPool.NodeDelegatorNotFound.selector);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(nodeDelegatorContractFour);

        vm.stopPrank();
    }

    function test_RevertWhenNodeDelegatorHasAssetBalance() external {
        vm.startPrank(admin);

        uint256 amountToDeposit = 1 ether;
        bytes memory errorData = abi.encodeWithSelector(
            ILRTDepositPool.NodeDelegatorHasAssetBalance.selector,
            address(stETH), // asset
            amountToDeposit // asset balance
        );

        vm.expectRevert(errorData);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(nodeDelegatorContractOne);

        vm.stopPrank();
    }

    function test_RemoveNodeDelegatorContractFromQueue() external {
        // mock contract function to remove asset balance from node delegator contract two
        MockNodeDelegator(nodeDelegatorContractTwo).removeAssetBalance();

        // remove node delegator contract one from queue
        vm.startPrank(admin);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(nodeDelegatorContractTwo);
        vm.stopPrank();

        assertEq(lrtDepositPool.getNodeDelegatorQueue().length, 2, "Node delegator queue length is not set");
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(0), nodeDelegatorContractOne, "Node delegator index 0 contract is not set"
        );
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(1),
            nodeDelegatorContractThree,
            "Node delegator index 1 contract is not set"
        );
        assertEq(lrtDepositPool.isNodeDelegator(nodeDelegatorContractTwo), 0, "Node delegator is not removed");
    }

    function test_RemoveManyNodeDelegatorContractsFromQueue() external {
        // mock contract function to remove asset balance from node delegator contract one
        MockNodeDelegator(nodeDelegatorContractOne).removeAssetBalance();
        MockNodeDelegator(nodeDelegatorContractTwo).removeAssetBalance();

        // remove node delegator contract one from queue
        address[] memory nodeDelegatorContractsToRemove = new address[](2);
        nodeDelegatorContractsToRemove[0] = nodeDelegatorContractOne;
        nodeDelegatorContractsToRemove[1] = nodeDelegatorContractTwo;

        vm.startPrank(admin);
        lrtDepositPool.removeManyNodeDelegatorContractsFromQueue(nodeDelegatorContractsToRemove);
        vm.stopPrank();

        assertEq(lrtDepositPool.getNodeDelegatorQueue().length, 1, "Node delegator queue length is not set");
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(0),
            nodeDelegatorContractThree,
            "Node delegator index 0 contract is not set"
        );
        assertEq(lrtDepositPool.isNodeDelegator(nodeDelegatorContractOne), 0, "Node delegator 1 is not removed");
        assertEq(lrtDepositPool.isNodeDelegator(nodeDelegatorContractTwo), 0, "Node delegator 2 is not removed");
    }
}

contract LRTDepositPoolTransferAssetToNodeDelegator is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    address public operator;

    function setUp() public override {
        super.setUp();

        operator = makeAddr("operator");

        vm.prank(admin);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, operator);

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;
        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);

        // add node delegator contracts to queue
        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigOperator() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        lrtDepositPool.transferAssetToNodeDelegator(0, address(ethX), 1 ether);

        address[] memory assets = new address[](2);
        assets[0] = address(ethX);
        assets[1] = address(stETH);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        lrtDepositPool.transferAssetsToNodeDelegator(0, assets);

        vm.stopPrank();
    }

    function test_TransferAssetToNodeDelegator() external {
        // deposit 3 ether ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 3 ether);
        lrtDepositPool.depositAsset(address(ethX), 3 ether, minimunAmountOfPRETHToReceive, referralId);
        vm.stopPrank();

        uint256 indexOfNodeDelegatorContractOneInNDArray;
        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (lrtDepositPool.nodeDelegatorQueue(i) == nodeDelegatorContractOne) {
                indexOfNodeDelegatorContractOneInNDArray = i;
                break;
            }
        }

        // transfer 1 ether ethX to node delegator contract one
        vm.startPrank(operator);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegatorContractOneInNDArray, address(ethX), 1 ether);
        vm.stopPrank();

        assertEq(ethX.balanceOf(address(lrtDepositPool)), 2 ether, "Asset amount in lrtDepositPool is incorrect");
        assertEq(ethX.balanceOf(nodeDelegatorContractOne), 1 ether, "Asset is not transferred to node delegator");
    }

    // TODO add bulk transfer unit test
    function test_TransferAssetsToNodeDelegator() external {
        // deposit 3 ether ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 3 ether);
        lrtDepositPool.depositAsset(address(ethX), 3 ether, minimunAmountOfPRETHToReceive, referralId);

        stETH.approve(address(lrtDepositPool), 6 ether);
        lrtDepositPool.depositAsset(address(stETH), 6 ether, minimunAmountOfPRETHToReceive, referralId);
        vm.stopPrank();

        uint256 indexOfNodeDelegatorContractOneInNDArray;
        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (lrtDepositPool.nodeDelegatorQueue(i) == nodeDelegatorContractOne) {
                indexOfNodeDelegatorContractOneInNDArray = i;
                break;
            }
        }

        // transfer 1 ether ethX to node delegator contract one
        vm.startPrank(operator);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegatorContractOneInNDArray, address(ethX), 1 ether);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegatorContractOneInNDArray, address(stETH), 2 ether);
        vm.stopPrank();

        assertEq(ethX.balanceOf(address(lrtDepositPool)), 2 ether, "ETHx amount in lrtDepositPool is incorrect");
        assertEq(ethX.balanceOf(nodeDelegatorContractOne), 1 ether, "ETHx is not transferred to node delegator");

        assertEq(stETH.balanceOf(address(lrtDepositPool)), 4 ether, "stETH amount in lrtDepositPool is incorrect");
        assertEq(stETH.balanceOf(nodeDelegatorContractOne), 2 ether, "stETH is not transferred to node delegator");
    }
}

contract LRTDepositTransferETHToNodeDelegator is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;
        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);

        // add node delegator contracts to queue
        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);
        vm.stopPrank();
    }
}

contract LRTDepositPoolSwapAssetFromDepositPool is LRTDepositPoolTest {
    event AssetSwapped(
        address indexed fromAsset, address indexed toAsset, uint256 fromAssetAmount, uint256 toAssetAmount
    );

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        // send 5 stETH to manager
        vm.prank(alice);
        stETH.transfer(manager, 5 ether);

        // deposit 5 ethX to lrtDepositPool
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 5 ether);
        lrtDepositPool.depositAsset(address(ethX), 5 ether, 0, "");
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.swapAssetWithinDepositPool(address(stETH), address(ethX), 1 ether, 1 ether);

        vm.stopPrank();
    }

    function test_SwapAssetFromDepositPool() external {
        uint256 amountToSwap = 3 ether;

        uint256 minimumAmountOfEthxToReceive =
            lrtDepositPool.getSwapAssetReturnAmount(address(stETH), address(ethX), amountToSwap);

        uint256 balanceOfEthxBefore = ethX.balanceOf(address(lrtDepositPool));
        uint256 balanceOfStethBefore = stETH.balanceOf(address(lrtDepositPool));

        uint256 managerBalanceOfEthxBefore = ethX.balanceOf(manager);
        uint256 managerBalanceOfStethBefore = stETH.balanceOf(manager);

        vm.startPrank(manager);
        stETH.approve(address(lrtDepositPool), amountToSwap);

        expectEmit();
        emit AssetSwapped(address(stETH), address(ethX), amountToSwap, minimumAmountOfEthxToReceive);
        lrtDepositPool.swapAssetWithinDepositPool(
            address(stETH), address(ethX), amountToSwap, minimumAmountOfEthxToReceive
        );
        vm.stopPrank();

        uint256 balanceOfEthxAfter = ethX.balanceOf(address(lrtDepositPool));
        uint256 balanceOfStethAfter = stETH.balanceOf(address(lrtDepositPool));

        uint256 managerBalanceOfEthxAfter = ethX.balanceOf(manager);
        uint256 managerBalanceOfStethAfter = stETH.balanceOf(manager);

        assertEq(
            balanceOfEthxAfter,
            balanceOfEthxBefore - minimumAmountOfEthxToReceive,
            "Ethx was not removed properly from lrtDepositPool"
        );
        assertEq(
            balanceOfStethAfter, balanceOfStethBefore + amountToSwap, "StETH was not added properly to lrtDepositPool"
        );

        assertEq(
            managerBalanceOfEthxAfter,
            managerBalanceOfEthxBefore + minimumAmountOfEthxToReceive,
            "Ethx was not given properly to manager"
        );
        assertEq(
            managerBalanceOfStethAfter,
            managerBalanceOfStethBefore - amountToSwap,
            "StETH was not removed properly from manager"
        );
    }
}

contract LRTDepositPoolGetSwapAssetReturnAmount is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetSwapAssetReturnAmount() external {
        uint256 amountToSwap = 3 ether;

        uint256 minimumAmountOfEthxToReceive =
            lrtDepositPool.getSwapAssetReturnAmount(address(stETH), address(ethX), amountToSwap);

        assertGt(minimumAmountOfEthxToReceive, 1 ether, "Minimum amount of ethx to receive is incorrect");
    }
}

contract LRTDepositPoolUpdateMaxNodeDelegatorLimit is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.updateMaxNodeDelegatorLimit(10);

        vm.stopPrank();
    }

    function test_UpdateMaxNodeDelegatorLimit() external {
        vm.startPrank(admin);
        lrtDepositPool.updateMaxNodeDelegatorLimit(10);
        vm.stopPrank();

        assertEq(lrtDepositPool.maxNodeDelegatorLimit(), 10, "Max node delegator count is not set");
    }
}

contract LRTDepositPoolSetMinAmountToDeposit is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.setMinAmountToDeposit(1 ether);

        vm.stopPrank();
    }

    function test_SetMinAmountToDeposit() external {
        vm.startPrank(admin);
        lrtDepositPool.setMinAmountToDeposit(1 ether);
        vm.stopPrank();

        assertEq(lrtDepositPool.minAmountToDeposit(), 1 ether, "Min amount to deposit is not set");
    }
}

contract LRTDepositPoolPause is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        assertTrue(lrtDepositPool.paused(), "LRTDepositPool is not paused");
    }

    function test_DepositWhenPaused() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(alice);
        lrtDepositPool.depositAsset(address(ethX), 1 ether, 0, referralId);
    }

    function test_WithdrawWhenPaused() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(alice);
        lrtDepositPool.requestWithdrawal(address(ethX), 1 ether, 1.1 ether);
    }

    function test_ClaimWithdrawWhenPaused() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        // Assign an empty withdrawal for unit testing
        IDelegationManager.Withdrawal memory withdrawal;

        vm.expectRevert("Pausable: paused");

        vm.prank(alice);
        lrtDepositPool.claimWithdrawal(withdrawal);
    }

    function test_ClaimWithdrawYnWhenPaused() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        // Assign an empty withdrawal for unit testing
        IDelegationManager.Withdrawal memory withdrawal;

        vm.expectRevert("Pausable: paused");

        vm.prank(alice);
        lrtDepositPool.claimWithdrawalYn(withdrawal);
    }
}

contract LRTDepositPoolUnpause is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.unpause();

        vm.stopPrank();
    }

    function test_Unpause() external {
        vm.prank(manager);
        lrtDepositPool.pause();
        vm.prank(admin);
        lrtDepositPool.unpause();

        assertFalse(lrtDepositPool.paused(), "LRTDepositPool is not unpaused");
    }
}

contract LRTDepositPoolWithdrawAsset is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);

        // add mockStrategy to LRTConfig
        uint256 mockUserUnderlyingViewBalance = 10 ether;
        MockStrategy ethXMockStrategy = new MockStrategy(address(ethX), mockUserUnderlyingViewBalance, 1.02e18);
        MockStrategy stETHMockStrategy = new MockStrategy(address(stETH), mockUserUnderlyingViewBalance, 1.005e18);

        lrtConfig.updateAssetStrategy(address(ethX), address(ethXMockStrategy));
        lrtConfig.updateAssetStrategy(address(stETH), address(stETHMockStrategy));

        // add burner role to lrtDepositPool so it can burn primeETH
        lrtConfig.grantRole(LRTConstants.BURNER_ROLE, address(lrtDepositPool));

        vm.stopPrank();

        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 2 ether);
        lrtDepositPool.depositAsset(ethXAddress, 2 ether, 0, referralId);
        vm.stopPrank();
    }

    function test_RevertWhenWithdrawAmountIsZero() external {
        vm.expectRevert(ILRTDepositPool.ZeroAmount.selector);
        lrtDepositPool.requestWithdrawal(ethXAddress, 0, 0);
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAsset = makeAddr("randomAsset");

        vm.expectRevert(ILRTDepositPool.NotWithdrawAsset.selector);
        lrtDepositPool.requestWithdrawal(randomAsset, 1 ether, 1 ether);
    }

    function test_WithdrawAsset() external {
        // alice balance of prETH before deposit
        uint256 aliceBalanceBefore = preth.balanceOf(address(alice));

        uint256 withdrawAmount = 1 ether;
        uint256 maxPrimeETHToBurn = lrtDepositPool.getMintAmount(ethXAddress, withdrawAmount) + 1;

        vm.prank(alice);
        lrtDepositPool.requestWithdrawal(ethXAddress, withdrawAmount, maxPrimeETHToBurn);

        // alice balance of prETH after deposit
        uint256 aliceBalanceAfter = preth.balanceOf(address(alice));

        assertLt(aliceBalanceAfter, aliceBalanceBefore, "Alice balance is not set");
    }

    function test_FuzzWithdrawAsset(uint256 withdrawAmount) external {
        // uint256 stETHDepositLimit = lrtConfig.depositLimitByAsset(address(stETH));
        vm.assume(withdrawAmount > 0 && withdrawAmount < 2 ether);

        uint256 maxPrimeETHToBurn = lrtDepositPool.getMintAmount(ethXAddress, withdrawAmount) + 1;

        vm.prank(alice);
        lrtDepositPool.requestWithdrawal(ethXAddress, withdrawAmount, maxPrimeETHToBurn);
    }

    function test_ClaimWithdrawAsset() external {
        // Assign an empty withdrawal for unit testing
        IDelegationManager.Withdrawal memory withdrawal;

        vm.prank(alice);
        lrtDepositPool.claimWithdrawal(withdrawal);
    }

    function test_ClaimWithdrawAssetYn() external {
        // Assign an empty withdrawal for unit testing
        IDelegationManager.Withdrawal memory withdrawal;

        vm.prank(alice);
        lrtDepositPool.claimWithdrawalYn(withdrawal);
    }
}
