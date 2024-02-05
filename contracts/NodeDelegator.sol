// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";
import { IEigenStrategyManager } from "./interfaces/IEigenStrategyManager.sol";
import { IOETH } from "./interfaces/IOETH.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IEigenPodManager } from "./interfaces/IEigenPodManager.sol";
import { IEigenPod, BeaconChainProofs } from "./interfaces/IEigenPod.sol";

/// @title NodeDelegator Contract
/// @notice The contract that handles the depositing of assets into strategies
contract NodeDelegator is INodeDelegator, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    /// @dev The EigenPod is created and owned by this contract
    IEigenPod public eigenPod;
    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentials to verify the validator credentials on EigenLayer
    uint256 public stakedButNotVerifiedEth;

    uint256 internal constant DUST_AMOUNT = 10;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
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
        eigenPodManager.createPod();
        eigenPod = eigenPodManager.ownerToPod(address(this));

        emit EigenPodCreated(address(eigenPod), address(this));
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

        IEigenStrategyManager(eigenlayerStrategyManagerAddress).depositIntoStrategy(IStrategy(strategy), token, balance);
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

        bool success;
        if (asset == LRTConstants.ETH_TOKEN) {
            (success,) = payable(lrtDepositPool).call{ value: amount }("");
        } else {
            success = IERC20(asset).transfer(lrtDepositPool, amount);
        }

        if (!success) {
            revert TokenTransferFailed();
        }
    }

    /// @notice Fetches balance of all assets staked in eigen layer through this contract
    /// @return assets the assets that the node delegator has deposited into strategies
    /// @return assetBalances the balances of the assets that the node delegator has deposited into strategies
    function getAssetBalances()
        external
        view
        override
        returns (address[] memory assets, uint256[] memory assetBalances)
    {
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        (IStrategy[] memory strategies,) =
            IEigenStrategyManager(eigenlayerStrategyManagerAddress).getDeposits(address(this));

        uint256 strategiesLength = strategies.length;
        assets = new address[](strategiesLength);
        assetBalances = new uint256[](strategiesLength);

        for (uint256 i = 0; i < strategiesLength;) {
            assets[i] = address(IStrategy(strategies[i]).underlyingToken());
            assetBalances[i] = IStrategy(strategies[i]).userUnderlyingView(address(this));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the balance of an asset that the node delegator has deposited into the strategy
    /// @param asset the asset to get the balance of
    /// @return stakedBalance the balance of the asset
    function getAssetBalance(address asset) external view override returns (uint256) {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            return 0;
        }

        return IStrategy(strategy).userUnderlyingView(address(this));
    }

    /// @dev Returns the balance of an asset that the node delegator has deposited into its EigenPod strategy
    function getETHEigenPodBalance() external view override returns (uint256 ethStaked) {
        // TODO: Once withdrawals are enabled, allow this to handle pending withdraws and a potential negative share
        // balance in the EigenPodManager ownershares
        ethStaked = stakedButNotVerifiedEth;
        if (address(eigenPod) != address(0)) {
            ethStaked += address(eigenPod).balance;
        }
    }

    /// @notice Stake ETH from NDC into EigenLayer. it calls the stake function in the EigenPodManager
    /// which in turn calls the stake function in the EigenPod
    /// @param pubkey The pubkey of the validator
    /// @param signature The signature of the validator
    /// @param depositDataRoot The deposit data root of the validator
    /// @dev Only LRT Operator should call this function
    /// @dev Exactly 32 ether is allowed, hence it is hardcoded
    function stakeEth(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    )
        external
        onlyLRTOperator
    {
        // Call the stake function in the EigenPodManager
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        // Increment the staked but not verified ETH
        stakedButNotVerifiedEth += 32 ether;

        emit ETHStaked(pubkey, 32 ether);
    }

    /// @dev Verifies the withdrawal credentials for a withdrawal
    /// This will allow the EigenPodManager to verify the withdrawal credentials and credit the OD with shares
    /// Only manager should call this function
    /// @param oracleBlockNumber The oracle block number of the withdrawal
    /// @param validatorIndex The validator index of the withdrawal
    /// @param proofs The proofs of the withdrawal
    /// @param validatorFields The validator fields of the withdrawal
    function verifyWithdrawalCredentials(
        uint64 oracleBlockNumber,
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs memory proofs,
        bytes32[] calldata validatorFields
    )
        external
        onlyLRTOperator
    {
        eigenPod.verifyWithdrawalCredentialsAndBalance(oracleBlockNumber, validatorIndex, proofs, validatorFields);

        // Decrement the staked but not verified ETH
        uint64 validatorCurrentBalanceGwei =
            BeaconChainProofs.getBalanceFromBalanceRoot(validatorIndex, proofs.balanceRoot);

        uint256 gweiToWei = 1e9;
        stakedButNotVerifiedEth -= (validatorCurrentBalanceGwei * gweiToWei);
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyLRTManager {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /// @dev allow NodeDelegator to receive ETH
    function sendETHFromDepositPoolToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        address lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        if (msg.sender != lrtDepositPool) {
            revert InvalidETHSender();
        }

        emit ETHDepositFromDepositPool(msg.value);
    }

    /// @dev opts in for rebase so the asset's token balance will increase
    function optIn(address asset) external onlyLRTAdmin onlySupportedAsset(asset) {
        IOETH(asset).rebaseOptIn();
    }

    /// @dev allow NodeDelegator to receive ETH rewards
    receive() external payable {
        emit ETHRewardsReceived(msg.value);
    }
}
