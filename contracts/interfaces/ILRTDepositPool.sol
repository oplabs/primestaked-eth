// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

interface ILRTDepositPool {
    //errors
    error TokenTransferFailed();
    error InvalidAmountToDeposit();
    error NotEnoughAssetToTransfer();
    error MaximumDepositLimitReached();
    error MaximumNodeDelegatorLimitReached();
    error InvalidMaximumNodeDelegatorLimit();
    error MinimumAmountToReceiveNotMet();
    error NodeDelegatorNotFound();
    error NodeDelegatorHasAssetBalance(address assetAddress, uint256 assetBalance);

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

    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minPrimeETHAmount,
        string calldata referralId
    )
        external;

    function getTotalAssetDeposits(address asset) external view returns (uint256);

    function getAssetCurrentLimit(address asset) external view returns (uint256);

    function getMintAmount(address asset, uint256 depositAmount) external view returns (uint256);

    function addNodeDelegatorContractToQueue(address[] calldata nodeDelegatorContract) external;

    function transferAssetToNodeDelegator(uint256 ndcIndex, address asset, uint256 amount) external;
    function transferAssetsToNodeDelegator(uint256 ndcIndex, address[] calldata assets) external;

    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit) external;

    function getNodeDelegatorQueue() external view returns (address[] memory);

    function getAssetDistributionData(address asset)
        external
        view
        returns (uint256 depositPoolAssets, uint256 ndcAssets, uint256 eigenAssets);
}
