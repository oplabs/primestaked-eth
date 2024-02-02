// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "../utils/UtilLib.sol";
import { IPriceFetcher } from "../interfaces/IPriceFetcher.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ISfrxETH {
    /// @notice How much frxETH is 1E18 sfrxETH worth. Price is in ETH, not USD
    function pricePerShare() external view returns (uint256);
}

interface IDualOracle {
    function getCurveEmaEthPerFrxEth() external view returns (uint256);
}

/// @title sfrxETHPriceOracle Contract
/// @notice contract that fetches the exchange rate of sfrxETH/ETH
contract SfrxETHPriceOracle is IPriceFetcher {
    address public immutable sfrxETHContractAddress;
    IDualOracle public immutable fraxDualOracle;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _sfrxETHContractAddress, address _fraxDualOracle) {
        sfrxETHContractAddress = _sfrxETHContractAddress;
        fraxDualOracle = IDualOracle(_fraxDualOracle);
    }

    /// @notice Fetches Asset/ETH exchange rate
    /// @param asset the asset for which exchange rate is required
    /// @return assetPrice exchange rate of asset
    function getAssetPrice(address asset) external view returns (uint256) {
        if (asset != sfrxETHContractAddress) {
            revert InvalidAsset();
        }

        return (ISfrxETH(sfrxETHContractAddress).pricePerShare() * fraxDualOracle.getCurveEmaEthPerFrxEth()) / 1e18;
    }
}
