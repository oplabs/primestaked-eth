// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IDelegationManager } from "contracts/eigen/interfaces/IDelegationManager.sol";

contract MockNodeDelegator {
    address[] public assets;
    uint256[] public assetBalances;

    constructor(address[] memory _assets, uint256[] memory _assetBalances) {
        assets = _assets;
        assetBalances = _assetBalances;
    }

    function getAssetBalance(
        address
    )
        external
        pure
        returns (uint256 assetLyingInNDC, uint256 assetStakedInEigenLayer)
    {
        assetLyingInNDC = 0;
        assetStakedInEigenLayer = 1e18;
    }

    function getAssetBalances() external view returns (address[] memory, uint256[] memory) {
        return (assets, assetBalances);
    }

    function removeAssetBalance() external {
        assetBalances[0] = 0;
        assetBalances[1] = 0;
    }

    function requestWithdrawal(address strategyAddress, uint256 strategyShares, address staker) external { }
    function claimWithdrawal(
        IDelegationManager.Withdrawal calldata withdrawal,
        address staker,
        address receiver
    )
        external
        returns (address asset, uint256 assets)
    { }
}
