// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { CrossChainRateProvider } from "./CrossChainRateProvider.sol";

import { ILRTOracle } from "../interfaces/ILRTOracle.sol";
import { Addresses } from "../utils/Addresses.sol";

/// @title primeETH cross chain rate provider
/// @notice Provides the current exchange rate of primeETH to a receiver contract on a different chain than the one this
/// contract is deployed on
contract PrimeStakedETHRateProvider is CrossChainRateProvider {
    address public primeETHPriceOracle;

    constructor(address _primeETHPriceOracle, uint16 _dstChainId, address _layerZeroEndpoint) {
        primeETHPriceOracle = _primeETHPriceOracle;

        rateInfo = RateInfo({
            tokenSymbol: "primeETH",
            tokenAddress: Addresses.PRIME_STAKED_ETH, // primeETH token address on ETH mainnet
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
