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
import { IDelayedWithdrawalRouter } from "./eigen/interfaces/IDelayedWithdrawalRouter.sol";
import { IEigenPodManager, IEigenPod } from "./eigen/interfaces/IEigenPodManager.sol";
import { ISignatureUtils } from "./eigen/interfaces/ISignatureUtils.sol";
import { IStrategyManager, IStrategy } from "./eigen/interfaces/IStrategyManager.sol";
import { INodeDelegatorETH } from "./interfaces/INodeDelegatorETH.sol";
import { ISSVNetwork, Cluster } from "./interfaces/ISSVNetwork.sol";
// import { IOETH } from "./interfaces/IOETH.sol";
import { IWETH } from "./interfaces/IWETH.sol";

struct ValidatorStakeData {
    bytes pubkey;
    bytes signature;
    bytes32 depositDataRoot;
}

/// @title NodeDelegatorETH Contract
/// @notice The contract that handles the depositing WETH into SSV validators
contract NodeDelegatorETH is
    INodeDelegatorETH,
    LRTConfigRoleChecker,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    /// @dev The Wrapped ETH (WETH) contract address with interface IWETH
    address public immutable WETH;

    /// @dev The EigenPod is created and owned by this contract
    address public eigenPod;
    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentials to verify the validator credentials on EigenLayer
    uint256 public stakedButNotVerifiedEth;

    uint256 internal constant DUST_AMOUNT = 10;
    uint256 public constant FULL_STAKE = 32 ether;
    uint256 public constant MIN_SLASHED_AMOUNT = 26 ether;

    mapping(bytes32 pubkeyHash => bool hasStaked) public validatorsStaked;

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

    function createEigenPod() external onlyLRTManager {
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPod = eigenPodManager.createPod();

        emit EigenPodCreated(eigenPod, address(this));
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
        if (asset == WETH) {
            uint256 ethBalance = address(this).balance;
            if (ethBalance > 0) {
                // Convert any ETH into WETH
                IWETH(WETH).deposit{ value: ethBalance }();
            }
        }

        bool success = IERC20(asset).transfer(lrtDepositPool, amount);

        if (!success) {
            revert TokenTransferFailed();
        }
    }

    /// @notice Fetches the balance of all supported assets in this contract and the underlying EigenLayer.
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

        // If an LST asset
        if (asset != WETH) {
            // LST can't be deposited into EigenLayer from this NodeDelegatorETH contract
            // so just return the LSTs in this contract if any.
            return (ndcAssets, eigenAssets);
        }
        // Every other asset is an LST

        // Add any ETH in the NDC that was earned from execution rewards
        ndcAssets += address(this).balance;

        eigenAssets += stakedButNotVerifiedEth;

        // Not getting ETH restaked into EigenLayer as that is not yet supported
        // by the NodeDelegatorETH.
        // The WETH asset will point to the EigenLayer beaconChainETHStrategy
        // 0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0

        // Not adding any consensus rewards that have been sent to the EigenPod.
        // This can include forced validator withdrawals so that needs to be accounted for
        // in a future implementation.
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
            uint256 wethBalance = IWETH(WETH).balanceOf(address(this));
            if (wethBalance + ethBalance < requiredETH) {
                revert InsufficientWETH(wethBalance + ethBalance);
            }
            // Convert WETH asset to native ETH
            IWETH(WETH).withdraw(requiredETH - ethBalance);
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

    /// @notice Delegates all staked assets from this contract to an EigenLayer Operator.
    /// This includes both both LSTs and native ETH.
    /// @param operator the address of the EigenLayer Operator to delegate to.
    function delegateTo(address operator) external onlyLRTManager {
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        delegationManager.delegateTo(
            operator, ISignatureUtils.SignatureWithExpiry({ signature: new bytes(0), expiry: 0 }), 0x0
        );

        emit Delegate(operator);
    }

    /// @notice Undelegates all staked LST assets from this contract from the
    /// previously delegated to EigenLayer Operator.
    /// This also forces a withdrawal so the assets will need to be claimed.
    function undelegate() external onlyLRTManager {
        address delegationManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager delegationManager = IDelegationManager(delegationManagerAddress);

        // Get the amount of strategy shares owned by this contract
        IStrategyManager strategyManager = IStrategyManager(lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER));

        // For each asset
        address[] memory assets = lrtConfig.getSupportedAssetList();
        for (uint256 i = 0; i < assets.length; ++i) {
            // Skip WETH as ETH restaked into EigenLayer is not yet supported by this NodeDelegatorETH contract.
            if (assets[i] == WETH) {
                continue;
            }

            // Get the EigenLayer strategy for the LST asset
            address strategy = lrtConfig.assetStrategy(assets[i]);

            uint256 strategyShares = strategyManager.stakerStrategyShares(address(this), IStrategy(strategy));
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

    /// @dev Initiates exits from validators in a SSV Cluster
    /// The staked ETH will eventually swept to the EigenPod.
    /// Only the Operator can call this function.
    /// @param publicKeys Array of validator public keys
    /// @param operatorIds The operator IDs of the SSV Cluster
    function exitSsvValidators(
        bytes[] calldata publicKeys,
        uint64[] calldata operatorIds
    )
        external
        onlyLRTOperator
        whenNotPaused
    {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).bulkExitValidator(publicKeys, operatorIds);
    }

    /// @dev Remove validators from the SSV Cluster.
    /// Make sure `exitSsvValidators` is called before and all the validators have exited the Beacon chain.
    /// If removed before the validator has exited the beacon chain will result in the validator being slashed.
    /// Only the Operator can call this function.
    /// @param publicKeys Array of validator public keys
    /// @param operatorIds The operator IDs of the SSV Cluster
    /// @param cluster The SSV cluster details including the validator count and SSV balance
    function removeSsvValidators(
        bytes[] calldata publicKeys,
        uint64[] calldata operatorIds,
        Cluster calldata cluster
    )
        external
        onlyLRTOperator
        whenNotPaused
    {
        address SSV_NETWORK_ADDRESS = lrtConfig.getContract(LRTConstants.SSV_NETWORK);

        ISSVNetwork(SSV_NETWORK_ADDRESS).bulkRemoveValidator(publicKeys, operatorIds, cluster);
    }

    /// @dev Withdraw all ether in the EigenPod which can be from beacon consensus rewards or validator exits.
    /// The ether will be sent to the EigenLayer's DelayedWithdrawalRouter contract where it can be claimed after seven
    /// days.
    function requestEthWithdrawal() external onlyLRTOperator {
        if (eigenPod == address(0)) {
            revert NoEigenPod();
        }
        IEigenPod(eigenPod).withdrawBeforeRestaking();
    }

    /// @dev Claim previously requested ether withdrawals from EigenLayer's DelayedWithdrawalRouter contract.
    /// Need to account if the ether is from validator exits or beacon chain consensus rewards.
    function claimEthWithdrawal() external onlyLRTOperator {
        uint256 ethBefore = address(this).balance;

        address delayerWithdrawalRouter = lrtConfig.getContract(LRTConstants.EIGEN_DELAYED_WITHDRAWAL_ROUTER);
        // Only claim one withdrawal request at a time to make the accounting easier
        IDelayedWithdrawalRouter(delayerWithdrawalRouter).claimDelayedWithdrawals(1);

        uint256 ethClaimed = address(this).balance - ethBefore;

        uint256 fullyWithdrawnValidators;
        // Account for the claimed ether
        if (ethClaimed >= FULL_STAKE) {
            // explicitly cast to uint256 as we want to round to a whole number of validators
            fullyWithdrawnValidators = uint256(ethClaimed / FULL_STAKE);
            stakedButNotVerifiedEth -= fullyWithdrawnValidators * FULL_STAKE;

            emit WithdrawnValidators(fullyWithdrawnValidators, stakedButNotVerifiedEth);
        }

        uint256 ethRemaining = ethClaimed - fullyWithdrawnValidators * FULL_STAKE;
        // should be less than a whole validator stake
        require(ethRemaining < FULL_STAKE, "Unexpected accounting");

        // If no Beacon chain consensus rewards swept
        if (ethRemaining == 0) {
            // do nothing
        } else if (ethRemaining < MIN_SLASHED_AMOUNT) {
            // Beacon chain consensus rewards swept (partial validator withdrawals)
            emit ConsensusRewards(ethRemaining);
        } else {
            // Beacon chain consensus rewards swept but also a slashed validator fully exited
            stakedButNotVerifiedEth -= FULL_STAKE;
            emit SlashedValidator(ethRemaining, stakedButNotVerifiedEth);
        }
    }

    /// @dev allow NodeDelegatorETH to receive execution rewards from MEV and
    /// ETH from WETH withdrawals.
    /// Is not required to receive consensus rewards from the BeaconChain.
    receive() external payable { }
}
