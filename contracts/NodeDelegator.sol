// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { IDelegationManager } from "./eigen/interfaces/IDelegationManager.sol";
import { IEigenPodManager, IEigenPod } from "./eigen/interfaces/IEigenPodManager.sol";
import { ISignatureUtils } from "./eigen/interfaces/ISignatureUtils.sol";
import { IStrategyManager, IStrategy } from "./eigen/interfaces/IStrategyManager.sol";
import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { ISSVNetwork, Cluster } from "./interfaces/ISSVNetwork.sol";
import { IOETH } from "./interfaces/IOETH.sol";
import { IWETH } from "./interfaces/IWETH.sol";

struct ValidatorStakeData {
    bytes pubkey;
    bytes signature;
    bytes32 depositDataRoot;
}

/// @title NodeDelegator Contract
/// @notice The contract that handles the depositing of assets into strategies
contract NodeDelegator is INodeDelegator, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    /// @dev The Wrapped ETH (WETH) contract address with interface IWETH
    address public immutable WETH_TOKEN_ADDRESS;

    /// @dev The EigenPod is created and owned by this contract
    address public eigenPod;
    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentials to verify the validator credentials on EigenLayer
    uint256 public stakedButNotVerifiedEth;

    uint256 internal constant DUST_AMOUNT = 10;
    mapping(bytes32 pubkeyHash => bool hasStaked) public validatorsStaked;

    /// @dev Maps the withdrawalRoots from the EigenLayer DelegationManager to the staker requesting the withdrawal.
    /// Is not populated for internal withdrawals
    mapping(bytes32 => address) public withdrawalRequests;
    /// @dev Maps each EigenLayer strategy to the total amount of shares pending from internal withdrawals.
    /// This does not include pending external withdrawals from Stakers as the PrimeETH total supply
    // is reduced on external withdrawal request.
    mapping(address => uint256) public pendingInternalShareWithdrawals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _wethAddress) {
        UtilLib.checkNonZeroAddress(_wethAddress);
        WETH_TOKEN_ADDRESS = _wethAddress;

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

    function createEigenPod() external onlyLRTManager {
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPod = eigenPodManager.createPod();

        emit EigenPodCreated(eigenPod, address(this));
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
    /// @dev only supported assets can be deposited and only called by the LRT Operator
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
    /// @dev only supported assets can be deposited and only called by the LRT Operator
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

        // Convert any ETH to WETH before transferring
        if (asset == WETH_TOKEN_ADDRESS) {
            uint256 ethBalance = address(this).balance;
            if (ethBalance > 0) {
                // Convert any ETH into WETH
                IWETH(WETH_TOKEN_ADDRESS).deposit{ value: ethBalance }();
            }
        }

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

    /// @dev Returns the balance of an asset that the node delegator has deposited into an EigenLayer strategy
    /// or native ETH staked into an EigenPod.
    // Also needs to account for any shares pending internal withdrawal by the Prime Operator.
    /// @param asset the token address of the asset.
    /// WETH will include any native ETH in this contract or staked in EigenLayer.
    /// @return ndcAssets assets lying in this NDC contract.
    /// This includes any native ETH when the asset is WETH.
    /// @return eigenAssets asset amount deposited in underlying EigenLayer strategy
    /// or native ETH staked into an EigenPod.
    function getAssetBalance(address asset) public view override returns (uint256 ndcAssets, uint256 eigenAssets) {
        ndcAssets += IERC20(asset).balanceOf(address(this));

        // The WETH asset will point to the EigenLayer beaconChainETHStrategy 0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy != address(0)) {
            // Get the amount of strategy shares owned by this NodeDelegator contract.
            // Currently this only include LST assets as EigenLayer restaking is
            // not yet supported by this NodeDelegator contract. The WETH asset will
            // point to the EigenLayer beaconChainETHStrategy 0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0
            IStrategyManager strategyManager =
                IStrategyManager(lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER));
            uint256 strategyShares = strategyManager.stakerStrategyShares(address(this), IStrategy(strategy));

            // add any shares pending internal withdrawal to the strategy shares owned by this NodeDelegator.
            // staker withdrawals are not added to pendingInternalShareWithdrawals as the primeETH tokens are burnt on
            // request.
            strategyShares += pendingInternalShareWithdrawals[strategy];

            // Convert the strategy shares to LST assets
            eigenAssets = IStrategy(strategy).sharesToUnderlyingView(strategyShares);
        }

        if (asset == WETH_TOKEN_ADDRESS) {
            // Add any ETH in the NDC that was earned from execution rewards
            ndcAssets += address(this).balance;

            eigenAssets += stakedButNotVerifiedEth;

            // Add any consensus rewards that have been sent to the EigenPod.
            // In the future this can include full validator withdrawals that have been swept
            // to the EigenPod but native ETH restaking and withdrawals is not currently supported
            // by the NodeDelegator.
            if (eigenPod != address(0)) {
                eigenAssets += eigenPod.balance;
            }
        }
    }

    /// @notice Stakes WETH or ETH in the NDC to multiple validators connected to an EigenPod.
    /// @param validators A list of validator data needed to stake.
    /// The ValidatorStakeData struct contains the pubkey, signature and depositDataRoot.
    /// @dev Only accounts with the Operator role can call this function.
    function stakeEth(ValidatorStakeData[] calldata validators) external whenNotPaused nonReentrant onlyLRTOperator {
        // Yield from the validators will come as native ETH.
        uint256 ethBalance = address(this).balance;
        uint256 requiredETH = validators.length * 32 ether;
        if (ethBalance < requiredETH) {
            // If not enough native ETH, convert WETH to native ETH
            uint256 wethBalance = IWETH(WETH_TOKEN_ADDRESS).balanceOf(address(this));
            if (wethBalance + ethBalance < requiredETH) {
                revert InsufficientWETH(wethBalance + ethBalance);
            }
            // Convert WETH asset to native ETH
            IWETH(WETH_TOKEN_ADDRESS).withdraw(requiredETH - ethBalance);
        }

        // For each validator
        for (uint256 i = 0; i < validators.length;) {
            bytes32 pubkeyHash = keccak256(validators[i].pubkey);

            if (validatorsStaked[pubkeyHash]) {
                revert ValidatorAlreadyStaked(validators[i].pubkey);
            }

            _stakeEth(validators[i].pubkey, validators[i].signature, validators[i].depositDataRoot);
            validatorsStaked[pubkeyHash] = true;

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Stake WETH and ETH in NDC in EigenLayer. It calls the `stake` function on the EigenPodManager
    /// which calls `stake` on the EigenPod contract which calls `stake` on the Beacon DepositContract.
    /// @dev The public functions that call this internal function are responsible for access control.
    function _stakeEth(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) internal {
        // Call the stake function in the EigenPodManager
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        // Increment the staked but not verified ETH
        stakedButNotVerifiedEth += 32 ether;

        emit ETHStaked(pubkey, 32 ether);
    }

    /// @notice Delegates all staked assets from this NodeDelegator to an EigenLayer Operator.
    /// This includes both both LSTs and native ETH.
    /// @param operator the address of the EigenLayer Operator to delegate to.
    function delegateTo(address operator) external onlyLRTManager {
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        delegationManager.delegateTo(
            operator, ISignatureUtils.SignatureWithExpiry({ signature: new bytes(0), expiry: 0 }), 0x0
        );
    }

    /// @notice Undelegates all staked assets from this NodeDelegator from the
    /// previously delegated to EigenLayer Operator.
    /// This also forces a withdrawal so the assets will need to be claimed.
    function undelegate() external onlyLRTManager {
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        // Get the amount of strategy shares owned by this NodeDelegator contract
        IStrategyManager strategyManager = IStrategyManager(lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER));

        // For each asset
        address[] memory assets = lrtConfig.getSupportedAssetList();
        for (uint256 i = 0; i < assets.length;) {
            // Get the EigenLayer strategy for the asset
            // The WETH asset will point to the EigenLayer beaconChainETHStrategy
            // 0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0
            address strategy = lrtConfig.assetStrategy(assets[i]);

            // account for the strategy shares pending internal withdrawal
            pendingInternalShareWithdrawals[strategy] +=
                strategyManager.stakerStrategyShares(address(this), IStrategy(strategy));

            unchecked {
                ++i;
            }
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

    /// @dev Approves the SSV Network contract to transfer SSV tokens for deposits
    function approveSSV() external onlyLRTManager {
        address SSV_TOKEN_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_TOKEN);
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        IERC20(SSV_TOKEN_ADDRESS).approve(SSV_NETWORK_ADDRESS, type(uint256).max);
    }

    /// @dev Deposits more SSV Tokens to the SSV Network contract which is used to pay the SSV Operators
    function depositSSV(uint64[] memory operatorIds, uint256 amount, Cluster memory cluster) external onlyLRTManager {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).deposit(address(this), operatorIds, amount, cluster);
    }

    /// @dev Registers a new validator in the SSV Cluster
    function registerSsvValidator(
        bytes calldata publicKey,
        uint64[] calldata operatorIds,
        bytes calldata sharesData,
        uint256 amount,
        Cluster calldata cluster
    )
        external
        onlyLRTOperator
        whenNotPaused
    {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).registerValidator(publicKey, operatorIds, sharesData, amount, cluster);
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
        withdrawalRequests[withdrawalRoot] = staker;
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
        _requestWithdrawal(strategyAddress, strategyShares);

        // account for the pending withdrawal as the shares are no longer accounted for in the EigenLayer strategy
        pendingInternalShareWithdrawals[strategyAddress] += strategyShares;
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
        IDelegationManager.QueuedWithdrawalParams[] memory requests = new IDelegationManager.QueuedWithdrawalParams[](1);
        requests[0] = IDelegationManager.QueuedWithdrawalParams(strategies, shares, address(this));
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);

        // request the withdrawal from EigenLayer.
        // Will emit the Withdrawal event from EigenLayer's DelegationManager which is needed for the claim.
        withdrawalRoot = IDelegationManager(delegationManagerAddress).queueWithdrawals(requests)[0];
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
        address staker
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

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IStrategy(withdrawal.strategies[0]).underlyingToken();
        asset = address(tokens[0]);

        // There can be assets sitting in this NodeDelegator contract so we need to account for those.
        uint256 assetsBefore = IERC20(asset).balanceOf(address(this));

        // Claim the previously requested withdrawal from EigenLayer
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        // the 3rd middlewareTimesIndexes param is not used in the EigenLayer M2 contracts
        IDelegationManager(delegationManagerAddress).completeQueuedWithdrawal(withdrawal, tokens, 0, true);

        // Calculate the amount of assets returned from the withdrawal
        assets = IERC20(asset).balanceOf(address(this)) - assetsBefore;
        if (assets > 0) {
            // transfer withdrawn assets to the staker
            IERC20(asset).transfer(staker, assets);
        }
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
        // the 3rd middlewareTimesIndexes param is not used in the EigenLayer M2 contracts
        IDelegationManager(delegationManagerAddress).completeQueuedWithdrawal(withdrawal, tokens, 0, true);

        // Remove the pending internal withdrawal shares now that they have been claimed
        pendingInternalShareWithdrawals[address(withdrawal.strategies[0])] -= withdrawal.shares[0];

        // Calculate the amount of assets returned from the withdrawal
        assets = IERC20(asset).balanceOf(address(this)) - assetsBefore;
        if (assets > 0) {
            // transfer withdrawn assets to the Deposit Pool
            IERC20(asset).transfer(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL), assets);
        }
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

    /// @dev allow NodeDelegator to receive execution rewards from MEV and
    /// ETH from WETH withdrawals.
    /// Is not required to receive consensus rewards from the BeaconChain.
    receive() external payable { }
}
