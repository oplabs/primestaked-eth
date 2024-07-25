// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { IDelegationManager } from "./eigen/interfaces/IDelegationManager.sol";
import { IStrategy } from "./eigen/interfaces/IStrategy.sol";
import { IPrimeETH } from "./interfaces/IPrimeETH.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { INodeDelegatorLST } from "./interfaces/INodeDelegatorLST.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IynEigen } from "./interfaces/IynEigen.sol";
import { IOETH } from "./interfaces/IOETH.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title LRTDepositPool - Deposit Pool Contract for LSTs
/// @notice Handles LST asset deposits
contract LRTDepositPool is ILRTDepositPool, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    // The NodeDelegator index to request LST withdrawals from. eg OETH
    uint256 public constant LST_NDC_INDEX = 0;

    address public immutable WETH;
    address public immutable WITHDRAW_ASSET;

    /// @notice Wrapped OETH (wOETH)
    address public immutable wOETH;
    // Yield Nest's EigenLayer vault for ETH (ynLSDe)
    address public immutable ynLSDe;

    uint256 public maxNodeDelegatorLimit;
    uint256 public minAmountToDeposit;

    mapping(address => uint256) public isNodeDelegator; // 0: not a node delegator, 1: is a node delegator
    address[] public nodeDelegatorQueue;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _weth, address _withdrawAsset, address _wOETH, address _ynLSDe) {
        UtilLib.checkNonZeroAddress(_weth);
        UtilLib.checkNonZeroAddress(_withdrawAsset);
        WETH = _weth;
        WITHDRAW_ASSET = _withdrawAsset;
        wOETH = _wOETH;
        ynLSDe = _ynLSDe;

        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __Pausable_init();
        __ReentrancyGuard_init();
        maxNodeDelegatorLimit = 10;
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice gets the total asset present in protocol
    /// @param asset Asset address
    /// @return totalAssetDeposit total asset present in protocol
    function getTotalAssetDeposits(address asset) public view override returns (uint256 totalAssetDeposit) {
        (uint256 depositPoolAssets, uint256 ndcAssets, uint256 eigenAssets) = getAssetDistributionData(asset);
        return (depositPoolAssets + ndcAssets + eigenAssets);
    }

    /// @notice gets the current limit of asset deposit
    /// @param asset Asset address
    /// @return currentLimit Current limit of asset deposit
    function getAssetCurrentLimit(address asset) public view override returns (uint256) {
        if (getTotalAssetDeposits(asset) > lrtConfig.depositLimitByAsset(asset)) {
            return 0;
        }

        return lrtConfig.depositLimitByAsset(asset) - getTotalAssetDeposits(asset);
    }

    /// @dev get node delegator queue
    /// @return nodeDelegatorQueue Array of node delegator contract addresses
    function getNodeDelegatorQueue() external view override returns (address[] memory) {
        return nodeDelegatorQueue;
    }

    /// @dev provides asset amount distribution data among depositPool, NDCs and EigenLayer
    /// @param asset the asset to get the total amount of
    /// @return depositPoolAssets asset amount lying in this LRTDepositPool contract
    /// @return ndcAssets asset amount sum lying in all NDC contracts.
    /// This includes any native ETH when the asset is WETH.
    /// @return eigenAssets asset amount deposited in EigenLayer through all NDCs.
    /// This is either LSTs in EigenLayer strategies or native ETH managed by EigenLayer pods.
    function getAssetDistributionData(address asset)
        public
        view
        override
        onlySupportedAsset(asset)
        returns (uint256 depositPoolAssets, uint256 ndcAssets, uint256 eigenAssets)
    {
        depositPoolAssets = IERC20(asset).balanceOf(address(this));

        uint256 ndcsCount = nodeDelegatorQueue.length;
        for (uint256 i; i < ndcsCount;) {
            (uint256 _ndcAssets, uint256 _eigenAssets) = INodeDelegatorLST(nodeDelegatorQueue[i]).getAssetBalance(asset);
            ndcAssets += _ndcAssets;
            eigenAssets += _eigenAssets;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice View amount of primeETH to mint for given asset amount
    /// @param asset Asset address
    /// @param amount Asset amount
    /// @return primeEthAmount Amount of primeETH to mint
    function getMintAmount(address asset, uint256 amount) public view override returns (uint256 primeEthAmount) {
        // setup oracle contract
        address lrtOracleAddress = lrtConfig.getContract(LRTConstants.LRT_ORACLE);
        ILRTOracle lrtOracle = ILRTOracle(lrtOracleAddress);

        // calculate primeETH amount to mint based on asset amount and asset exchange rate
        primeEthAmount = (amount * lrtOracle.getAssetPrice(asset)) / lrtOracle.primeETHPrice();
    }

    /*//////////////////////////////////////////////////////////////
                        Deposit functions
    //////////////////////////////////////////////////////////////*/

    /// @notice helps user stake LST to the protocol
    /// @param asset LST asset address to stake
    /// @param depositAmount LST asset amount to stake
    /// @param minPrimeETH Minimum amount of primeETH to receive
    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minPrimeETH,
        string calldata referralId
    )
        external
        whenNotPaused
        nonReentrant
        onlySupportedAsset(asset)
    {
        // checks
        uint256 primeETHAmount = _beforeDeposit(asset, depositAmount, minPrimeETH);

        // interactions
        if (!IERC20(asset).transferFrom(msg.sender, address(this), depositAmount)) {
            revert TokenTransferFailed();
        }
        _mint(primeETHAmount);

        emit AssetDeposit(msg.sender, asset, depositAmount, primeETHAmount, referralId);
    }

    function _beforeDeposit(
        address asset,
        uint256 depositAmount,
        uint256 minPrimeETH
    )
        private
        view
        returns (uint256 primeETHAmount)
    {
        if (depositAmount == 0 || depositAmount < minAmountToDeposit) {
            revert InvalidAmountToDeposit();
        }

        if (depositAmount > getAssetCurrentLimit(asset)) {
            revert MaximumDepositLimitReached();
        }
        primeETHAmount = getMintAmount(asset, depositAmount);

        if (primeETHAmount < minPrimeETH) {
            revert MinimumAmountToReceiveNotMet();
        }
    }

    /// @dev private function to mint primeETH
    /// @param amount Amount of primeETH to be minted
    function _mint(uint256 amount) private {
        address primeETH = lrtConfig.primeETH();
        // mint primeETH for user
        IPrimeETH(primeETH).mint(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        Withdraw functions
    //////////////////////////////////////////////////////////////*/

    /// @notice PrimeETH staker requests the withdrawal of OETH from its underlying EigenLayer strategy.
    /// @dev Will emit the `Withdrawal` event from EigenLayer's `DelegationManager` contract
    /// which is needed for the `claimWithdrawal` call.
    /// @param asset address of the liquid staking token (LST) being requested. Only OETH us supported. Can not be WETH.
    /// @param assetAmount the amount of LSTs to withdraw.
    /// @param maxPrimeETH the maximum amount of primeETH tokens that can be burned.
    /// @return primeETHAmount the amount of primeETH tokens that were burned.
    function requestWithdrawal(
        address asset,
        uint256 assetAmount,
        uint256 maxPrimeETH
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256 primeETHAmount)
    {
        if (assetAmount == 0) {
            revert ZeroAmount();
        }

        // Can only withdraw the supported asset
        if (asset != WITHDRAW_ASSET) {
            revert NotWithdrawAsset();
        }

        // Convert asset amount to primeETH amount.
        // Using mint function here even though it's a withdrawal as it does the same calculation.
        // We round up the primeETH amount for withdrawals as the the divide by the primeETH exchange rate will truncate
        // down.
        primeETHAmount = getMintAmount(asset, assetAmount) + 1;

        // Check the primeETH amount to be burned is within the maximum allowed
        if (primeETHAmount > maxPrimeETH) {
            revert MaxBurnAmount();
        }

        // burn primeETH from the staker
        address primeETH = lrtConfig.primeETH();
        IPrimeETH(primeETH).burnFrom(msg.sender, primeETHAmount);

        // Get the NodeDelegator contract to request the withdrawal from
        address nodeDelegator = nodeDelegatorQueue[LST_NDC_INDEX];

        // Calculate the strategy shares for the requested assets
        address strategyAddress = lrtConfig.assetStrategy(asset);
        uint256 strategyShares = IStrategy(strategyAddress).underlyingToShares(assetAmount);

        INodeDelegatorLST(nodeDelegator).requestWithdrawal(strategyAddress, strategyShares, msg.sender);

        emit WithdrawalRequested(msg.sender, asset, strategyAddress, primeETHAmount, assetAmount, strategyShares);
    }

    /// @notice PrimeETH staker claims the withdrawal of their previously requested OETH.
    /// Must wait `minWithdrawalDelayBlocks` on EigenLayer's `DelegationManager` contract
    /// before claiming the withdrawal.
    /// This is currently set to 50,400 blocks (7 days) on mainnet. 10 blocks on Holesky.
    /// @dev The asset is validated against the withdrawal strategy in EigenLayer's `StrategyBase`.
    /// @return asset the address of the LST that was withdrawn
    /// @return assets the amount of LSTs received from the withdrawal
    function claimWithdrawal(IDelegationManager.Withdrawal calldata withdrawal)
        external
        whenNotPaused
        nonReentrant
        returns (address asset, uint256 assets)
    {
        // Get the NodeDelegator contract to request the withdrawal from
        address nodeDelegator = nodeDelegatorQueue[LST_NDC_INDEX];

        // Claim the withdrawal from the NodeDelegator
        (asset, assets) = INodeDelegatorLST(nodeDelegator).claimWithdrawal(withdrawal, msg.sender, msg.sender);

        emit WithdrawalClaimed(msg.sender, asset, assets);
    }

    /// @notice PrimeETH staker claims the withdrawal of their previously requested OETH
    /// but instead of receiving OETH, the OETH is deposited into Yield Nest and the withdrawer receives ynLSDe tokens.
    /// Must wait `minWithdrawalDelayBlocks` on EigenLayer's `DelegationManager` contract
    /// before claiming the withdrawal.
    /// This is currently set to 50,400 blocks (7 days) on mainnet. 10 blocks on Holesky.
    /// @dev The asset is validated against the withdrawal strategy in EigenLayer's `StrategyBase`.
    /// @return ynLSDeAmount the amount of ynLSDe tokens received after OETH is deposited into Yield Nest
    function claimWithdrawalYn(IDelegationManager.Withdrawal calldata withdrawal)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 ynLSDeAmount)
    {
        // Get the NodeDelegatorLST contract to request the withdrawal from
        address nodeDelegator = nodeDelegatorQueue[LST_NDC_INDEX];

        // Claim the withdrawal of OETH from the NodeDelegatorLST
        (, uint256 oethAmount) = INodeDelegatorLST(nodeDelegator).claimWithdrawal(withdrawal, msg.sender, address(this));

        // Convert to Wrapped OETH (wOETH)
        // Approve the wOETH to spend the OETH
        IERC20(WITHDRAW_ASSET).approve(wOETH, oethAmount);
        uint256 woethAmount = IERC4626(wOETH).deposit(oethAmount, address(this));

        // Approve the ynEigen to spend the wOETH
        IERC20(wOETH).approve(ynLSDe, woethAmount);

        // Deposit the wOETH into Yield Nest's LSD vault and receive ynLSDe tokens
        uint256 ynLSDeAmount = IynEigen(ynLSDe).deposit(IERC20(wOETH), woethAmount, msg.sender);

        emit WithdrawalClaimed(msg.sender, ynLSDe, ynLSDeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        Admin functions
    //////////////////////////////////////////////////////////////*/

    /// @notice add new node delegator contract addresses
    /// @dev only callable by LRT admin
    /// @param nodeDelegatorContracts Array of NodeDelegator contract addresses
    function addNodeDelegatorContractToQueue(address[] calldata nodeDelegatorContracts) external onlyLRTAdmin {
        uint256 length = nodeDelegatorContracts.length;
        if (nodeDelegatorQueue.length + length > maxNodeDelegatorLimit) {
            revert MaximumNodeDelegatorLimitReached();
        }

        for (uint256 i; i < length;) {
            UtilLib.checkNonZeroAddress(nodeDelegatorContracts[i]);

            // check if node delegator contract is already added and add it if not
            if (isNodeDelegator[nodeDelegatorContracts[i]] == 0) {
                nodeDelegatorQueue.push(nodeDelegatorContracts[i]);
            }

            isNodeDelegator[nodeDelegatorContracts[i]] = 1;

            unchecked {
                ++i;
            }
        }

        emit NodeDelegatorAddedInQueue(nodeDelegatorContracts);
    }

    /// @notice remove node delegator contract address from queue
    /// @dev only callable by LRT admin
    /// @param nodeDelegatorAddress NodeDelegator contract address
    function removeNodeDelegatorContractFromQueue(address nodeDelegatorAddress) public onlyLRTAdmin {
        // revert if node delegator contract has assets lying in it or it has asset in EigenLayer asset strategies
        (address[] memory assets, uint256[] memory assetBalances) =
            INodeDelegatorLST(nodeDelegatorAddress).getAssetBalances();

        uint256 assetsLength = assets.length;
        for (uint256 i; i < assetsLength;) {
            if (assetBalances[i] > 0) {
                revert NodeDelegatorHasAssetBalance(assets[i], assetBalances[i]);
            }

            unchecked {
                ++i;
            }
        }

        uint256 length = nodeDelegatorQueue.length;
        uint256 ndcIndex;

        for (uint256 i; i < length;) {
            if (nodeDelegatorQueue[i] == nodeDelegatorAddress) {
                ndcIndex = i;
                break;
            }

            if (i == length - 1) {
                revert NodeDelegatorNotFound();
            }

            unchecked {
                ++i;
            }
        }

        // remove node delegator contract from queue
        nodeDelegatorQueue[ndcIndex] = nodeDelegatorQueue[length - 1];
        nodeDelegatorQueue.pop();

        isNodeDelegator[nodeDelegatorAddress] = 0;

        emit NodeDelegatorRemovedFromQueue(nodeDelegatorAddress);
    }

    /// @notice remove many node delegator contracts from queue
    /// @dev calls internally removeNodeDelegatorContractFromQueue which is only callable by LRT admin
    /// @param nodeDelegatorContracts Array of NodeDelegator contract addresses
    function removeManyNodeDelegatorContractsFromQueue(address[] calldata nodeDelegatorContracts)
        external
        onlyLRTAdmin
    {
        uint256 length = nodeDelegatorContracts.length;

        for (uint256 i; i < length;) {
            removeNodeDelegatorContractFromQueue(nodeDelegatorContracts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice transfers asset lying in this DepositPool to node delegator contract
    /// @dev only callable by LRT manager
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param asset Asset address
    /// @param amount Asset amount to transfer
    function transferAssetToNodeDelegator(
        uint256 ndcIndex,
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        onlyLRTOperator
        onlySupportedAsset(asset)
    {
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        UtilLib.checkNonZeroAddress(nodeDelegator);

        if (!IERC20(asset).transfer(nodeDelegator, amount)) {
            revert TokenTransferFailed();
        }
    }

    /// @notice Transfers all specified assets lying in this DepositPool to a node delegator
    /// @dev only callable by LRT Manager
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue starting at zero.
    /// @param assets List of asset addresses
    function transferAssetsToNodeDelegator(
        uint256 ndcIndex,
        address[] calldata assets
    )
        external
        override
        nonReentrant
        onlyLRTOperator
    {
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        UtilLib.checkNonZeroAddress(nodeDelegator);

        // For each of the specified assets
        for (uint256 i; i < assets.length;) {
            // Check the asset is supported
            if (!lrtConfig.isSupportedAsset(assets[i])) {
                revert ILRTConfig.AssetNotSupported();
            }

            // Get the asset's balance held by this contract
            uint256 amount = IERC20(assets[i]).balanceOf(address(this));

            // If something to transfer
            if (amount > 0) {
                // Transfer the asset to the node delegator
                if (!IERC20(assets[i]).transfer(nodeDelegator, amount)) {
                    revert TokenTransferFailed();
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice swap assets that are accepted by LRTDepositPool
    /// @dev use LRTOracle to get price for fromToken to toToken. Only callable by LRT manager
    /// @param fromAsset Asset address to swap from
    /// @param toAsset Asset address to swap to
    /// @param fromAssetAmount Asset amount to swap from
    /// @param minToAssetAmount Minimum asset amount to swap to

    function swapAssetWithinDepositPool(
        address fromAsset,
        address toAsset,
        uint256 fromAssetAmount,
        uint256 minToAssetAmount
    )
        external
        onlyLRTManager
        onlySupportedAsset(fromAsset)
        onlySupportedAsset(toAsset)
    {
        // checks
        uint256 toAssetAmount = getSwapAssetReturnAmount(fromAsset, toAsset, fromAssetAmount);
        if (toAssetAmount < minToAssetAmount || IERC20(toAsset).balanceOf(address(this)) < toAssetAmount) {
            revert NotEnoughAssetToTransfer();
        }

        // interactions
        IERC20(fromAsset).transferFrom(msg.sender, address(this), fromAssetAmount);

        IERC20(toAsset).transfer(msg.sender, toAssetAmount);

        emit AssetSwapped(fromAsset, toAsset, fromAssetAmount, toAssetAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice get return amount for swapping assets that are accepted by LRTDepositPool
    /// @dev use LRTOracle to get price for fromToken to toToken
    /// @param fromAsset Asset address to swap from
    /// @param toAsset Asset address to swap to
    /// @param fromAssetAmount Asset amount to swap from
    /// @return returnAmount Return amount of toAsset
    function getSwapAssetReturnAmount(
        address fromAsset,
        address toAsset,
        uint256 fromAssetAmount
    )
        public
        view
        returns (uint256 returnAmount)
    {
        address lrtOracleAddress = lrtConfig.getContract(LRTConstants.LRT_ORACLE);
        ILRTOracle lrtOracle = ILRTOracle(lrtOracleAddress);

        return lrtOracle.getAssetPrice(fromAsset) * fromAssetAmount / lrtOracle.getAssetPrice(toAsset);
    }

    /*//////////////////////////////////////////////////////////////
                        Governance functions
    //////////////////////////////////////////////////////////////*/

    /// @notice update max node delegator count
    /// @dev only callable by LRT admin
    /// @param maxNodeDelegatorLimit_ Maximum count of node delegator
    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit_) external onlyLRTAdmin {
        if (maxNodeDelegatorLimit_ < nodeDelegatorQueue.length) {
            revert InvalidMaximumNodeDelegatorLimit();
        }

        maxNodeDelegatorLimit = maxNodeDelegatorLimit_;
        emit MaxNodeDelegatorLimitUpdated(maxNodeDelegatorLimit);
    }

    /// @notice update min amount to deposit
    /// @dev only callable by LRT admin
    /// @param minAmountToDeposit_ Minimum amount to deposit
    function setMinAmountToDeposit(uint256 minAmountToDeposit_) external onlyLRTAdmin {
        minAmountToDeposit = minAmountToDeposit_;
        emit MinAmountToDepositUpdated(minAmountToDeposit_);
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
}
