// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { IDelegationManager } from "../eigen/interfaces/IDelegationManager.sol";

interface INodeDelegator {
    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);
    event ETHRewardsClaimed(uint256 amount);

    // errors
    error TokenTransferFailed(); // 0x045c4b02
    error StrategyIsNotSetForAsset(); // 0x615c938
    error InvalidETHSender(); // 0xe811a0c2
    error InsufficientWETH(uint256 balance); // 0x2ed796b4
    error ValidatorAlreadyStaked(bytes pubkey); // 0x2229546d
    error StakersWithdrawalNotFound(); // 0x0110c83d
    error NotInternalWithdrawal(); // 0xb1345ad5
    error NotSingleStrategyWithdrawal(); // 0xc18ea890

    // methods
    function depositAssetIntoStrategy(address asset) external;
    function depositAssetsIntoStrategy(address[] calldata assets) external;

    function requestWithdrawal(address strategyAddress, uint256 strategyShares, address staker) external;
    function requestInternalWithdrawal(address strategyAddress, uint256 strategyShares) external;
    function claimWithdrawal(
        address asset,
        IDelegationManager.Withdrawal calldata withdrawal,
        address staker
    )
        external
        returns (uint256 assets);
    function claimInternalWithdrawal(
        address asset,
        IDelegationManager.Withdrawal calldata withdrawal
    )
        external
        returns (uint256 assets);

    function maxApproveToEigenStrategyManager(address asset) external;

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256 ndcAssets, uint256 eigenAssets);
}
