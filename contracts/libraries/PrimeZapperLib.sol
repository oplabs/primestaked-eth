// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";
import { Addresses, AddressesGoerli, AddressesHolesky } from "contracts/utils/Addresses.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";

library PrimeZapperLib {
    function deploy() internal returns (address contractAddress) {
        address primeEthAddress = block.chainid == 1 ? Addresses.PRIME_STAKED_ETH : AddressesHolesky.PRIME_STAKED_ETH;
        address depositPoolAddress = block.chainid == 1 ? Addresses.LRT_DEPOSIT_POOL : AddressesHolesky.LRT_DEPOSIT_POOL;
        address wethAddress = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesHolesky.WETH_TOKEN;

        contractAddress = address(new PrimeZapper(primeEthAddress, depositPoolAddress, wethAddress));
        console.log("PrimeZapper deployed at: %s", contractAddress);
    }
}
