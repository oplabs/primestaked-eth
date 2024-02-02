// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "../utils/UtilLib.sol";
import { IPriceFetcher } from "../interfaces/IPriceFetcher.sol";

/// @title OneETHPriceOracle Contract
/// @notice contract that returns 1e18 as the exchange rate of asset/ETH
contract OneETHPriceOracle is IPriceFetcher {
    /// @return assetPrice 1e18 as the exchange rate of asset/ETH
    function getAssetPrice(address) external view virtual returns (uint256) {
        return 1e18;
    }
}
