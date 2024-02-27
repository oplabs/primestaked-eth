// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { PrimeZapperLib } from "contracts/libraries/PrimeZapperLib.sol";


contract DeployPrimeZapper is BaseMainnetScript {
    address public primeZapper;

    constructor() {
        // Will only execute script before this block number
        // deployBlockNum = ;
    }

    function _execute() internal override {
        // Deploy new Prime Zapper
        primeZapper = PrimeZapperLib.deploy();
    }

    function _fork() internal override {
    }
}
