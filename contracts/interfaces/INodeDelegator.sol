// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "./IStrategy.sol";

interface INodeDelegator {
    enum VALIDATOR_STATE {
        REGISTERED, // validator is registered on the SSV network
        STAKED, // validator has funds staked
        EXITING, // exit message has been posted and validator is in the process of exiting
        EXIT_COMPLETE // validator has funds withdrawn to the EigenPod and is removed from the SSV
    }

    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);
    event ETHRewardsClaimed(uint256 amount);
    event SSVValidatorRegistered(bytes publicKey, uint64[] operatorIds);
    event SSVValidatorExitInitiated(bytes publicKey, uint64[] operatorIds);
    event SSVValidatorExitCompleted(bytes publicKey, uint64[] operatorIds);

    // errors
    error TokenTransferFailed();
    error StrategyIsNotSetForAsset();
    error InvalidETHSender();
    error InsufficientWETH(uint256 balance);
    error ValidatorInUnexpectedState(bytes pubkey, VALIDATOR_STATE state);

    // methods
    function depositAssetIntoStrategy(address asset) external;
    function depositAssetsIntoStrategy(address[] calldata assets) external;

    function maxApproveToEigenStrategyManager(address asset) external;

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256 ndcAssets, uint256 eigenAssets);
}
