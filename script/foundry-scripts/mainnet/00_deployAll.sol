// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { DeployMinimal } from "./01_deployMinimal.s.sol";
import { DeployFirstOracles } from "./02_deployFirstOracles.s.sol";
import { DeployDelegatorPoolOracle } from "./03_deployDelegatorPoolOracle.s.sol";
import { AddInitialAssets } from "./04_addInitialAssets.s.sol";
import { AddMoreAssets } from "./05_addMoreAssets.s.sol";
import { UpdateDepositLimits } from "./06_updateDepositLimits.s.sol";
import { TransferOwnership } from "./07_transferOwnership.s.sol";
import { UpgradeDepositPoolNodeDelegator } from "./08_upgradeDepositPoolNodeDelegator.s.sol";
import { UpgradeDepositPoolNodeDelegatorOracles } from "./09_upgradeDepositPoolNodeDelegatorOracles.s.sol";
import { DeployNativeETH } from "./10_deployNativeETH.s.sol";
import { DeployPrimeZapper } from "./11_deployPrimeZapper.s.sol";

contract DeployAll {
    // Ignores this contract when checking contract sized with
    // forge build --sizes
    bool public IS_SCRIPT = true;
    address public primeZapper;

    function run() external {
        (new DeployMinimal()).run();
        (new DeployFirstOracles()).run();
        (new AddInitialAssets()).run();
        (new AddMoreAssets()).run();
        (new UpdateDepositLimits()).run();
        (new DeployDelegatorPoolOracle()).run();
        (new TransferOwnership()).run();
        (new UpgradeDepositPoolNodeDelegator()).run();
        (new UpgradeDepositPoolNodeDelegatorOracles()).run();
        (new DeployNativeETH()).run();
        DeployPrimeZapper deployPrimeZapper = new DeployPrimeZapper();
        deployPrimeZapper.run();
        primeZapper = deployPrimeZapper.primeZapper();
    }
}
