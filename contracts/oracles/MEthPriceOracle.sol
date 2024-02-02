// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { OneETHPriceOracle } from "./OneETHPriceOracle.sol";

interface IMEthStaking {
    function mETHToETH(uint256) external view returns (uint256);
}

/// @title METHPriceOracle Contract
/// @notice contract that returns value as the exchange rate of asset/ETH
contract MEthPriceOracle is OneETHPriceOracle {
    address public immutable mEthAddress;
    IMEthStaking public immutable mEthStaking;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _mEthAddress, address _mEthStaking) {
        mEthAddress = _mEthAddress;
        mEthStaking = IMEthStaking(_mEthStaking);
    }

    /// @return assetPrice value as the exchange rate of asset/ETH
    function getAssetPrice(address asset) external view override returns (uint256) {
        if (asset != mEthAddress) {
            revert InvalidAsset();
        }

        return mEthStaking.mETHToETH(1 ether);
    }
}
