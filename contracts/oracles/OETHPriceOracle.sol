// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { OneETHPriceOracle } from "./OneETHPriceOracle.sol";

/// @title OETHPriceOracle Contract
/// @notice contract that returns 1e18 as the exchange rate of asset/ETH
contract OETHPriceOracle is OneETHPriceOracle {
    address public immutable oethAddress;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _oethAddress) {
        oethAddress = _oethAddress;
    }

    /// @return assetPrice 1e18 as the exchange rate of asset/ETH
    function getAssetPrice(address asset) external view override returns (uint256) {
        if (asset != oethAddress) {
            revert InvalidAsset();
        }

        return 1e18;
    }
}
