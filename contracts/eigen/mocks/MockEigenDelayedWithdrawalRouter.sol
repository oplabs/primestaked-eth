// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

contract MockEigenDelayedWithdrawalRouter {
    struct DelayedWithdrawal {
        uint224 amount;
        uint32 blockCreated;
    }

    function getUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory) { }
    function createDelayedWithdrawal(address podOwner, address recipient) external payable { }
    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim) external { }
}