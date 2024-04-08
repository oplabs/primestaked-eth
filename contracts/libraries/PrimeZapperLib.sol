// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";
import { Addresses, AddressesHolesky } from "contracts/utils/Addresses.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";

library PrimeZapperLib {
    function deploy(address primeEthAddress, address depositPoolAddress) internal returns (address contractAddress) {
        address wethAddress = block.chainid == 1 ? Addresses.WETH_TOKEN : AddressesHolesky.WETH_TOKEN;

        contractAddress = address(new PrimeZapper(primeEthAddress, depositPoolAddress, wethAddress));
        console.log("PrimeZapper deployed at: %s", contractAddress);
    }
}
