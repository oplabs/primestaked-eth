// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";

library PrimeZapperLib {
    function deploy() internal returns (address contractAddress) {
        address primeEth = block.chainid == 1 ? Addresses.PRIME_STAKED_ETH : AddressesGoerli.PRIME_STAKED_ETH;
        address lrtDepositPool = block.chainid == 1 ? Addresses.LRT_DEPOSIT_POOL : AddressesGoerli.LRT_DEPOSIT_POOL;
        address weth = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesGoerli.WETH_TOKEN;

        contractAddress = address(new PrimeZapper(primeEth, lrtDepositPool, weth));
        console.log("PrimeZapper deployed at: %s", contractAddress);
    }
}
