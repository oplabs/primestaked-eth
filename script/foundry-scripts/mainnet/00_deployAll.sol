// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { DeployMinimal } from "./01_deployMinimal.s.sol";
import { DeployFirstOracles } from "./02_deployFirstOracles.s.sol";
import { AddInitialAssets } from "./03_addInitialAssets.s.sol";
import { DeployNativeETH } from "./10_deployNativeETH.s.sol";

contract DeployAll {
    function run() external {
        (new DeployMinimal()).run();

        (new DeployFirstOracles()).run();

        (new AddInitialAssets()).run();

        (new DeployNativeETH()).run();
    }
}
