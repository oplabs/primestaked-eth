// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { IDelegationManager, IDelegationManagerTypes } from "./eigen/interfaces/IDelegationManager.sol";
import { ISignatureUtils } from "./eigen/interfaces/ISignatureUtils.sol";
import { ISignatureUtilsMixinTypes } from "./eigen/interfaces/ISignatureUtilsMixin.sol";
import { IStrategyManager, IStrategy } from "./eigen/interfaces/IStrategyManager.sol";
import { INodeDelegatorLST } from "./interfaces/INodeDelegatorLST.sol";
import { IOETH } from "./interfaces/IOETH.sol";

/// @title NodeDelegatorLST Contract
/// @notice The contract that handles the depositing of assets into strategies
contract NodeDelegatorLST is
    INodeDelegatorLST,
    LRTConfigRoleChecker,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    /// @dev The Wrapped ETH (WETH) contract address with interface IWETH
    address public immutable WETH;

    /// @dev The EigenPod is created and owned by this contract
    address internal deprecated_eigenPod;
    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentials to verify the validator credentials on EigenLayer
    uint256 internal deprecated_stakedButNotVerifiedEth;

    uint256 internal constant DUST_AMOUNT = 10;
    mapping(bytes32 pubkeyHash => bool hasStaked) internal deprecated_validatorsStaked;

    /// @dev Maps the withdrawalRoots from the EigenLayer DelegationManager to the staker requesting the withdrawal.
    /// Is not populated for internal withdrawals
    mapping(bytes32 => address) public withdrawalRequests;
    /// @dev Maps each EigenLayer strategy to the total amount of shares pending from internal withdrawals.
    /// This does not include pending external withdrawals from Stakers as the PrimeETH total supply
    // is reduced on external withdrawal request.
    mapping(address => uint256) public pendingInternalShareWithdrawals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _weth) {
        UtilLib.checkNonZeroAddress(_weth);
        WETH = _weth;

        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __Pausable_init();
        __ReentrancyGuard_init();

        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /// @notice Approves the maximum amount of an asset to the eigen strategy manager
    /// @dev only supported assets can be deposited and only called by the LRT manager
    /// @param asset the asset to deposit
    function maxApproveToEigenStrategyManager(address asset)
        external
        override
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);
        IERC20(asset).approve(eigenlayerStrategyManagerAddress, type(uint256).max);
    }

    /// @notice Deposits an asset lying in this NDC into its strategy
    /// @dev only supported LST assets can be deposited and only called by the LRT Operator.
    /// WETH can not be deposited.
    /// @param asset the asset to deposit
    function depositAssetIntoStrategy(address asset)
        external
        override
        whenNotPaused
        nonReentrant
        onlySupportedAsset(asset)
        onlyLRTOperator
    {
        _depositAssetIntoStrategy(asset);
    }

    /// @notice Deposits all specified assets lying in this NDC into its strategy
    /// @dev only supported LST assets can be deposited and only called by the LRT Operator.
    /// WETH can not be deposited.
    /// @param assets List of assets to deposit
    function depositAssetsIntoStrategy(address[] calldata assets)
        external
        override
        whenNotPaused
        nonReentrant
        onlyLRTOperator
    {
        // For each of the specified assets
        for (uint256 i; i < assets.length;) {
            // Check the asset is supported
            if (!lrtConfig.isSupportedAsset(assets[i])) {
                revert ILRTConfig.AssetNotSupported();
            }

            _depositAssetIntoStrategy(assets[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Deposits an asset into its strategy.
    /// The calling function is responsible for ensuring the asset is supported.
    /// @param asset the asset to deposit
    function _depositAssetIntoStrategy(address asset) internal {
        if (asset == WETH) {
            // Can not deposit WETH into this NodeDelegatorLST contract
            revert ILRTConfig.AssetNotSupported();
        }
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            revert StrategyIsNotSetForAsset();
        }

        IERC20 token = IERC20(asset);
        uint256 balance = token.balanceOf(address(this));

        // EigenLayer does not allow minting zero shares. Error: StrategyBase.deposit: newShares cannot be zero
        // So do not deposit if dust amount
        if (balance <= DUST_AMOUNT) {
            return;
        }

        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        emit AssetDepositIntoStrategy(asset, strategy, balance);

        IStrategyManager(eigenlayerStrategyManagerAddress).depositIntoStrategy(IStrategy(strategy), token, balance);
    }

    /// @notice Transfers an asset back to the LRT deposit pool
    /// @dev only supported assets can be transferred and only called by the LRT manager
    /// @param asset the asset to transfer
    /// @param amount the amount to transfer
    function transferBackToLRTDepositPool(
        address asset,
        uint256 amount
    )
        external
        whenNotPaused
        nonReentrant
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        address lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);

        bool success = IERC20(asset).transfer(lrtDepositPool, amount);

        if (!success) {
            revert TokenTransferFailed();
        }
    }

    /// @notice Fetches the balance of all supported assets in this NodeDelegator and the underlying EigenLayer.
    /// This includes LSTs and WETH.
    /// @return assets a list of assets addresses
    /// @return assetBalances the balances of the assets in the node delegator and EigenLayer
    function getAssetBalances()
        external
        view
        override
        returns (address[] memory assets, uint256[] memory assetBalances)
    {
        assets = lrtConfig.getSupportedAssetList();
        assetBalances = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length;) {
            (uint256 ndcAssets, uint256 eigenAssets) = getAssetBalance(assets[i]);
            assetBalances[i] = ndcAssets + eigenAssets;

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the balance of an asset that the node delegator has deposited into an EigenLayer strategy.
    // Also needs to account for any shares pending internal withdrawal by the Prime Operator.
    /// @param asset the token address of the asset.
    /// Any WETH in the contract will be included but no native ETH in this contract or staked in EigenLayer.
    /// @return ndcAssets assets lying in this NDC contract.
    /// @return eigenAssets asset amount deposited in underlying EigenLayer strategy
    function getAssetBalance(address asset) public view override returns (uint256 ndcAssets, uint256 eigenAssets) {
        ndcAssets += IERC20(asset).balanceOf(address(this));

        if (asset == WETH) {
            // WETH can't be staked into validators from this NodeDelegatorLST contract
            // so just return the WETH in this contract if any.
            return (ndcAssets, eigenAssets);
        }

        // If an LST asset
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            return (ndcAssets, eigenAssets);
        }

        // Get the amount of strategy shares owned by this contract.
        IStrategyManager strategyManager = IStrategyManager(lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER));
        uint256 strategyShares = strategyManager.stakerDepositShares(address(this), IStrategy(strategy));

        // add any shares pending internal withdrawal to the strategy shares owned by this contract.
        // staker withdrawals are not added to pendingInternalShareWithdrawals as the primeETH tokens are burnt on
        // request.
        strategyShares += pendingInternalShareWithdrawals[strategy];

        // Convert the strategy shares to LST assets
        eigenAssets = IStrategy(strategy).sharesToUnderlyingView(strategyShares);
    }

    /// @notice Delegates all staked assets from this contract to an EigenLayer Operator.
    /// @param operator the address of the EigenLayer Operator to delegate to.
    function delegateTo(address operator) external onlyLRTManager {
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        delegationManager.delegateTo(
            operator, ISignatureUtilsMixinTypes.SignatureWithExpiry({ signature: new bytes(0), expiry: 0 }), 0x0
        );

        emit Delegate(operator);
    }

    /// @notice Undelegates all staked LST assets from this contract from the
    /// previously delegated to EigenLayer Operator.
    /// This also forces a withdrawal so the assets will need to be claimed.
    function undelegate() external onlyLRTManager {
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        // Get the amount of strategy shares owned by this NodeDelegator contract
        IStrategyManager strategyManager = IStrategyManager(lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER));

        // For each asset
        address[] memory assets = lrtConfig.getSupportedAssetList();
        for (uint256 i = 0; i < assets.length; ++i) {
            // Skip WETH as ETH restaked into EigenLayer is not yet supported by the NodeDelegator.
            if (assets[i] == WETH) {
                continue;
            }

            // Get the EigenLayer strategy for the LST asset
            address strategy = lrtConfig.assetStrategy(assets[i]);

            uint256 strategyShares = strategyManager.stakerDepositShares(address(this), IStrategy(strategy));
            // account for the strategy shares pending internal withdrawal
            pendingInternalShareWithdrawals[strategy] += strategyShares;

            emit Undelegate(strategy, strategyShares);
        }

        delegationManager.undelegate(address(this));
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyLRTManager {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /// @dev opts in for rebase so the asset's token balance will increase
    function optIn(address asset) external onlyLRTAdmin onlySupportedAsset(asset) {
        IOETH(asset).rebaseOptIn();
    }

    /// @notice Requests a withdrawal of liquid staking tokens (LST) from EigenLayer's underlying strategy.
    /// Is only callable by the `LRTDepositPool` contract.
    /// @param strategyAddress the address of the EigenLayer LST strategy to withdraw from
    /// @param strategyShares the amount of EigenLayer strategy shares to redeem
    /// @param staker the address of the staker requesting the withdrawal.
    function requestWithdrawal(
        address strategyAddress,
        uint256 strategyShares,
        address staker
    )
        external
        onlyDepositPool
        whenNotPaused
    {
        // request the withdrawal of the LST asset from EigenLayer
        bytes32 withdrawalRoot = _requestWithdrawal(strategyAddress, strategyShares);

        // store a mapping of the returned withdrawalRoot to the staker withdrawing
        require(withdrawalRequests[withdrawalRoot] == address(0), "Withdrawal already requested");
        withdrawalRequests[withdrawalRoot] = staker;

        emit RequestWithdrawal(strategyAddress, withdrawalRoot, staker, strategyShares);
    }

    /// @notice Requests a withdrawal of liquid staking tokens (LST) from EigenLayer's underlying strategy.
    /// Must wait `minWithdrawalDelayBlocks` on EigenLayer's `DelegationManager` contract
    /// before claiming the withdrawal.
    /// This is currently set to 50,400 blocks (7 days) on mainnet. 10 blocks on Holesky.
    /// Is only callable by accounts with the Operator role.
    /// @param strategyAddress the address of the EigenLayer LST strategy to withdraw from
    /// @param strategyShares the amount of EigenLayer strategy shares to redeem
    function requestInternalWithdrawal(address strategyAddress, uint256 strategyShares) external onlyLRTOperator {
        // request the withdrawal of the LSTs from EigenLayer's underlying strategy.
        bytes32 withdrawalRoot = _requestWithdrawal(strategyAddress, strategyShares);

        // account for the pending withdrawal as the shares are no longer accounted for in the EigenLayer strategy
        pendingInternalShareWithdrawals[strategyAddress] += strategyShares;

        emit RequestWithdrawal(strategyAddress, withdrawalRoot, address(0), strategyShares);
    }

    /// @dev request the withdrawal of the LSTs from EigenLayer's underlying strategy.
    /// @param strategy the address of the EigenLayer LST strategy to withdraw from
    /// @param strategyShares the amount of EigenLayer strategy shares to redeem
    /// @return withdrawalRoot the hash of the withdrawal data
    function _requestWithdrawal(address strategy, uint256 strategyShares) internal returns (bytes32 withdrawalRoot) {
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(strategy);

        // Calculate how many EigenLayer strategy shares to redeem to get the requested asset amount
        uint256[] memory shares = new uint256[](1);
        shares[0] = strategyShares;

        // request the withdrawal of the LSTs from EigenLayer
        IDelegationManagerTypes.QueuedWithdrawalParams[] memory requests =
            new IDelegationManagerTypes.QueuedWithdrawalParams[](1);
        requests[0] = IDelegationManagerTypes.QueuedWithdrawalParams(strategies, shares, address(this));
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        // request the withdrawal from EigenLayer.
        // Will emit the Withdrawal event from EigenLayer's DelegationManager which is needed for the claim.
        withdrawalRoot = delegationManager.queueWithdrawals(requests)[0];
    }

    /// @notice Claims the previously requested withdrawal from EigenLayer's underlying strategy.
    /// Transfers the withdrawn assets to the staker that requested the withdrawal.
    /// Is only callable by the `LRTDepositPool` contract.
    /// @param withdrawal the `withdrawal` data emitted in the `WithdrawalQueued` event from EigenLayer's
    /// `DelegationManager` contract when `requestWithdrawal` was called on the `LRTDepositPool` contract by the staker.
    /// @param staker the address of the staker requesting the withdrawal
    /// @return asset address of the liquid staking tokens (LST) that were claimed.
    /// @return assets the amount of LSTs received from the withdrawal
    function claimWithdrawal(
        IDelegationManager.Withdrawal calldata withdrawal,
        address staker,
        address receiver
    )
        external
        onlyDepositPool
        whenNotPaused
        returns (address asset, uint256 assets)
    {
        // Make sure the staker requested this withdrawal
        // and the withdrawal was not manipulated
        bytes32 withdrawalRoot = _calculateWithdrawalRoot(withdrawal);
        if (withdrawalRequests[withdrawalRoot] != staker) {
            revert StakersWithdrawalNotFound();
        }
        withdrawalRequests[withdrawalRoot] = DEAD_ADDRESS;

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IStrategy(withdrawal.strategies[0]).underlyingToken();
        asset = address(tokens[0]);

        // There can be assets sitting in this NodeDelegator contract so we need to account for those.
        uint256 assetsBefore = IERC20(asset).balanceOf(address(this));

        // Claim the previously requested withdrawal from EigenLayer
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager(delegationManagerAddress).completeQueuedWithdrawal(withdrawal, tokens, true);

        // Calculate the amount of assets returned from the withdrawal
        assets = IERC20(asset).balanceOf(address(this)) - assetsBefore;
        if (assets > 0) {
            // transfer withdrawn assets to the receiver, which is either the staker or the LRTDepositPool contract
            IERC20(asset).transfer(receiver, assets);
        }

        emit ClaimWithdrawal(address(withdrawal.strategies[0]), withdrawalRoot, staker, receiver, assets);
    }

    /// @notice Claims the previously requested internal withdrawal from the underlying EigenLayer strategy.
    /// Transfers the withdrawn liquid staking tokens to the `LRTDepositPool` contract.
    /// Is only callable by accounts with the Operator role.
    /// @param withdrawal the `withdrawal` data emitted in the `WithdrawalQueued` event from EigenLayer's
    /// `DelegationManager` contract when `requestInternalWithdrawal` was called
    /// on the `NodeDelegator` contract by a Prime Operator.
    /// @return asset address of the liquid staking tokens (LST) that were claimed.
    /// @return assets the amount of LSTs transferred to the `LRTDepositPool` contract.
    function claimInternalWithdrawal(IDelegationManager.Withdrawal calldata withdrawal)
        external
        onlyLRTOperator
        returns (address asset, uint256 assets)
    {
        // Make sure not withdrawing a staker's requested withdrawal
        bytes32 withdrawalRoot = _calculateWithdrawalRoot(withdrawal);
        if (withdrawalRequests[withdrawalRoot] != address(0)) {
            revert NotInternalWithdrawal();
        }
        // Safety check that only one strategy is being withdrawn from.
        // This should be the case as the call to EL's DelegationManager.queueWithdrawals
        // comes from this contract's requestInternalWithdrawal function with only one strategy.
        if (withdrawal.strategies.length != 1) {
            revert NotSingleStrategyWithdrawal();
        }
        asset = address(IStrategy(withdrawal.strategies[0]).underlyingToken());

        // There can be assets sitting in this NodeDelegator contract so we need to account for those.
        uint256 assetsBefore = IERC20(asset).balanceOf(address(this));

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(asset);

        // Claim the previously requested withdrawal from EigenLayer
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager(delegationManagerAddress).completeQueuedWithdrawal(withdrawal, tokens, true);

        // Remove the pending internal withdrawal shares now that they have been claimed
        pendingInternalShareWithdrawals[address(withdrawal.strategies[0])] -= withdrawal.scaledShares[0];

        // Calculate the amount of assets returned from the withdrawal
        address depositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        assets = IERC20(asset).balanceOf(address(this)) - assetsBefore;
        if (assets > 0) {
            // transfer withdrawn assets to the Deposit Pool
            IERC20(asset).transfer(depositPool, assets);
        }

        emit ClaimWithdrawal(address(withdrawal.strategies[0]), withdrawalRoot, address(0), depositPool, assets);
    }

    /// @dev Returns the keccak256 hash of `withdrawal`.
    /// @param withdrawal the `withdrawal` data emitted in the `WithdrawalQueued` event
    /// from EigenLayer's `DelegationManager` contract.
    function _calculateWithdrawalRoot(IDelegationManager.Withdrawal memory withdrawal)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(withdrawal));
    }
}
