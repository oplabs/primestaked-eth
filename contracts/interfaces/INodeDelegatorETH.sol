// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { IDelegationManager } from "../eigen/interfaces/IDelegationManager.sol";
import { Cluster } from "./ISSVNetwork.sol";

interface INodeDelegatorETH {
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event Delegate(address indexed operator);
    event Undelegate(address indexed strategy, uint256 strategyShares);
    event ConsensusRewards(uint256 amount);
    event WithdrawnValidators(uint256 fullyWithdrawnValidators, uint256 stakedButNotVerifiedEth);
    event SlashedValidator(uint256 slashedAmount, uint256 stakedButNotVerifiedEth);

    // errors
    error TokenTransferFailed(); // 0x045c4b02
    error InvalidETHSender(); // 0xe811a0c2
    error InsufficientWETH(uint256 balance); // 0x2ed796b4
    error ValidatorAlreadyStaked(bytes pubkey); // 0x2229546d
    error NoEigenPod(); // 5dd90f17

    function exitSsvValidators(bytes[] calldata publicKeys, uint64[] calldata operatorIds) external;
    function removeSsvValidators(
        bytes[] calldata publicKeys,
        uint64[] calldata operatorIds,
        Cluster calldata cluster
    )
        external;

    function requestEthWithdrawal() external;
    function claimEthWithdrawal() external;

    // function maxApproveToEigenStrategyManager(address asset) external;

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256 ndcAssets, uint256 eigenAssets);

    function delegateTo(address operator) external;
    function undelegate() external;

    function depositSSV(uint64[] memory operatorIds, uint256 amount, Cluster memory cluster) external;
    function withdrawSSV(uint64[] memory operatorIds, uint256 amount, Cluster memory cluster) external;
}
