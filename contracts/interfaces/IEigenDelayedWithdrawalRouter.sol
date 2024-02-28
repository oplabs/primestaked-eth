// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

interface IEigenDelayedWithdrawalRouter {
    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim) external;
}
