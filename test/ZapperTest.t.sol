// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { BaseTest } from "./BaseTest.t.sol";
import { LRTDepositPoolTest } from "./LRTDepositPoolTest.t.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract ZapperTest is BaseTest, LRTDepositPoolTest {
    PrimeZapper public primeZapper;
    address public wethAddress;

    function setUp() public virtual override(LRTDepositPoolTest, BaseTest) {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        wethAddress = address(weth);
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        primeZapper = new PrimeZapper(address(preth), address(lrtDepositPool), wethAddress);
    }

    function test_DepositETH() external {
        vm.startPrank(alice);

        // alice balance of prETH before deposit
        uint256 aliceBalanceBefore = preth.balanceOf(address(alice));

        primeZapper.deposit{ value: 2 ether }((2 ether * 99 / 100), referralId);

        // Alice's balance of prETH after deposit
        uint256 aliceBalanceAfter = preth.balanceOf(address(alice));
        vm.stopPrank();

        assertEq(lrtDepositPool.getTotalAssetDeposits(wethAddress), 2 ether, "Total asset deposits is not set");
        assertGe(aliceBalanceAfter - aliceBalanceBefore, 2 ether, "Alice balance too low");
    }

    function test_sendETH() external {
        vm.startPrank(alice);

        // alice balance of prETH before deposit
        uint256 aliceBalanceBefore = preth.balanceOf(address(alice));

        (bool sent, bytes memory data) = address(primeZapper).call{ value: 2 ether }("");
        require(sent, "Failed to send Ether");

        // Alice's balance of prETH after deposit
        uint256 aliceBalanceAfter = preth.balanceOf(address(alice));
        vm.stopPrank();

        assertEq(lrtDepositPool.getTotalAssetDeposits(wethAddress), 2 ether, "Total asset deposits is not set");
        assertGe(aliceBalanceAfter - aliceBalanceBefore, 2 ether, "Alice balance too low");
    }
}
