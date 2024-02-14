// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { BaseMainnetScript } from "./BaseMainnetScript.sol";
import { OracleLib } from "contracts/libraries/OracleLib.sol";

contract DeployFirstOracles is BaseMainnetScript {
    constructor() {
        // Will only execute script before this block number
        deployBlockNum = 19_142_698;
    }

    function _execute() internal override {
        OracleLib.deployChainlinkOracle();
        OracleLib.deployOETHOracle();
        OracleLib.deployEthXPriceOracle();
        OracleLib.deployMEthPriceOracle();
        OracleLib.deploySfrxEthPriceOracle();
    }
}
