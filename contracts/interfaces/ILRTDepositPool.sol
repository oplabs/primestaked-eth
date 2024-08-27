// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { IDelegationManager } from "../eigen/interfaces/IDelegationManager.sol";

interface ILRTDepositPool {
    //errors
    error TokenTransferFailed(); // 0x045c4b02
    error InvalidAmountToDeposit(); // 0x91c6ba02
    error NotEnoughAssetToTransfer(); // 0x21d9b3bb
    error MaximumDepositLimitReached(); // 0x1751ef83
    error MaximumNodeDelegatorLimitReached(); // 0x9aca5e24
    error InvalidMaximumNodeDelegatorLimit(); // 0xe1a3dd92
    error MinimumAmountToReceiveNotMet(); // 0x1ec9a894
    error NodeDelegatorNotFound(); // 0xa5cddd8f
    error NodeDelegatorHasAssetBalance(address assetAddress, uint256 assetBalance); // 0xef008f08
    error ZeroAmount(); // 0x1f2a2005
    error MaxBurnAmount(); // 0x711d466b
    error NotWithdrawAsset(); // 0xfaf6a48f

    //events
    event MaxNodeDelegatorLimitUpdated(uint256 maxNodeDelegatorLimit);
    event NodeDelegatorAddedInQueue(address[] nodeDelegatorContracts);
    event NodeDelegatorRemovedFromQueue(address nodeDelegatorContracts);
    event AssetDeposit(
        address indexed depositor,
        address indexed asset,
        uint256 depositAmount,
        uint256 primeEthMintAmount,
        string referralId
    );
    event ETHDeposit(address indexed depositor, uint256 depositAmount, uint256 primeEthMintAmount, string referralId);
    event MinAmountToDepositUpdated(uint256 minAmountToDeposit);
    event AssetSwapped(
        address indexed fromAsset, address indexed toAsset, uint256 fromAssetAmount, uint256 toAssetAmount
    );
    event WithdrawalRequested(
        address indexed withdrawer,
        address indexed asset,
        address indexed strategy,
        uint256 primeETHAmount,
        uint256 assetAmount,
        uint256 sharesAmount
    );
    event WithdrawalClaimed(address indexed withdrawer, address indexed asset, uint256 assets);

    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minPrimeETHAmount,
        string calldata referralId
    )
        external;

    function requestWithdrawal(
        address asset,
        uint256 assetAmount,
        uint256 maxPrimeETH
    )
        external
        returns (uint256 primeETHAmount);

    function claimWithdrawal(
        IDelegationManager.Withdrawal calldata withdrawal
    )
        external
        returns (address asset, uint256 assets);

    function claimWithdrawalYn(
        IDelegationManager.Withdrawal calldata withdrawal
    )
        external
        returns (uint256 ynLSDeAmount);

    function getTotalAssetDeposits(address asset) external view returns (uint256);

    function getAssetCurrentLimit(address asset) external view returns (uint256);

    function getMintAmount(address asset, uint256 depositAmount) external view returns (uint256);

    function addNodeDelegatorContractToQueue(address[] calldata nodeDelegatorContract) external;

    function transferAssetToNodeDelegator(uint256 ndcIndex, address asset, uint256 amount) external;
    function transferAssetsToNodeDelegator(uint256 ndcIndex, address[] calldata assets) external;

    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit) external;

    function getNodeDelegatorQueue() external view returns (address[] memory);

    function getAssetDistributionData(
        address asset
    )
        external
        view
        returns (uint256 depositPoolAssets, uint256 ndcAssets, uint256 eigenAssets);

    function optIn(address asset) external;
}
