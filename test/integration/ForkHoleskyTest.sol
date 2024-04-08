// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    function deposit(address asset, address whale, uint256 amountToTransfer) internal {
        vm.startPrank(whale);

        IERC20(asset).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(asset, amountToTransfer, amountToTransfer * 99 / 100, referralId);

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
        address strategy = makeAddr("strategy"); // TODO: Deploy a mock strategy contract

        vm.prank(admin);
        lrtConfig.updateAssetStrategy(stETHAddress, strategy);

        assertEq(lrtConfig.assetStrategy(stETHAddress), strategy);
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

contract ForkHoleskyTestNative is ForkHoleskyTestBase {
    NodeDelegator public nodeDelegator2;
    PrimeZapper public primeZapper;

    uint64[] operatorIds;
    Cluster public cluster;
    bytes internal constant sharesData =
    // solhint-disable-next-line max-line-length
        hex"8dd18b66d455376e47fbb92ef5017b378b98bf4507abcbb6d4a854685719f777eb43c57192b4c3583f67b0401e07ae510564c57cfb76e3edb87a9ce9cbc789c634589d6418536215f173d55a79bf96f1e2006e6b812bf182ca3415cc4812b9cb955cb772a6cf4306e88414ed3bfae7cf7105c6bfe32d57f256074f8fe576ba9f6af48b673b3bbc117f114446e9fd9fc9b5d35a90a1832ad3a5e61e7963b517bdbe1ee3f6825fdb6657dfce43780515458f4dfc2aeb69fcd37981965ba595b3fc838ab000986b05b026b1ebf05900e6fe45a606a3f7581c32d2ae194f8345a3a07e3fd58e306cd71571b23e248ba427e8b27cf0412bd878f2594e5883065c141891ea943b90167ff8cce307ed670e8a36c69187a6b00ac88bce8ca71e9ecf331390a0b8b46259d8c3f95101b9128f218ba5c6d901c586564f563110e097c3ee6dcf1a4a5aa2f81f59f027148bc51558ac9ffe5b24090aa69649678540878c0cc09463144a3773b667558b1799f64cbf1c29a94b2ebec2c6a764088974aee68fe38fb5983b4493ff47ab9f8e66fd06d8d92af5b8374075ecf6f1094f927ff35500e30e0742eb567c02f51c146a739a3ce85b0939aa9778197defe9c2e1d9cec8482430a324b0837f13fa492241f0dd510886d7aa81502a33136153b1ea9965100eb708b8b13009af373544971072ca5b28403024873f69077829ac83c3bdf3ea0e8b9900a4ad85e9c16ea01b306a8ee6703df4ee25feff456a3e74b804c0a98f411b910fb1aa44442d3706fa7688ee77442147cd99b9eef2ff3f556937e0f6bc504692651f13b7afa4412062cfe7cb2d64fb23a013a49aff9c8254ae048534d8855c884cc58d690ef11c6e7d8f6353eec59053cac6ad837afe24e71b8d792ca5d36101fa4bcc9e344351000546b4d9f30a3b693d97698b6a957560b8a271a089569caeebf6a1edba8704eaf78787751c4becd77a4f83ab1aa42f2ffa80f7f538669084aa37415cf3061237ba5509b7ea80489fc7775b354ec89b73b369c2b734bc3dc8e28bae508e9f39da79a1086e01b1e12a76db69311ef8ab39bedf190ee19e7f5e3fcdd6b1ea7b2eb4d3e91eec4f22fc0ce0cc97c85440e250b28bbadfa78488493e2241e80e7a6ccad07f0c7061fdeb5793ff0745d24df326a278150f0b36645ff4c0f34cff7aaf102c4af869e27e4ec640f3e022329da68e8735562daaa9d58e0f00e836902bc83f09be1b66b492f0c06d9c6d33ad2887516ad6ae9d295becdabcc81e7d5e129051cb604f0feb568fdb46f15594e979da76b09adf874f5b1e76a5cf98bead9d920f72f685506c5e5d615cbdd029eff09cabf04374f1b1e0190a44a7495fec92ded4bdbd57e626a966aff37351972007dea8b3b15653e32e5ddd28e121944730ae293b661b3db1535b5f24369f41577554adab337268e5a4d0152d4c366da3b6d37345a6ed37c23ca3b0e08eeed2235615175f5fe48338420f4587fb3ad182bae9614f2a29ce713d32129049d12cf248e6a9699c8d37e8eff549e16ccd760a7a5c9a1dca4f7626ad821a0e98bdc28b98ff5c9148b0e6ad25153efc62ebcd7c91123b1393bb37936451228a2fc040d1ee7e494807616bb3b61027b009aefbaa53a3dce727ad7639eae42d562148dbf30f3d6e8464a3e88708e214c7d1bf62d5d572663e3e521b876ce14fbf74c1ac590c2cdc281b483d794624af59b0619a43fb9f92e9d2c8195d29b5c9f0a4d2054e53e230740f10114f3cd462eebe18e955ed9cc8de7867e9dcf83b80548c91a04da9851f02a0023cb53dc78cb2d509badd0b97832046e866660c09d3350662a2531e63ce450053ec741e";
    uint256 internal constant ssvAmount = 1 ether;
    ValidatorStakeData[] internal validatorStakeData;

    address internal wWhale;

    function setUp() public override {
        super.setUp();

        nodeDelegator2 = NodeDelegator(payable(AddressesHolesky.NODE_DELEGATOR_NATIVE_STAKING));
        primeZapper = PrimeZapper(payable(AddressesHolesky.PRIME_ZAPPER));

        validatorStakeData.push(
            ValidatorStakeData({
                pubkey: hex"a49f46e5436c3d6bc6cad10e01d7e28d040ff7ed25a461f0c0316802da94f2e81ce9de4876269c72ad10e04a27fb4d89",
                // solhint-disable-next-line max-line-length
                signature: hex"b7f0a76e4c219500b5f957dcbbfd77b8e7315d0f68674f09f002c8829ce7c35a68dbb331be861257c09244ce02a312570a574ac4c0c16f3fcfe1a01723aa73d36b51c3f972de29aefbc19372dbe4ca1b3cb5c62b218175f76fef46618ff5dbed",
                depositDataRoot: 0xa42e1c2f202f28e94c8d31040787f5ddd39c828ba8b2582a2c129bc72bb9daf4
            })
        );

        // Latest SSV Cluster data
        cluster = Cluster({
            validatorCount: 1,
            networkFeeIndex: 41_966_195_056,
            index: 52_348_337_478,
            active: true,
            balance: 2_267_120_984_000_000_000
        });

        // SSV Cluster operator ids
        operatorIds.push(111);
        operatorIds.push(119);
        operatorIds.push(230);
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
    // Use the following to get the latest cluster SSV balance
    // npx hardhat getClusterInfo --network local --operatorids 111.119.230.252
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
