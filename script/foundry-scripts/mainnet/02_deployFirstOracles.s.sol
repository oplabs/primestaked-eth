// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { ProxyFactory } from "../utils/ProxyFactory.sol";
import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { OraclesLib } from "contracts/libraries/OraclesLib.sol";
import { Addresses, AddressesGoerli } from "contracts/utils/Addresses.sol";

contract DeployFirstOracles is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_142_698;
    }

    function _execute() internal override {
        ProxyAdmin proxyAdmin = ProxyAdmin(Addresses.PROXY_ADMIN);
        ProxyFactory proxyFactory = ProxyFactory(Addresses.PROXY_FACTORY);

        OraclesLib.deployInitChainlinkOracle(proxyAdmin, proxyFactory, LRTConfig(Addresses.LRT_CONFIG));
        OraclesLib.deployInitOETHOracle(proxyAdmin, proxyFactory);
        OraclesLib.deployInitEthXPriceOracle(proxyAdmin, proxyFactory);
        OraclesLib.deployInitMEthPriceOracle();
        OraclesLib.deployInitSfrxEthPriceOracle();
    }
}
