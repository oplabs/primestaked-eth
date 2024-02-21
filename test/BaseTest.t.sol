// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { MockToken } from "contracts/mocks/MockToken.sol";
import { MockWETH } from "contracts/mocks/MockWETH.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";

contract BaseTest is Test {
    MockToken public stETH;
    MockToken public ethX;
    MockWETH public weth;

    MockToken public rETH;
    MockToken public cbETH;

    address public admin = makeAddr("admin");

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    uint256 public oneThousand = 1000 ** 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public virtual {
        stETH = new MockToken("Lido ETH", "stETH");
        ethX = new MockToken("ETHX", "ethX");
        weth = new MockWETH("Wrapped WETH", "WETH");
        rETH = new MockToken("Rocket Pool ETH", "rETH");
        cbETH = new MockToken("Coinbase ETH", "cbETH");

        // mint LST tokens to alice, bob and carol
        mintLSTTokensForUsers(stETH);
        mintLSTTokensForUsers(ethX);
        mintLSTTokensForUsers(weth);
        mintLSTTokensForUsers(rETH);
        mintLSTTokensForUsers(cbETH);

        // give ETH to alice, bob and carol
        vm.deal(alice, oneThousand);
        vm.deal(bob, oneThousand);
        vm.deal(carol, oneThousand);
    }

    function mintLSTTokensForUsers(MockToken asset) internal {
        asset.mint(alice, oneThousand);
        asset.mint(bob, oneThousand);
        asset.mint(carol, oneThousand);
    }

    /// @dev Expects an event to be emitted by checking all three topics and the data. As mentioned
    /// in the Foundry
    /// Book, the extra `true` arguments don't hurt.
    function expectEmit() internal {
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
    }
}
