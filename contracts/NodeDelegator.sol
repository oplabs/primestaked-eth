// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";
import { IEigenStrategyManager } from "./interfaces/IEigenStrategyManager.sol";
import { IOETH } from "./interfaces/IOETH.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { ISSVNetwork, Cluster } from "./interfaces/ISSVNetwork.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IEigenPodManager } from "./interfaces/IEigenPodManager.sol";
import { IEigenPod } from "./interfaces/IEigenPod.sol";

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
    IEigenPod public eigenPod;
    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentials to verify the validator credentials on EigenLayer
    uint256 public stakedButNotVerifiedEth;

    uint256 internal constant DUST_AMOUNT = 10;
    mapping(bytes32 pubkeyHash => bool hasStaked) public validatorsStaked;

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
    /// @param asset the token address of the asset.
    /// WETH will include any native ETH in this contract or staked in EigenLayer.
    /// @return ndcAssets assets lying in this NDC contract.
    /// This includes any native ETH when the asset is WETH.
    /// @return eigenAssets asset amount deposited in underlying EigenLayer strategy
    /// or native ETH staked into an EigenPod.
    function getAssetBalance(address asset) public view override returns (uint256 ndcAssets, uint256 eigenAssets) {
        ndcAssets += IERC20(asset).balanceOf(address(this));

        if (asset == WETH_TOKEN_ADDRESS) {
            // Add any ETH in the NDC that was earned from EigenLayer
            ndcAssets += address(this).balance;

            eigenAssets = stakedButNotVerifiedEth;
        } else {
            address strategy = lrtConfig.assetStrategy(asset);
            if (strategy != address(0)) {
                eigenAssets = IStrategy(strategy).userUnderlyingView(address(this));
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

    /// @dev allow NodeDelegator to receive ETH rewards
    receive() external payable { }
}
