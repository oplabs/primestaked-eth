// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { CrossChainRateProvider } from "./CrossChainRateProvider.sol";

import { ILRTOracle } from "../interfaces/ILRTOracle.sol";

/// @title primeETH cross chain rate provider
/// @notice Provides the current exchange rate of primeETH to a receiver contract on a different chain than the one this
/// contract is deployed on
contract PrimeStakedETHRateProvider is CrossChainRateProvider {
    address public primeETHPriceOracle;

    constructor(address _primeETHPriceOracle, uint16 _dstChainId, address _layerZeroEndpoint) {
        primeETHPriceOracle = _primeETHPriceOracle;

        rateInfo = RateInfo({
            tokenSymbol: "primeETH",
            tokenAddress: 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7, // primeETH token address on ETH mainnet
            baseTokenSymbol: "ETH",
            baseTokenAddress: address(0) // Address 0 for native tokens
         });
        dstChainId = _dstChainId;
        layerZeroEndpoint = _layerZeroEndpoint;
    }

    /// @notice Returns the latest rate from the primeETH contract
    function getLatestRate() public view override returns (uint256) {
        return ILRTOracle(primeETHPriceOracle).primeETHPrice();
    }
}
