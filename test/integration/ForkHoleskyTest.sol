// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";
import { LRTDepositPool, ILRTDepositPool, LRTConstants } from "contracts/LRTDepositPool.sol";
import { LRTConfig, ILRTConfig } from "contracts/LRTConfig.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";
import { AddressesHolesky } from "contracts/utils/Addresses.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ForkHoleskyTest is Test {
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
    address public constant rEthWhale = AddressesHolesky.RETH_WHALE;

    address public constant stEthOracle = AddressesHolesky.CHAINLINK_ORACLE_PROXY;
    address public constant rEthPriceOracle = AddressesHolesky.CHAINLINK_ORACLE_PROXY;

    uint256 public constant minPrimeAmount = 0;
    string public constant referralId = "ref id";
    uint256 public constant amountToTransfer = 1 ether;

    uint256 indexOfNodeDelegator;

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

        // rEthWhale balance of prETH before deposit
        uint256 rEthWhaleBalanceBefore = primeETH.balanceOf(rEthWhale);
        // total asset deposits before deposit for rETH
        uint256 totalAssetDepositsBefore = lrtDepositPool.getTotalAssetDeposits(rEthAddress);
        // balance of lrtDepositPool before deposit
        uint256 lrtDepositPoolBalanceBefore = ERC20(rEthAddress).balanceOf(address(lrtDepositPool));

        uint256 whaleBalBefore = ERC20(rEthAddress).balanceOf(address(rEthWhale));
        vm.startPrank(rEthWhale);
        ERC20(rEthAddress).approve(address(lrtDepositPool), amountToDeposit);
        lrtDepositPool.depositAsset(rEthAddress, amountToDeposit, minPrimeAmount, referralId);
        vm.stopPrank();
        uint256 whaleBalAfter = ERC20(rEthAddress).balanceOf(address(rEthWhale));

        console.log("whale amount transfer:", whaleBalBefore - whaleBalAfter);

        // rEthWhale balance of prETH after deposit
        uint256 rEthWhaleBalanceAfter = primeETH.balanceOf(address(rEthWhale));

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

        vm.startPrank(rEthWhale);
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
