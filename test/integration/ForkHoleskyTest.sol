// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IDelegationManager } from "contracts/eigen/interfaces/IDelegationManager.sol";
import { IStrategy } from "contracts/eigen/interfaces/IStrategy.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";
import { IWETH } from "contracts/interfaces/IWETH.sol";
import { LRTDepositPool, ILRTDepositPool, LRTConstants } from "contracts/LRTDepositPool.sol";
import { LRTConfig, ILRTConfig } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator, INodeDelegator, ValidatorStakeData } from "contracts/NodeDelegator.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";
import { AddressesHolesky } from "contracts/utils/Addresses.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";

contract ForkHoleskyTestBase is Test {
    uint256 public fork;

    LRTDepositPool public constant lrtDepositPool = LRTDepositPool(payable(AddressesHolesky.LRT_DEPOSIT_POOL));
    LRTConfig public constant lrtConfig = LRTConfig(AddressesHolesky.LRT_CONFIG);
    PrimeStakedETH public constant primeETH = PrimeStakedETH(AddressesHolesky.PRIME_STAKED_ETH);
    LRTOracle public constant lrtOracle = LRTOracle(AddressesHolesky.LRT_ORACLE);
    NodeDelegator public constant nodeDelegator1 = NodeDelegator(payable(AddressesHolesky.NODE_DELEGATOR));

    address public constant admin = AddressesHolesky.ADMIN_ROLE;
    address public constant manager = AddressesHolesky.MANAGER_ROLE;
    address public constant deployer = AddressesHolesky.DEPLOYER;

    address public constant stETHAddress = AddressesHolesky.STETH_TOKEN;
    address public constant rEthAddress = AddressesHolesky.RETH_TOKEN;

    address public constant stWhale = AddressesHolesky.STETH_WHALE;
    address public constant rWhale = AddressesHolesky.RETH_WHALE;

    address public constant stEthOracle = AddressesHolesky.CHAINLINK_ORACLE_PROXY;
    address public constant rEthPriceOracle = AddressesHolesky.CHAINLINK_ORACLE_PROXY;

    uint256 public constant minPrimeAmount = 0;
    string public constant referralId = "ref id";
    uint256 public constant amountToTransfer = 1 ether;

    uint256 indexOfNodeDelegator;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Zap(address indexed minter, address indexed asset, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);
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
        fork = vm.createSelectFork(url);

        vm.startPrank(stWhale);
        ERC20(stETHAddress).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(stETHAddress, amountToTransfer, minPrimeAmount, referralId);
        vm.stopPrank();

        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (nodeDelegatorArray[i] == address(nodeDelegator1)) {
                indexOfNodeDelegator = i;
                break;
            }
        }

        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, stETHAddress, amountToTransfer);
    }

    function deposit(address asset, address whale, uint256 depositAmount) internal {
        vm.startPrank(whale);

        IERC20(asset).approve(address(lrtDepositPool), depositAmount);
        lrtDepositPool.depositAsset(asset, depositAmount, depositAmount * 99 / 100, referralId);

        vm.stopPrank();
    }
}

contract ForkHoleskyTestLST is ForkHoleskyTestBase {
    function test_LRTDepositPoolSetup() public {
        assertEq(address(lrtConfig), address(lrtDepositPool.lrtConfig()));
        assertEq(address(nodeDelegator1), address(lrtDepositPool.nodeDelegatorQueue(0)));
    }

    function test_LRTDepositPoolIsAlreadyInitialized() public {
        // attempt to initialize LRTDepositPool again reverts
        vm.expectRevert("Initializable: contract is already initialized");
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenDepositAmountIsZeroForDepositAsset() external {
        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);

        lrtDepositPool.depositAsset(rEthAddress, 0, minPrimeAmount, referralId);
    }

    function test_RevertWhenAssetIsNotSupportedForDepositAsset() external {
        address randomAsset = makeAddr("randomAsset");

        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        lrtDepositPool.depositAsset(randomAsset, 1 ether, minPrimeAmount, referralId);
    }

    function test_DepositAssetSTETHWorksWhenUsingTheCorrectConditions() external {
        if (block.chainid == 1) {
            // skip test on mainnet
            console.log("Skipping test as STETH has reached deposit limit pm mainnet");
            vm.skip(true);
        }

        uint256 amountToDeposit = 2 ether;

        // stWhale balance of prETH before deposit
        uint256 stWhaleBalanceBefore = primeETH.balanceOf(stWhale);
        // total asset deposits before deposit for stETH
        uint256 totalAssetDepositsBefore = lrtDepositPool.getTotalAssetDeposits(stETHAddress);
        // balance of lrtDepositPool before deposit
        uint256 lrtDepositPoolBalanceBefore = ERC20(stETHAddress).balanceOf(address(lrtDepositPool));

        uint256 whaleStETHBalBefore = ERC20(stETHAddress).balanceOf(address(stWhale));
        vm.startPrank(stWhale);
        ERC20(stETHAddress).approve(address(lrtDepositPool), amountToDeposit);
        lrtDepositPool.depositAsset(stETHAddress, amountToDeposit, minPrimeAmount, referralId);
        vm.stopPrank();
        uint256 whaleStETHBalAfter = ERC20(stETHAddress).balanceOf(address(stWhale));

        console.log("whale stETH amount transfer:", whaleStETHBalBefore - whaleStETHBalAfter);

        // stWhale balance of prETH after deposit
        uint256 stWhaleBalanceAfter = primeETH.balanceOf(address(stWhale));

        assertApproxEqAbs(
            lrtDepositPool.getTotalAssetDeposits(stETHAddress),
            totalAssetDepositsBefore + amountToDeposit,
            20,
            "Total asset deposits check is incorrect"
        );
        assertApproxEqAbs(
            ERC20(stETHAddress).balanceOf(address(lrtDepositPool)),
            lrtDepositPoolBalanceBefore + amountToDeposit,
            20,
            "lrtDepositPool balance is not set"
        );
        assertGt(stWhaleBalanceAfter, stWhaleBalanceBefore, "Alice balance is not set");
    }

    function test_DepositAssetRETHWorksWhenUsingTheCorrectConditions() external {
        uint256 amountToDeposit = 2 ether;

        // rETH whale balance of prETH before deposit
        uint256 rEthWhaleBalanceBefore = primeETH.balanceOf(rWhale);
        // total asset deposits before deposit for rETH
        uint256 totalAssetDepositsBefore = lrtDepositPool.getTotalAssetDeposits(rEthAddress);
        // balance of lrtDepositPool before deposit
        uint256 lrtDepositPoolBalanceBefore = ERC20(rEthAddress).balanceOf(address(lrtDepositPool));

        uint256 whaleBalBefore = ERC20(rEthAddress).balanceOf(address(rWhale));
        vm.startPrank(rWhale);
        ERC20(rEthAddress).approve(address(lrtDepositPool), amountToDeposit);
        lrtDepositPool.depositAsset(rEthAddress, amountToDeposit, minPrimeAmount, referralId);
        vm.stopPrank();
        uint256 whaleBalAfter = ERC20(rEthAddress).balanceOf(address(rWhale));

        console.log("whale amount transfer:", whaleBalBefore - whaleBalAfter);

        // rETH whale balance of prETH after deposit
        uint256 rEthWhaleBalanceAfter = primeETH.balanceOf(address(rWhale));

        assertEq(
            lrtDepositPool.getTotalAssetDeposits(rEthAddress),
            totalAssetDepositsBefore + amountToDeposit,
            "Total asset deposits check is incorrect"
        );
        assertEq(
            ERC20(rEthAddress).balanceOf(address(lrtDepositPool)),
            lrtDepositPoolBalanceBefore + amountToDeposit,
            "lrtDepositPool balance is not set"
        );
        assertGt(rEthWhaleBalanceAfter, rEthWhaleBalanceBefore, "Alice balance is not set");
    }

    function test_GetCurrentAssetLimitAfterAssetIsDepositedInLRTDepositPool() external {
        if (block.chainid == 1) {
            // skip test on mainnet
            console.log("Skipping test as STETH has reached deposit limit pm mainnet");
            vm.skip(true);
        }

        uint256 depositAmount = 3 ether;

        uint256 stETHDepositLimitBefore = lrtDepositPool.getAssetCurrentLimit(stETHAddress);

        vm.startPrank(stWhale);
        ERC20(stETHAddress).approve(address(lrtDepositPool), depositAmount);
        lrtDepositPool.depositAsset(stETHAddress, depositAmount, minPrimeAmount, referralId);
        vm.stopPrank();

        uint256 stETHDepositLimitAfter = lrtDepositPool.getAssetCurrentLimit(stETHAddress);

        assertGt(stETHDepositLimitBefore, stETHDepositLimitAfter, "Deposit limit is not set");
    }

    function test_RevertWhenCallingAddNodeDelegatorByANonLRTAdmin() external {
        address randomAddress = makeAddr("randomAddress");

        address[] memory addNodeDelegatorArray = new address[](1);
        addNodeDelegatorArray[0] = randomAddress;

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.addNodeDelegatorContractToQueue(addNodeDelegatorArray);
    }

    function test_IsAbleToAddNodeDelegatorByLRTAdmin() external {
        address randomAddress = makeAddr("randomAddress");

        address[] memory addNodeDelegatorArray = new address[](1);
        addNodeDelegatorArray[0] = randomAddress;

        vm.prank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(addNodeDelegatorArray);

        // find index of newly added nodeDelegator
        uint256 indexOfNodeDelegator_;
        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (nodeDelegatorArray[i] == randomAddress) {
                indexOfNodeDelegator_ = i;
                break;
            }
        }

        // 5 nodeDelegators were already added in contract at the time of deployment
        assertEq(lrtDepositPool.nodeDelegatorQueue(indexOfNodeDelegator_), randomAddress, "Node delegator is not added");
    }

    function test_RevertWhenCallingTransferAssetToNodeDelegatorWhenNotCalledByOperator() external {
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        indexOfNodeDelegator = 0;
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, stETHAddress, 1 ether);
    }

    function test_TransferAssetSTETHToNodeDelegatorWhenCalledbyManager() external {
        if (block.chainid == 1) {
            // skip test on mainnet
            console.log("Skipping test as STETH has reached deposit limit pm mainnet");
            vm.skip(true);
        }

        uint256 lrtDepositPoolBalanceBefore = ERC20(stETHAddress).balanceOf(address(lrtDepositPool));

        vm.startPrank(stWhale);
        ERC20(stETHAddress).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(stETHAddress, amountToTransfer, minPrimeAmount, referralId);
        vm.stopPrank();

        assertApproxEqAbs(
            ERC20(stETHAddress).balanceOf(address(lrtDepositPool)),
            lrtDepositPoolBalanceBefore + amountToTransfer,
            2,
            "lrtDepositPool balance is not set"
        );

        uint256 getTotalAssetDepositsBeforeDeposit = lrtDepositPool.getTotalAssetDeposits(stETHAddress);

        uint256 nodeDelegator1BalanceBefore = ERC20(stETHAddress).balanceOf(address(nodeDelegator1));

        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, stETHAddress, amountToTransfer);

        uint256 nodeDelegator1BalanceAfter = ERC20(stETHAddress).balanceOf(address(nodeDelegator1));

        assertApproxEqAbs(
            lrtDepositPool.getTotalAssetDeposits(stETHAddress),
            getTotalAssetDepositsBeforeDeposit,
            2,
            "Total asset deposits has not changed when transfering asset from deposit pool to node delegator"
        );

        // assert nodeDelegator1 balance before + 1 ether is equal to nodeDelegator1 balance after
        assertApproxEqAbs(
            nodeDelegator1BalanceAfter,
            nodeDelegator1BalanceBefore + amountToTransfer,
            2,
            "node delegator 1 balance before is different from node delegator 1 balance after"
        );
    }

    function test_TransferAssetRETHToNodeDelegatorWhenCalledbyManager() external {
        uint256 lrtDepositPoolBalanceBefore = ERC20(rEthAddress).balanceOf(address(lrtDepositPool));

        vm.startPrank(rWhale);
        ERC20(rEthAddress).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(rEthAddress, amountToTransfer, minPrimeAmount, referralId);
        vm.stopPrank();

        assertEq(
            ERC20(rEthAddress).balanceOf(address(lrtDepositPool)),
            lrtDepositPoolBalanceBefore + amountToTransfer,
            "lrtDepositPool balance is not set"
        );

        uint256 _indexOfNodeDelegator;
        // find index of nodeDelegator1
        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (nodeDelegatorArray[i] == address(nodeDelegator1)) {
                _indexOfNodeDelegator = i;
                break;
            }
        }

        uint256 getTotalAssetDepositsBeforeDeposit = lrtDepositPool.getTotalAssetDeposits(rEthAddress);

        uint256 nodeDelegator1BalanceBefore = ERC20(rEthAddress).balanceOf(address(nodeDelegator1));

        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(_indexOfNodeDelegator, rEthAddress, amountToTransfer);

        uint256 nodeDelegator1BalanceAfter = ERC20(rEthAddress).balanceOf(address(nodeDelegator1));

        assertEq(
            lrtDepositPool.getTotalAssetDeposits(rEthAddress),
            getTotalAssetDepositsBeforeDeposit,
            "Total asset deposits has not changed when transfering asset from deposit pool to node delegator"
        );

        // assert nodeDelegator1 balance before + 1 ether is equal to nodeDelegator1 balance after
        assertEq(
            nodeDelegator1BalanceAfter,
            nodeDelegator1BalanceBefore + amountToTransfer,
            "node delegator 1 balance before is different from node delegator 1 balance after"
        );
    }

    function test_RevertUpdateMaxNodeDelegatorLimitWhenNotCalledByLRTConfigAdmin() external {
        vm.prank(stWhale);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.updateMaxNodeDelegatorLimit(10);
    }

    function test_UpdateMaxNodeDelegatorLimitWhenCalledByAdmin() external {
        vm.startPrank(admin);
        lrtDepositPool.updateMaxNodeDelegatorLimit(100);
        vm.stopPrank();

        assertEq(lrtDepositPool.maxNodeDelegatorLimit(), 100, "Max node delegator count is not set");
    }

    function test_RevertPauseWhenNotCalledByLRTConfigManager() external {
        vm.prank(stWhale);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.pause();
    }

    function test_PauseAndUnpauseWhenCalledByManagerAndAdmin() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        assertTrue(lrtDepositPool.paused(), "LRTDepositPool is not paused");

        vm.prank(stWhale); // cannot unpause
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.unpause();

        vm.prank(admin);
        lrtDepositPool.unpause();

        assertFalse(lrtDepositPool.paused(), "LRTDepositPool is not unpaused");
    }

    function test_LRTConfigSetup() public {
        // privileged roles
        assertTrue(lrtConfig.hasRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin), "admin role");
        assertTrue(lrtConfig.hasRole(LRTConstants.MANAGER, manager), "manager role");

        // tokens
        assertEq(stETHAddress, lrtConfig.getLSTToken(LRTConstants.ST_ETH_TOKEN), "stETH token");
        // Is ETHX_TOKEN and not R_ETH_TOKEN as the second token is hardcoded in LRTConfig
        assertEq(rEthAddress, lrtConfig.getLSTToken(LRTConstants.ETHX_TOKEN), "rETH token");
        assertEq(address(primeETH), lrtConfig.primeETH(), "primeETH token");

        assertTrue(lrtConfig.isSupportedAsset(stETHAddress));
        assertTrue(lrtConfig.isSupportedAsset(rEthAddress));

        assertEq(AddressesHolesky.STETH_EIGEN_STRATEGY, lrtConfig.assetStrategy(stETHAddress), "Eigen stETH strategy");
        assertEq(AddressesHolesky.RETH_EIGEN_STRATEGY, lrtConfig.assetStrategy(rEthAddress), "Eigen rETH strategy");

        assertEq(AddressesHolesky.EIGEN_STRATEGY_MANAGER, lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER));
        assertEq(address(lrtDepositPool), lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
        assertEq(address(lrtOracle), lrtConfig.getContract(LRTConstants.LRT_ORACLE));
    }

    function test_LRTConfigIsAlreadyInitialized() public {
        // attempt to initialize LRTConfig again reverts
        vm.expectRevert("Initializable: contract is already initialized");
        lrtConfig.initialize(admin, stETHAddress, rEthAddress, address(primeETH));
    }

    function test_RevertWhenCallingAddNewAssetByANonLRTManager() external {
        address randomAssetAddress = makeAddr("randomAssetAddress");
        uint256 randomAssetDepositLimit = 100 ether;
        // Example of error message. Unfortunately vm.expectRevert does not support the result of string casting.
        // string memory errorMessage = string(
        //     abi.encodePacked(
        //         "AccessControl: account ",
        //         Strings.toHexString(address(this)),
        //         " is missing role ",
        //         Strings.toHexString(uint256(LRTConstants.MANAGER), 32)
        //     )
        // );
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xaf290d8680820aad922855f39b306097b20e28774d6c1ad35a20325630c3a02c"
        );

        lrtConfig.addNewSupportedAsset(randomAssetAddress, randomAssetDepositLimit);
    }

    function test_IsAbleToAddNewAssetByManager() external {
        address randomAssetAddress = makeAddr("randomAssetAddress");
        uint256 randomAssetDepositLimit = 100 ether;

        vm.prank(manager);
        lrtConfig.addNewSupportedAsset(randomAssetAddress, randomAssetDepositLimit);

        assertEq(lrtConfig.depositLimitByAsset(randomAssetAddress), randomAssetDepositLimit);
    }

    function test_RevertUpdateAssetDepositLimitIfNotManager() external {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xaf290d8680820aad922855f39b306097b20e28774d6c1ad35a20325630c3a02c"
        );

        lrtConfig.updateAssetDepositLimit(stETHAddress, 1000);
    }

    function test_UpdateAssetDepositLimit() external {
        uint256 depositLimit = 1000;

        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(stETHAddress, depositLimit);

        assertEq(lrtConfig.depositLimitByAsset(stETHAddress), depositLimit);
    }

    function test_RevertUpdateAssetStrategyIfNotAdmin() external {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        lrtConfig.updateAssetStrategy(stETHAddress, address(this));
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomToken = makeAddr("randomToken");
        address strategy = makeAddr("strategy");

        vm.startPrank(admin);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        lrtConfig.updateAssetStrategy(address(randomToken), strategy);
        vm.stopPrank();
    }

    function test_RevertWhenStrategyAddressIsZero() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        lrtConfig.updateAssetStrategy(stETHAddress, address(0));
        vm.stopPrank();
    }

    function test_RevertWhenSameStrategyWasAlreadyAddedBeforeForAsset() external {
        address strategy = lrtConfig.assetStrategy(stETHAddress);
        vm.startPrank(admin);
        // revert when same strategy was already added before for asset
        vm.expectRevert(ILRTConfig.ValueAlreadyInUse.selector);
        lrtConfig.updateAssetStrategy(stETHAddress, strategy);
        vm.stopPrank();
    }

    function test_UpdateAssetStrategy() external {
        address strategy = makeAddr("strategy");

        vm.prank(admin);
        lrtConfig.updateAssetStrategy(rEthAddress, strategy);

        assertEq(lrtConfig.assetStrategy(rEthAddress), strategy);
    }

    function test_RevertSetPrimeETHIfNotAdmin() external {
        address newPRETH = makeAddr("newPRETH");

        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        lrtConfig.setPrimeETH(newPRETH);
    }

    function test_RevertSetPrimeETHIfPrimeETHAddressIsZero() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        lrtConfig.setPrimeETH(address(0));
        vm.stopPrank();
    }

    function test_SetPrimeETH() external {
        address newPrimeETH = makeAddr("newPrimeETH");
        vm.prank(admin);
        lrtConfig.setPrimeETH(newPrimeETH);

        assertEq(lrtConfig.primeETH(), newPrimeETH);
    }

    function test_RevertSetTokenIfNotAdmin() external {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        lrtConfig.setToken(LRTConstants.ST_ETH_TOKEN, address(this));
    }

    function test_RevertSetTokenIfTokenAddressIsZero() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        lrtConfig.setToken(LRTConstants.ST_ETH_TOKEN, address(0));
        vm.stopPrank();
    }

    function test_RevertSetTokenIfTokenAlreadySet() external {
        address newToken = makeAddr("newToken");
        vm.startPrank(admin);
        lrtConfig.setToken(LRTConstants.ST_ETH_TOKEN, newToken);

        // revert when same token was already set before
        vm.expectRevert(ILRTConfig.ValueAlreadyInUse.selector);
        lrtConfig.setToken(LRTConstants.ST_ETH_TOKEN, newToken);
        vm.stopPrank();
    }

    function test_SetToken() external {
        address newToken = makeAddr("newToken");

        vm.prank(admin);
        lrtConfig.setToken(LRTConstants.ST_ETH_TOKEN, newToken);

        assertEq(lrtConfig.tokenMap(LRTConstants.ST_ETH_TOKEN), newToken);
    }

    function test_RevertSetContractIfNotAdmin() external {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(this));
    }

    function test_RevertSetContractIfContractAddressIsZero() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(0));
        vm.stopPrank();
    }

    function test_RevertSetContractIfContractAlreadySet() external {
        address newContract = makeAddr("newContract");
        vm.startPrank(admin);
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, newContract);

        // revert when same contract was already set before
        vm.expectRevert(ILRTConfig.ValueAlreadyInUse.selector);
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, newContract);
        vm.stopPrank();
    }

    function test_SetContract() external {
        address newContract = makeAddr("newContract");

        vm.prank(admin);
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, newContract);

        assertEq(lrtConfig.contractMap(LRTConstants.LRT_ORACLE), newContract);
    }

    function test_LRTOracleSetup() public {
        assertLt(lrtOracle.getAssetPrice(rEthAddress), 1.2 ether);
        assertGt(lrtOracle.getAssetPrice(rEthAddress) + 1, 1 ether);

        assertLt(lrtOracle.getAssetPrice(stETHAddress), 1.2 ether);
        assertGt(lrtOracle.getAssetPrice(stETHAddress), 0.9 ether);

        assertEq(lrtOracle.assetPriceOracle(stETHAddress), stEthOracle, "stETH Oracle address");
        assertEq(lrtOracle.assetPriceOracle(rEthAddress), rEthPriceOracle, "rETH Oracle address");
    }

    function test_LRTOracleIsAlreadyInitialized() public {
        // attempt to initialize LRTOracle again reverts
        vm.expectRevert("Initializable: contract is already initialized");
        lrtOracle.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallingUpdatePriceOracleForByANonLRTAdmin() external {
        address randomAssetAddress = makeAddr("randomAssetAddress");
        address randomPriceOracleAddress = makeAddr("randomPriceOracleAddress");

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtOracle.updatePriceOracleFor(randomAssetAddress, randomPriceOracleAddress);
    }

    function test_IsAbleToUpdatePriceOracleForAssetByLRTManager() external {
        address randomPriceOracleAddress = makeAddr("randomPriceOracleAddress");

        vm.prank(manager);
        lrtOracle.updatePriceOracleFor(stETHAddress, randomPriceOracleAddress);

        assertEq(lrtOracle.assetPriceOracle(stETHAddress), randomPriceOracleAddress);
    }

    function test_PrimeETHSetup() public {
        // check if lrtDepositPool has MINTER role
        assertTrue(lrtConfig.hasRole(LRTConstants.MINTER_ROLE, address(lrtDepositPool)));

        // check if lrtConfig is set in prETH
        assertEq(address(primeETH.lrtConfig()), address(lrtConfig));
    }

    function test_primeEthIsAlreadyInitialized() public {
        // attempt to initialize PrimeStakedETH again reverts
        vm.expectRevert("Initializable: contract is already initialized");
        primeETH.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        primeETH.pause();
    }

    function test_RevertWhenContractIsAlreadyPaused() external {
        vm.startPrank(manager);
        primeETH.pause();

        vm.expectRevert("Pausable: paused");
        primeETH.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.startPrank(manager);
        primeETH.pause();

        vm.stopPrank();

        assertTrue(primeETH.paused(), "Contract is not paused");
    }

    function test_Unpause() external {
        vm.prank(manager);
        primeETH.pause();

        assertTrue(primeETH.paused(), "Contract is not paused");

        vm.prank(admin);
        primeETH.unpause();

        assertFalse(primeETH.paused(), "Contract is not unpaused");
    }

    function test_RevertWhenCallingUpdateLRTConfigAndCallerIsNotLRTAdmin() external {
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        primeETH.updateLRTConfig(address(lrtConfig));
    }

    function test_RevertWhenCallingUpdateLRTConfigAndLRTConfigIsZeroAddress() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        primeETH.updateLRTConfig(address(0));
        vm.stopPrank();
    }

    function test_UpdateLRTConfigWhenCallingUpdateLRTConfig() external {
        address newLRTConfigAddress = makeAddr("MockNewLRTConfig");
        ILRTConfig newLRTConfig = ILRTConfig(newLRTConfigAddress);

        vm.prank(admin);
        primeETH.updateLRTConfig(address(newLRTConfig));

        assertEq(address(newLRTConfig), address(primeETH.lrtConfig()), "LRT config address is not set");
    }

    function test_NodeDelegatorIsAlreadyInitialized() public {
        // attempt to initialize NodeDelegator again reverts
        vm.expectRevert("Initializable: contract is already initialized");
        nodeDelegator1.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManagerNodeDelegator() external {
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDelegator1.pause();
    }

    function test_RevertWhenContractIsAlreadyPausedNodeDelegator() external {
        vm.startPrank(manager);
        nodeDelegator1.pause();

        vm.expectRevert("Pausable: paused");
        nodeDelegator1.pause();

        vm.stopPrank();
    }

    function test_PauseNodeDelegator() external {
        vm.startPrank(manager);
        nodeDelegator1.pause();

        vm.stopPrank();

        assertTrue(nodeDelegator1.paused(), "Contract is not paused");
    }

    function test_UnpauseNodeDelegator() external {
        vm.prank(manager);
        nodeDelegator1.pause();

        assertTrue(nodeDelegator1.paused(), "Contract is not paused");

        vm.prank(admin);
        nodeDelegator1.unpause();

        assertFalse(nodeDelegator1.paused(), "Contract is not unpaused");
    }

    function test_RevertWhenCallingMaxApproveToEigenStrategyManagerByCallerIsNotLRTManager() external {
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDelegator1.maxApproveToEigenStrategyManager(stETHAddress);
    }

    function test_RevertWhenAssetIsNotSupportedInMaxApproveToEigenStrategyFunction() external {
        address randomAddress = address(0x123);
        vm.prank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDelegator1.maxApproveToEigenStrategyManager(randomAddress);
    }

    function test_MaxApproveToEigenStrategyManager() external {
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        vm.prank(manager);
        nodeDelegator1.maxApproveToEigenStrategyManager(stETHAddress);

        // check that the nodeDelegator has max approved the eigen strategy manager
        assertEq(
            ERC20(stETHAddress).allowance(address(nodeDelegator1), eigenlayerStrategyManagerAddress), type(uint256).max
        );
    }

    function test_RevertWhenCallingDepositAssetIntoStrategyAndNodeDelegatorIsPaused() external {
        vm.startPrank(manager);
        nodeDelegator1.pause();

        vm.expectRevert("Pausable: paused");
        nodeDelegator1.depositAssetIntoStrategy(stETHAddress);

        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupportedInDepositAssetIntoStrategyFunction() external {
        address randomAddress = address(0x123);
        vm.prank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDelegator1.depositAssetIntoStrategy(randomAddress);
    }

    function test_RevertWhenCallingDepositAssetIntoStrategyAndCallerIsNotOperator() external {
        vm.prank(deployer);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        nodeDelegator1.depositAssetIntoStrategy(stETHAddress);
    }

    function test_DepositAssetIntoStrategyFromNodeDelegator() external {
        if (block.chainid == 1) {
            console.log("Skipping test_DepositAssetIntoStrategyFromNodeDelegator for mainnet");
            vm.skip(true);
        }

        console.log(
            "nodeDel stETH balance before submitting to strategy:",
            ERC20(stETHAddress).balanceOf(address(nodeDelegator1))
        );

        (uint256 assetLyingInDepositPool, uint256 assetLyingInNDCs, uint256 assetStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        console.log("#######");
        console.log("getAssetDistributionData for stETH BEFORE submitting funds to strategy");
        console.log("assetLyingInDepositPool", assetLyingInDepositPool);
        console.log("assetLyingInNDCs", assetLyingInNDCs);
        console.log("assetStakedInEigenLayer", assetStakedInEigenLayer);
        console.log("#######");

        address eigenlayerSTETHStrategyAddress = lrtConfig.assetStrategy(stETHAddress);
        uint256 balanceOfStrategyBefore = ERC20(stETHAddress).balanceOf(eigenlayerSTETHStrategyAddress);
        console.log("balanceOfStrategyBefore", balanceOfStrategyBefore);

        vm.startPrank(manager);
        nodeDelegator1.maxApproveToEigenStrategyManager(stETHAddress);
        nodeDelegator1.depositAssetIntoStrategy(stETHAddress);
        vm.stopPrank();

        uint256 balanceOfStrategyAfter = ERC20(stETHAddress).balanceOf(eigenlayerSTETHStrategyAddress);
        console.log("balanceOfStrategyAfter", balanceOfStrategyAfter);

        console.log("stETH amount submitted to strategy", balanceOfStrategyAfter - balanceOfStrategyBefore);

        (assetLyingInDepositPool, assetLyingInNDCs, assetStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        console.log("#######");
        console.log("getAssetDistributionData for stETH AFTER submitting funds to strategy");
        console.log("assetLyingInDepositPool", assetLyingInDepositPool);
        console.log("assetLyingInNDCs", assetLyingInNDCs);
        console.log("assetStakedInEigenLayer", assetStakedInEigenLayer);

        assertGt(
            balanceOfStrategyAfter,
            balanceOfStrategyBefore,
            "Balance of strategy after is not greater than balance of strategy before tx"
        );
    }
}

contract ForkHoleskyTestLSTWithdrawals is ForkHoleskyTestBase {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(manager);
        nodeDelegator1.maxApproveToEigenStrategyManager(stETHAddress);
        nodeDelegator1.depositAssetIntoStrategy(stETHAddress);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////
    ///                     requestWithdrawal
    ////////////////////////////////////////////////////////////////

    function test_requestWithdrawal() external {
        uint256 primeETHBalanceBefore = primeETH.balanceOf(address(stWhale));
        console.log("Staker's primeETH before: ", primeETHBalanceBefore);

        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        vm.recordLogs();

        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();
        console.log("logs from requestWithdrawal", requestLogs.length);

        // Transfer event from PrimeStakedETH to burn primeETH tokens
        assertEq(requestLogs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(requestLogs[0].topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef);
        assertEq(requestLogs[0].topics[1], bytes32(uint256(uint160(stWhale))));
        assertEq(requestLogs[0].topics[2], bytes32(0)); // zero address
        console.log("primeETH burnt ", abi.decode(requestLogs[0].data, (uint256)));
        uint256 expectPrimeEthBurnt = 0.5976 ether;
        assertEq(requestLogs[0].data, abi.encode(expectPrimeEthBurnt));

        assertEq(
            primeETH.balanceOf(address(stWhale)),
            primeETHBalanceBefore - expectPrimeEthBurnt,
            "stETH whale's primeETH balance should reduce"
        );

        // WithdrawalQueued from EigenLayer's DelegationManager
        assertEq(
            requestLogs[1].topics[0],
            keccak256("WithdrawalQueued(bytes32,(address,address,address,uint256,uint32,address[],uint256[]))"),
            "decoded WithdrawalQueued"
        );
        assertEq(requestLogs[1].topics[0], 0x9009ab153e8014fbfb02f2217f5cde7aa7f9ad734ae85ca3ee3f4ca2fdd499f9);

        // WithdrawalRequested event on the LRTDepositPool contract
        assertEq(
            requestLogs[2].topics[0], keccak256("WithdrawalRequested(address,address,address,uint256,uint256,uint256)")
        );
        assertEq(requestLogs[2].topics[0], 0x92072c627ec1da81f8268b3cfb3c02bbbeedc12c21134faf4457469147619947);

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        assertEq(assetsInDepositPoolAfter, assetsInDepositPoolBefore, "stETH balance in deposit pool should not change");
        assertEq(assetsInNDCsAfter, assetsInNDCsBefore, "stETH balance in NodeDelegators should not change");
        assertApproxEqAbs(
            assetsInEigenLayerAfter,
            assetsInEigenLayerBefore - stEthWithdrawalAmount,
            2,
            "stETH balance in EigenLayer should reduce by withdraw amount with 2 wei tolerance"
        );
    }

    // requestWithdrawal when LRTDepositPool paused
    function test_revertRequestWithdrawalDepositPoolPaused() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        vm.prank(manager);
        lrtDepositPool.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal when NodeDelegator paused
    function test_revertRequestWithdrawalNodeDelegatorPaused() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        vm.prank(manager);
        nodeDelegator1.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal with not enough primeETH
    function test_revertRequestWithdrawalNoPrimeETH() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        // Should fail to withdraw with no primeETH tokens
        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(makeAddr("randomUser"));
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal with zero amount
    function test_revertRequestWithdrawalZeroAmount() external {
        uint256 stEthWithdrawalAmount = 0 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        vm.expectRevert(ILRTDepositPool.ZeroAmount.selector);
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal over max primeETH amount
    function test_revertRequestWithdrawalOverMaxBurn() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.59 ether;

        vm.expectRevert(ILRTDepositPool.MaxBurnAmount.selector);
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal with WETH
    function test_revertRequestWithdrawalWETH() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        vm.expectRevert(ILRTDepositPool.OnlyLSTWithdrawals.selector);
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(AddressesHolesky.WETH_TOKEN, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal with unsupported LST asset
    function test_revertRequestWithdrawalUnsupportedAsset() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;
        uint256 maxPrimeEthAmount = 0.7 ether;

        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(makeAddr("randomAsset"), stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // requestWithdrawal with not enough LST in EigenLayer
    function test_revertRequestWithdrawalStrategyLiquidity() external {
        uint256 stEthWithdrawalAmount = 2 ether;
        uint256 maxPrimeEthAmount = 2 ether;

        // Transfer some rETH to the stETH whale
        vm.prank(rWhale);
        ERC20(rEthAddress).transfer(stWhale, amountToTransfer);

        // deposit more rETH so we have enough PrimeETH to withdraw
        vm.startPrank(stWhale);
        ERC20(rEthAddress).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(rEthAddress, amountToTransfer, minPrimeAmount, referralId);
        vm.stopPrank();

        vm.expectRevert("StrategyManager._removeShares: shareAmount too high");
        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);
    }

    // malicious user calls requestWithdrawal on the NodeDelegator
    function test_revertClaimWithdrawalToNodeDelegator() external {
        uint256 stEthWithdrawalAmount = 0.6 ether;

        address maliciousUser = makeAddr("maliciousUser");

        vm.expectRevert(ILRTConfig.CallerNotLRTDepositPool.selector);
        vm.prank(maliciousUser);
        nodeDelegator1.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maliciousUser);
    }

    ////////////////////////////////////////////////////////////////
    ///                requestInternalWithdrawal
    ////////////////////////////////////////////////////////////////

    function test_requestInternalWithdrawalPartial() external {
        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        uint256 stEthWithdrawalAmount = 0.9 ether;

        vm.recordLogs();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, stEthWithdrawalAmount);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // WithdrawalQueued from EigenLayer's DelegationManager
        assertEq(
            requestLogs[0].topics[0],
            keccak256("WithdrawalQueued(bytes32,(address,address,address,uint256,uint32,address[],uint256[]))"),
            "decoded WithdrawalQueued"
        );
        assertEq(requestLogs[0].topics[0], 0x9009ab153e8014fbfb02f2217f5cde7aa7f9ad734ae85ca3ee3f4ca2fdd499f9);

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        assertEq(assetsInDepositPoolAfter, assetsInDepositPoolBefore, "stETH balance in deposit pool should not change");
        assertEq(assetsInNDCsAfter, assetsInNDCsBefore, "stETH balance in NodeDelegators should not change");
        assertApproxEqAbs(
            assetsInEigenLayerAfter, assetsInEigenLayerBefore, 2, "stETH balance in EigenLayer should not change"
        );
    }

    function test_requestInternalWithdrawalFull() external {
        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        // Withdraw all the NodeDelegator's shares from the strategy
        uint256 shares = IStrategy(AddressesHolesky.STETH_EIGEN_STRATEGY).shares(address(nodeDelegator1));

        vm.recordLogs();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, shares);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // WithdrawalQueued from EigenLayer's DelegationManager
        assertEq(
            requestLogs[0].topics[0],
            keccak256("WithdrawalQueued(bytes32,(address,address,address,uint256,uint32,address[],uint256[]))"),
            "decoded WithdrawalQueued"
        );
        assertEq(requestLogs[0].topics[0], 0x9009ab153e8014fbfb02f2217f5cde7aa7f9ad734ae85ca3ee3f4ca2fdd499f9);

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        assertEq(assetsInDepositPoolAfter, assetsInDepositPoolBefore, "stETH balance in deposit pool should not change");
        assertEq(assetsInNDCsAfter, assetsInNDCsBefore, "stETH balance in NodeDelegators should not change");
        assertApproxEqAbs(
            assetsInEigenLayerAfter, assetsInEigenLayerBefore, 2, "stETH balance in EigenLayer should not change"
        );

        assertEq(
            IStrategy(AddressesHolesky.STETH_EIGEN_STRATEGY).shares(address(nodeDelegator1)),
            0,
            "NodeDelegator has no more shares in strategy"
        );
    }

    // requestInternalWithdrawal when NodeDelegator paused
    function test_requestInternalWithdrawalWhenPaused() external {
        uint256 shares = 1 ether;

        vm.prank(manager);
        nodeDelegator1.pause();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, shares);
    }

    // malicious user calls requestInternalWithdrawal on the NodeDelegator
    function test_revertRequestInternalWithdrawalNotOperator() external {
        uint256 shares = 1 ether;

        address maliciousUser = makeAddr("maliciousUser");

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        vm.prank(maliciousUser);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, shares);
    }

    // requestInternalWithdrawal with zero shares
    function test_requestInternalWithdrawalWithZeroShares() external {
        uint256 shares = 0;

        vm.expectRevert("StrategyManager._removeShares: shareAmount should not be zero!");
        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, shares);
    }

    // requestInternalWithdrawal with invalid strategy
    function test_requestInternalWithdrawalWithInvalidStrategy() external {
        uint256 shares = 0.01 ether;

        vm.expectRevert("StrategyManager._removeShares: shareAmount too high");
        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(makeAddr("invalidStrategy"), shares);
    }

    // requestInternalWithdrawal with native staking strategy
    function test_requestInternalWithdrawalWithNativeETHStrategy() external {
        uint256 shares = 0.01 ether;

        vm.expectRevert("EigenPodManager.removeShares: cannot result in pod owner having negative shares");
        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0, shares);
    }

    ////////////////////////////////////////////////////////////////
    ///                  claimInternalWithdrawal
    ////////////////////////////////////////////////////////////////

    function test_claimInternalWithdrawalPartial() external {
        uint256 stEthShares = 0.8 ether;
        uint256 stEthExpected = IStrategy(AddressesHolesky.STETH_EIGEN_STRATEGY).sharesToUnderlying(stEthShares);

        vm.recordLogs();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, stEthShares);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawalRoot and withdrawal event data
        (bytes32 withdrawalRoot, IDelegationManager.Withdrawal memory withdrawal) =
            abi.decode(requestLogs[0].data, (bytes32, IDelegationManager.Withdrawal));

        // Move forward 10 blocks
        // DelegationManager.minWithdrawalDelayBlocks on Holesky is 10
        vm.roll(block.number + 11);

        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        vm.recordLogs();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.claimInternalWithdrawal(stETHAddress, withdrawal);

        requestLogs = vm.getRecordedLogs();
        console.log("logs from claimInternalWithdrawal", requestLogs.length);

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        assertApproxEqAbs(
            assetsInDepositPoolAfter,
            assetsInDepositPoolBefore + stEthExpected,
            2,
            "stETH balance in deposit pool should not change with 2 wei variance"
        );
        assertApproxEqAbs(
            assetsInNDCsAfter,
            assetsInNDCsBefore,
            2,
            "stETH balance in NodeDelegators should not change with 2 wei variance"
        );
        assertApproxEqAbs(
            assetsInEigenLayerAfter,
            assetsInEigenLayerBefore - stEthExpected,
            2,
            "stETH balance in EigenLayer should not change with 2 wei variance"
        );
    }
}

contract ForkHoleskyTestLSTWithdrawalsClaim is ForkHoleskyTestBase {
    uint256 public constant stEthWithdrawalAmount = 0.6 ether;
    uint256 public constant maxPrimeEthAmount = 0.7 ether;

    IDelegationManager.Withdrawal withdrawal;

    function setUp() public override {
        super.setUp();

        vm.startPrank(manager);
        nodeDelegator1.maxApproveToEigenStrategyManager(stETHAddress);
        nodeDelegator1.depositAssetIntoStrategy(stETHAddress);
        vm.stopPrank();

        vm.recordLogs();

        vm.prank(stWhale);
        lrtDepositPool.requestWithdrawal(stETHAddress, stEthWithdrawalAmount, maxPrimeEthAmount);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawalRoot and withdrawal event data
        bytes32 withdrawalRoot;
        (withdrawalRoot, withdrawal) = abi.decode(requestLogs[1].data, (bytes32, IDelegationManager.Withdrawal));

        // Move forward 10 blocks
        // DelegationManager.minWithdrawalDelayBlocks on Holesky is 10
        vm.roll(block.number + 11);
    }

    ////////////////////////////////////////////////////////////////
    ///                     claimWithdrawal
    ////////////////////////////////////////////////////////////////

    function test_claimWithdrawal() external {
        uint256 stETHBalanceBefore = IERC20(stETHAddress).balanceOf(address(stWhale));
        uint256 primeETHBalanceBefore = primeETH.balanceOf(address(stWhale));
        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        vm.recordLogs();

        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();
        console.log("logs from claimWithdrawal", requestLogs.length);

        // WithdrawalClaimed event from LRTDepositPool
        assertEq(requestLogs[5].topics[0], keccak256("WithdrawalClaimed(address,address,uint256)"));
        // assertEq(requestLogs[0].topics[0], 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef);
        assertEq(requestLogs[5].topics[1], bytes32(uint256(uint160(stWhale))));
        assertEq(requestLogs[5].topics[2], bytes32(uint256(uint160(stETHAddress))));
        uint256 actualAssets = abi.decode(requestLogs[5].data, (uint256));
        assertApproxEqAbs(actualAssets, stEthWithdrawalAmount, 2, "WithdrawalClaimed.assets with 2 wei tolerance");

        assertApproxEqAbs(
            IERC20(stETHAddress).balanceOf(address(stWhale)),
            stETHBalanceBefore + stEthWithdrawalAmount,
            3,
            "Whale's stETH balance should increase with 3 wei tolerance"
        );
        // This currently fails as wei is lost on the stETH transfers
        // assertGe(
        //     IERC20(stETHAddress).balanceOf(address(stWhale)),
        //     stETHBalanceBefore + stEthWithdrawalAmount,
        //     "Whale's stETH balance should increase by at least the requested amount"
        // );
        assertEq(
            primeETH.balanceOf(address(stWhale)),
            primeETHBalanceBefore,
            "stETH whale's primeETH balance should not change as it was burnt in requestWithdrawal"
        );

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        assertEq(assetsInDepositPoolAfter, assetsInDepositPoolBefore, "stETH balance in deposit pool should not change");
        assertApproxEqAbs(
            assetsInNDCsAfter,
            assetsInNDCsBefore,
            2,
            "stETH balance in NodeDelegator should not change with tolerance of 2 wei"
        );
        assertEq(assetsInEigenLayerAfter, assetsInEigenLayerBefore, "stETH balance in EigenLayer should not change");
    }

    // requestWithdrawal when LRTDepositPool paused
    function test_revertClaimWithdrawalDepositPoolPaused() external {
        vm.prank(manager);
        lrtDepositPool.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);
    }

    // requestWithdrawal when NodeDelegator paused
    function test_revertClaimWithdrawalNodeDelegatorPaused() external {
        vm.prank(manager);
        nodeDelegator1.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);
    }

    // another user claims the withdrawal
    function test_revertClaimWithdrawalNotWithdrawer() external {
        vm.expectRevert(INodeDelegator.StakersWithdrawalNotFound.selector);
        vm.prank(makeAddr("randomUser"));
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);
    }

    // withdrawer tries a second claim
    function test_revertClaimWithdrawalTwice() external {
        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);

        vm.expectRevert("DelegationManager._completeQueuedWithdrawal: action is not in queue");
        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);
    }

    // withdrawer adds extra shares to the withdrawal
    function test_revertClaimWithdrawalChangedShares() external {
        IDelegationManager.Withdrawal memory changedWithdrawal = withdrawal;
        // Add 1 wei to the shares
        changedWithdrawal.shares[0] += 1;

        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, withdrawal);

        vm.expectRevert(INodeDelegator.StakersWithdrawalNotFound.selector);
        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(stETHAddress, changedWithdrawal);
    }

    // another staker calls the NodeDelegator with a staker's withdrawal
    function test_revertClaimWithdrawalToNodeDelegator() external {
        address maliciousUser = makeAddr("maliciousUser");

        vm.expectRevert(ILRTConfig.CallerNotLRTDepositPool.selector);
        vm.prank(maliciousUser);
        nodeDelegator1.claimWithdrawal(stETHAddress, withdrawal, maliciousUser);
    }

    // claimWithdrawal with invalid asset
    function test_revertClaimWithdrawalInvalidAsset() external {
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        vm.prank(stWhale);
        lrtDepositPool.claimWithdrawal(makeAddr("invalidAsset"), withdrawal);
    }
}

contract ForkHoleskyTestInternalLSTWithdrawalsClaim is ForkHoleskyTestBase {
    uint256 shares;
    uint256 assetExpected;
    IDelegationManager.Withdrawal withdrawal;

    function setUp() public override {
        super.setUp();

        vm.startPrank(manager);
        nodeDelegator1.maxApproveToEigenStrategyManager(stETHAddress);
        nodeDelegator1.depositAssetIntoStrategy(stETHAddress);
        vm.stopPrank();

        // Withdraw all the NodeDelegator's shares from the strategy
        shares = IStrategy(AddressesHolesky.STETH_EIGEN_STRATEGY).shares(address(nodeDelegator1));
        assetExpected = IStrategy(AddressesHolesky.STETH_EIGEN_STRATEGY).sharesToUnderlying(shares);

        vm.recordLogs();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.requestInternalWithdrawal(AddressesHolesky.STETH_EIGEN_STRATEGY, shares);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        // decode the withdrawalRoot and withdrawal event data
        bytes32 withdrawalRoot;
        (withdrawalRoot, withdrawal) = abi.decode(requestLogs[0].data, (bytes32, IDelegationManager.Withdrawal));

        // Move forward 10 blocks
        // DelegationManager.minWithdrawalDelayBlocks on Holesky is 10
        vm.roll(block.number + 11);
    }

    function test_claimInternalWithdrawalFull() external {
        (uint256 assetsInDepositPoolBefore, uint256 assetsInNDCsBefore, uint256 assetsInEigenLayerBefore) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);

        vm.recordLogs();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.claimInternalWithdrawal(stETHAddress, withdrawal);

        Vm.Log[] memory requestLogs = vm.getRecordedLogs();

        (uint256 assetsInDepositPoolAfter, uint256 assetsInNDCsAfter, uint256 assetsInEigenLayerAfter) =
            lrtDepositPool.getAssetDistributionData(stETHAddress);
        assertApproxEqAbs(
            assetsInDepositPoolAfter,
            assetsInDepositPoolBefore + assetExpected,
            2,
            "stETH balance in deposit pool should not change with 2 wei variance"
        );
        assertApproxEqAbs(
            assetsInNDCsAfter,
            assetsInNDCsBefore,
            2,
            "stETH balance in NodeDelegators should not change with 2 wei variance"
        );
        assertApproxEqAbs(
            assetsInEigenLayerAfter,
            assetsInEigenLayerBefore - assetExpected,
            2,
            "stETH balance in EigenLayer should not change with 2 wei variance"
        );

        assertEq(
            IStrategy(AddressesHolesky.STETH_EIGEN_STRATEGY).shares(address(nodeDelegator1)),
            0,
            "NodeDelegator has no more shares in strategy"
        );
    }

    // claimInternalWithdrawal when NodeDelegator paused
    function test_claimInternalWithdrawalWhenPaused() external {
        vm.prank(manager);
        nodeDelegator1.pause();

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.claimInternalWithdrawal(stETHAddress, withdrawal);
    }

    // another user claims the internal withdrawal
    function test_revertClaimInternalWithdrawalNotOperator() external {
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);

        vm.prank(makeAddr("randomUser"));
        nodeDelegator1.claimInternalWithdrawal(stETHAddress, withdrawal);
    }

    // Added an extra strategy element to the claimInternalWithdrawal
    function test_revertClaimInternalWithdrawalNotSingleStrategy() external {
        IDelegationManager.Withdrawal memory changedWithdrawal = withdrawal;
        // Add another strategy element
        changedWithdrawal.strategies = new IStrategy[](2);

        vm.expectRevert(INodeDelegator.NotSingleStrategyWithdrawal.selector);

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.claimInternalWithdrawal(stETHAddress, changedWithdrawal);
    }

    // claimWithdrawal with invalid asset
    function test_revertClaimWithdrawalInvalidAsset() external {
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        nodeDelegator1.claimInternalWithdrawal(makeAddr("invalidAsset"), withdrawal);
    }
}

contract ForkHoleskyTestNative is ForkHoleskyTestBase {
    NodeDelegator public nodeDelegator2;
    PrimeZapper public primeZapper;

    uint64[] operatorIds;
    Cluster public cluster;
    // The test SSV validator data is the P2P APIs
    // 1. Call the Create SSV Request API
    // https://docs.p2p.org/reference/ssv-request-create
    // The `withdrawalAddress` is the EigenPod attached to the native staking NodeDelegator.
    // The `feeRecipientAddress` is the native staking NodeDelegator
    // The `ssvOwnerAddress` is the native staking NodeDelegator
    // 2. Call the SSV Request Status API
    // https://docs.p2p.org/reference/ssv-request-status
    // The following data is in the API response paths
    // sharesData: result.encryptedShares.sharesData
    // pubkey: result.depositData.pubkey
    // signature: result.depositData.signature
    // depositDataRoot: result.depositData.depositDataRoot
    // The leading 0x is removed when using hex in Solidity
    bytes internal constant sharesData =
    // solhint-disable-next-line max-line-length
        hex"911a288a6fd6a3ef2ec6596d308bfbd4e98bd4d711f1757f6f70c875d6ce4fe2b4e5c80def263f05168cd09d7e2c60850714a890dfacdc3238711e9f62093510fd94c7731f85afaefd9f6963132848ba6cf7fe3eef2660d1cdc9f9fa7adc2f9496570731994e5771f4d48ceef082cb476c09013319d48e2d8e848984329ab3f9ade70dccf2da8305e4216236d7cb98e08bffbe4721479934eb60d9b6a4c9da9ff2ad2144c2bdad1968426c0732ebc685863d6ca10b7a434572cd5c107ad895c6b8670ec0d3efc622f7e9ef8213dbed5e81d3c56cdb26f2c6c0864093e2325b700b034d8cd846cd4a3b31d979ad5a2cb0a0b16154723143b998e2cf462ebe206c2e804c35828dfff1cde301d0d5b8185553e6197801e619595e7c97cd68491bd1b9ef5fca12bac249e2ab3dc4cc5412e38088e9c3dc9369d80289909583dfec9d3c360105d73f9c49305cdafe1d82eb8123200ad3b4d54308a4e9c957f8e41bca0c5ad2f3d4071a8116f2f58ca0a42d9ed5fc81453dfa29d41b0d05cc19d502e0d3e194e174d2d2ae41662640e3113940c73cfb9595f9b33fd3c7fe5243d10ca493361c5994a9ad76f0040d211dc33fcd1a233ccc5c45ed9bc9d2dda52dc0b9d20726451bb3c2286aed397cb032e2999040e3bc3365b6b9842eb5c06c92828233280c20d6000323c107760465a4658230d93a1e70ab37120d7b232a9456db0b1ccfbd125402b49c2f7617226abeeaf3741cf08698c3e0383e850cf655ec2bb58c3ddb1ac257f13ac5905f9a03f6d3b17b47009519e4a4fbddadefca91d3d3cbe4d24010c95e755f281a3bf147b6e44aa28b4a10860f3c74be658f5b5015f13fa2f2131da13ba5b4f78b28ef8b116e30a9c504ed013a4396af9264ff9781131bbda75d54665fea5d3d99ebdf10f6ef1a295f9b64c640eccb630c697b3471269562558e6c4742f8ad5bfedbc906dcb97dd191caf3ee57a1b654159d82d65fbe7d55a5e99e4c6fe9fa6ec08fef9b38f1754266034fac7b04777ab185695fad87ede35db2c4b21a6e2e0b22a0957ec15723895fd17a7a5df0862f14eed608042538689771eb85f1e13f2b6b8e1a6617418cf59aed03b4006b55699c250404dbecd4ba113ddd1ccbd7ccb627802c5d99762d601bf36a4f53380e434eea71f8731c6f3050b9c93a304004ec087ec8aa3fed95878c803d0ae975a4efe6af984d3eef9fb1b39bb788e57159c3e8ba81ff95642e6ec3e17d3d46df0b1fbb6fa43a43732f614b7a7f44f0c79969ddeed8d078a5d8f02b8eb988d69ece5e9df64cf76f75b9a2b35eef53e089b34fbb216e2904bbef236758cf93ad850db275714467de3be7f390383cf0f9d64fef2ffbc8da3eb257a538777ff3cafea1affc57c67d9ebdd3fe74f0f9debba10844e911cbfecd45c75b9650fffe35c4f93abb83fda09a06f3f31003483eddd453c5ccd58a7fe37b1045503904136419165bed069b8550eb6f82bca44c2bfa48b2746974476cfa7b62c7e0d31f970ac5dec59465b0b896a44ec4605e297eb16c9d0d5a0d7ab60ad86e87ee5cc0957bedb44f749be47d2ee62461b8f940d113dbfa5009c58e56f8dc20ba194cdf32f2fbdc73648b77358f17e6ecb01daf7cbe7e5db9be1eb52f339d65cafa3f308cb01433d338fde9510139609abc5a339ffa9e2b33c6ca7c88ea43f309a32f1d555c0296f4082ad90720a7fdb82a9c78314bc0cf98b2c2946401bdb2ac62d2d4bb68758623fee85df8be1f3e5cd6f722961ab37e1cfd1957d16604e686af44724116befdd9028b1cca99a35353ea416a72566b9d50856fa3201440dfc40f75f4fda58e18adeefc2c01ed72477c";
    bytes internal constant pubkey =
        hex"abe1410bd0e704bf98724dfc3ed93b9f8486cb036900ae3cacebee284412a42a6b2935e39f735cb9902fd03e9e7f8c08";
    bytes internal constant signature =
    // solhint-disable-next-line max-line-length
        hex"8b17cbc6bf74af4c991f251aa983d58bcd7e358bbc1cfd586f79295fb880257af4aad65742bb36195ea08c90c0c31f0d0a6960688b3780d29d93a4c411bb86d26ba0b48ebef5808bdfec1c8e92cdaeb5e8c998a7aae6d34ff9274b302e9f2baf";
    bytes32 internal constant depositDataRoot = 0x98ca90962cc311b2f7487a5b383bc4136e63eca90261eb095e2f79211548a622;

    uint256 internal constant ssvAmount = 1 ether;
    ValidatorStakeData[] internal validatorStakeData;

    address internal wWhale;

    function setUp() public override {
        super.setUp();

        nodeDelegator2 = NodeDelegator(payable(AddressesHolesky.NODE_DELEGATOR_NATIVE_STAKING));
        primeZapper = PrimeZapper(payable(AddressesHolesky.PRIME_ZAPPER));

        validatorStakeData.push(
            ValidatorStakeData({ pubkey: pubkey, signature: signature, depositDataRoot: depositDataRoot })
        );

        // Use the following Hardhat task to get the latest SSV Cluster data
        // npx hardhat getClusterInfo --network local --operatorids 111.119.139.252
        // TODO get this data dynamically from the logs of the last SSV tx
        cluster = Cluster({
            validatorCount: 1,
            networkFeeIndex: 42_611_440_888,
            index: 53_800_140_600,
            active: true,
            balance: 2_267_120_984_000_000_000
        });

        // SSV Cluster operator ids
        operatorIds.push(111);
        operatorIds.push(119);
        operatorIds.push(139);
        operatorIds.push(252);

        wWhale = makeAddr("wethWhale");
        vm.deal(wWhale, 100 ether);
        vm.prank(wWhale);
        IWETH(AddressesHolesky.WETH_TOKEN).deposit{ value: 65 ether }();
    }

    function test_approveSSV() public {
        vm.prank(AddressesHolesky.MANAGER_ROLE);

        vm.expectEmit(AddressesHolesky.SSV_TOKEN);
        emit Approval(address(nodeDelegator2), AddressesHolesky.SSV_NETWORK, type(uint256).max);

        nodeDelegator2.approveSSV();
    }

    // This test will probably have to be removed as balance will change and can't simply be queried from the SSV
    // Network contract
    function test_depositSSV() public {
        uint256 amount = 3e18;
        deal(address(AddressesHolesky.SSV_TOKEN), AddressesHolesky.MANAGER_ROLE, amount);

        vm.prank(AddressesHolesky.MANAGER_ROLE);

        vm.expectEmit(AddressesHolesky.SSV_TOKEN);
        emit Transfer(address(nodeDelegator2), AddressesHolesky.SSV_NETWORK, amount);

        nodeDelegator2.depositSSV(operatorIds, amount, cluster);
    }

    function test_deposit_WETH() public {
        deposit(AddressesHolesky.WETH_TOKEN, wWhale, 20 ether);
    }

    function test_deposit_ETH() public {
        depositETH(wWhale, 20 ether, false);
    }

    function test_deposit_ETH_call() public {
        vm.prank(wWhale);
        IWETH(AddressesHolesky.WETH_TOKEN).withdraw(20 ether);

        depositETH(wWhale, 20 ether, true);
    }

    function test_transfer_del_node_WETH() public {
        uint256 transferAmount = 18 ether;
        address asset = AddressesHolesky.WETH_TOKEN;
        deposit(asset, wWhale, 20 ether);

        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        vm.prank(AddressesHolesky.OPERATOR_ROLE);

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
        address asset = AddressesHolesky.WETH_TOKEN;
        deposit(asset, wWhale, 30 ether);

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        lrtDepositPool.transferAssetToNodeDelegator(1, asset, transferAmount);

        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(asset);

        // Add ETH to the Node Delegator to simulate ETH rewards
        vm.deal(AddressesHolesky.NODE_DELEGATOR_NATIVE_STAKING, 0.01 ether);

        // Get after asset balances
        (uint256 assetsDepositPoolAfter, uint256 assetsNDCsAfter, uint256 assetsElAfter) =
            lrtDepositPool.getAssetDistributionData(asset);

        assertEq(assetsDepositPoolAfter, assetsDepositPoolBefore, "assets in DepositPool");
        assertEq(assetsNDCsAfter, assetsNDCsBefore + 0.01 ether, "assets in NDCs");
        assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer");
    }

    function test_registerValidator() public {
        uint256 transferAmount = 32 ether;
        address asset = AddressesHolesky.WETH_TOKEN;
        deposit(asset, wWhale, transferAmount);

        vm.startPrank(AddressesHolesky.OPERATOR_ROLE);

        lrtDepositPool.transferAssetToNodeDelegator(1, asset, transferAmount);

        (uint256 ndcEthBefore, uint256 eigenEthBefore) = nodeDelegator2.getAssetBalance(AddressesHolesky.WETH_TOKEN);

        nodeDelegator2.registerSsvValidator(validatorStakeData[0].pubkey, operatorIds, sharesData, ssvAmount, cluster);

        (uint256 ndcEthAfter, uint256 eigenEthAfter) = nodeDelegator2.getAssetBalance(AddressesHolesky.WETH_TOKEN);
        assertEq(ndcEthAfter, ndcEthBefore, "WETH/ETH in NodeDelegator after");
        assertEq(eigenEthAfter, eigenEthBefore, "WETH/ETH in EigenLayer after");

        vm.stopPrank();
    }

    function test_stakeETH() public {
        address asset = AddressesHolesky.WETH_TOKEN;
        deposit(asset, wWhale, 65 ether);

        vm.startPrank(AddressesHolesky.OPERATOR_ROLE);

        lrtDepositPool.transferAssetToNodeDelegator(1, asset, 65 ether);

        nodeDelegator2.registerSsvValidator(validatorStakeData[0].pubkey, operatorIds, sharesData, ssvAmount, cluster);

        (uint256 ndcEthBefore, uint256 eigenEthBefore) = nodeDelegator2.getAssetBalance(AddressesHolesky.WETH_TOKEN);

        vm.expectEmit(AddressesHolesky.NODE_DELEGATOR_NATIVE_STAKING);
        emit ETHStaked(validatorStakeData[0].pubkey, 32 ether);

        nodeDelegator2.stakeEth(validatorStakeData);

        (uint256 ndcEthAfter, uint256 eigenEthAfter) = nodeDelegator2.getAssetBalance(AddressesHolesky.WETH_TOKEN);
        assertEq(ndcEthAfter, ndcEthBefore - 32 ether, "WETH/ETH in NodeDelegator after");
        assertEq(eigenEthAfter, eigenEthBefore + 32 ether, "WETH/ETH in EigenLayer after");

        // Deposit some ETH in the EigenPod
        vm.deal(AddressesHolesky.EIGEN_POD, 0.1 ether);

        (uint256 ndcEthAfterRewards, uint256 eigenEthAfterRewards) =
            nodeDelegator2.getAssetBalance(AddressesHolesky.WETH_TOKEN);
        assertEq(ndcEthAfterRewards, ndcEthBefore - 32 ether, "WETH/ETH in NodeDelegator after consensus rewards");
        assertEq(eigenEthAfterRewards, eigenEthBefore + 32.1 ether, "WETH/ETH in EigenLayer after consensus rewards");

        // Should fail to register a second time
        vm.expectRevert(
            abi.encodeWithSelector(INodeDelegator.ValidatorAlreadyStaked.selector, validatorStakeData[0].pubkey)
        );
        nodeDelegator2.stakeEth(validatorStakeData);

        vm.stopPrank();
    }

    function test_transferBackWETH() public {
        // transferBackToLRTDepositPool
        address asset = AddressesHolesky.WETH_TOKEN;
        deposit(asset, wWhale, 20 ether);

        vm.prank(AddressesHolesky.OPERATOR_ROLE);
        lrtDepositPool.transferAssetToNodeDelegator(1, asset, 20 ether);

        // Add some ETH to the Node Delegator to simulate ETH rewards
        vm.deal(AddressesHolesky.NODE_DELEGATOR_NATIVE_STAKING, 10 ether);

        vm.prank(AddressesHolesky.MANAGER_ROLE);

        vm.expectEmit(AddressesHolesky.WETH_TOKEN);
        emit Transfer(address(nodeDelegator2), address(lrtDepositPool), 30 ether);

        nodeDelegator2.transferBackToLRTDepositPool(asset, 30 ether);
    }

    function test_revertWhenSecondCreatePod() public {
        vm.startPrank(AddressesHolesky.ADMIN_ROLE);
        vm.expectRevert("EigenPodManager.createPod: Sender already has a pod");
        nodeDelegator2.createEigenPod();
        vm.stopPrank();
    }

    function depositETH(address whale, uint256 amountToTransfer, bool sendEthWithACall) internal {
        // Get before asset balances
        (uint256 assetsDepositPoolBefore, uint256 assetsNDCsBefore, uint256 assetsElBefore) =
            lrtDepositPool.getAssetDistributionData(AddressesHolesky.WETH_TOKEN);

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
            emitter: AddressesHolesky.WETH_TOKEN,
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: false
        });
        emit Transfer(address(primeZapper), address(lrtDepositPool), amountToTransfer);

        // Should mint primeETH
        vm.expectEmit({
            emitter: AddressesHolesky.PRIME_STAKED_ETH,
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
            lrtDepositPool.getAssetDistributionData(AddressesHolesky.WETH_TOKEN);

        // Check the asset distribution across the DepositPool, NDCs and EigenLayer
        // stETH can leave a dust amount behind so using assertApproxEqAbs
        assertApproxEqAbs(
            assetsDepositPoolAfter, assetsDepositPoolBefore + amountToTransfer, 1, "assets in DepositPool"
        );
        assertEq(assetsNDCsAfter, assetsNDCsBefore, "assets in NDCs");
        assertEq(assetsElAfter, assetsElBefore, "assets in EigenLayer");
    }

    function test_revertWhenDepositLST() public {
        address[] memory assets = new address[](2);
        assets[0] = AddressesHolesky.STETH_TOKEN;
        assets[1] = AddressesHolesky.RETH_TOKEN;

        address[] memory whales = new address[](2);
        whales[0] = stWhale;
        whales[1] = rWhale;

        for (uint256 i = 0; i < assets.length; i++) {
            vm.prank(AddressesHolesky.MANAGER_ROLE);
            LRTConfig(AddressesHolesky.LRT_CONFIG).updateAssetDepositLimit(assets[i], 0);

            vm.startPrank(whales[i]);

            IERC20(assets[i]).approve(address(lrtDepositPool), 1e18);

            vm.expectRevert(ILRTDepositPool.MaximumDepositLimitReached.selector);
            lrtDepositPool.depositAsset(assets[i], 1e18, 0, referralId);

            vm.stopPrank();
        }
    }
}
