// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { OneETHPriceOracle } from "./OneETHPriceOracle.sol";

/// @title WETHPriceOracle Contract
/// @notice contract that returns 1e18 as the exchange rate of asset/ETH
contract WETHPriceOracle is OneETHPriceOracle {
    address public immutable wethAddress;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _wethAddress) {
        wethAddress = _wethAddress;
    }

    /// @return assetPrice 1e18 as the exchange rate of asset/ETH
    function getAssetPrice(address asset) external view override returns (uint256) {
        if (asset != wethAddress) {
            revert InvalidAsset();
        }

        return 1e18;
    }
}
