// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { BaseTest } from "./BaseTest.t.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTConfigTest, ILRTConfig, UtilLib, LRTConstants } from "./LRTConfigTest.t.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract PrimeStakedETHTest is BaseTest, LRTConfigTest {
    PrimeStakedETH public preth;

    event UpdatedLRTConfig(address indexed _lrtConfig);

    function setUp() public virtual override(LRTConfigTest, BaseTest) {
        super.setUp();

        // initialize LRTConfig
        lrtConfig.initialize(admin, address(stETH), address(ethX), prethMock);

        ProxyAdmin proxyAdmin = new ProxyAdmin();
        PrimeStakedETH tokenImpl = new PrimeStakedETH();
        TransparentUpgradeableProxy tokenProxy =
            new TransparentUpgradeableProxy(address(tokenImpl), address(proxyAdmin), "");

        preth = PrimeStakedETH(address(tokenProxy));
    }
}

contract PRETHInitialize is PrimeStakedETHTest {
    function test_RevertWhenLRTConfigIsZeroAddress() external {
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        preth.initialize(address(0));
    }

    function test_InitializeContractsVariables() external {
        preth.initialize(address(lrtConfig));

        assertTrue(lrtConfig.hasRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin), "Admin address is not set");
        assertEq(address(lrtConfig), address(preth.lrtConfig()), "LRT config address is not set");

        assertEq(preth.name(), "Prime Staked ETH", "Name is not set");
        assertEq(preth.symbol(), "primeETH", "Symbol is not set");
    }
}

contract PRETHMint is PrimeStakedETHTest {
    address public minter = makeAddr("minter");

    function setUp() public override {
        super.setUp();

        preth.initialize(address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, minter);
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotMinter() external {
        vm.startPrank(alice);

        string memory stringRole = string(abi.encodePacked(LRTConstants.MINTER_ROLE));
        bytes memory revertData = abi.encodeWithSelector(ILRTConfig.CallerNotLRTConfigAllowedRole.selector, stringRole);

        vm.expectRevert(revertData);

        preth.mint(address(this), 100 ether);
        vm.stopPrank();
    }

    function test_RevertMintIsPaused() external {
        vm.startPrank(manager);
        preth.pause();
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert("Pausable: paused");
        preth.mint(address(this), 1 ether);
        vm.stopPrank();
    }

    function test_Mint() external {
        vm.startPrank(admin);

        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, msg.sender);

        vm.stopPrank();

        vm.startPrank(minter);

        preth.mint(address(this), 100 ether);

        assertEq(preth.balanceOf(address(this)), 100 ether, "Balance is not correct");

        vm.stopPrank();
    }
}

contract PRETHBurnFrom is PrimeStakedETHTest {
    address public burner = makeAddr("burner");

    function setUp() public override {
        super.setUp();
        preth.initialize(address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        lrtConfig.grantRole(LRTConstants.BURNER_ROLE, burner);

        // give minter role to admin
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, admin);
        preth.mint(address(this), 100 ether);

        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotBurner() external {
        vm.startPrank(bob);

        string memory roleStr = string(abi.encodePacked(LRTConstants.BURNER_ROLE));
        bytes memory revertData = abi.encodeWithSelector(ILRTConfig.CallerNotLRTConfigAllowedRole.selector, roleStr);

        vm.expectRevert(revertData);

        preth.burnFrom(address(this), 100 ether);
        vm.stopPrank();
    }

    function test_RevertBurnIsPaused() external {
        vm.prank(manager);
        preth.pause();

        vm.prank(burner);
        vm.expectRevert("Pausable: paused");
        preth.burnFrom(address(this), 100 ether);
    }

    function test_BurnFrom() external {
        vm.prank(burner);
        preth.burnFrom(address(this), 100 ether);

        assertEq(preth.balanceOf(address(this)), 0, "Balance is not correct");
    }
}

contract PRETHPause is PrimeStakedETHTest {
    function setUp() public override {
        super.setUp();
        preth.initialize(address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);

        preth.pause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsAlreadyPaused() external {
        vm.startPrank(manager);
        preth.pause();

        vm.expectRevert("Pausable: paused");
        preth.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.startPrank(manager);
        preth.pause();

        vm.stopPrank();

        assertTrue(preth.paused(), "Contract is not paused");
    }
}

contract PRETHUnpause is PrimeStakedETHTest {
    function setUp() public override {
        super.setUp();
        preth.initialize(address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, admin);
        preth.pause();
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);

        preth.unpause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsNotPaused() external {
        vm.startPrank(admin);
        preth.unpause();

        vm.expectRevert("Pausable: not paused");
        preth.unpause();

        vm.stopPrank();
    }

    function test_Unpause() external {
        vm.startPrank(admin);
        preth.unpause();

        vm.stopPrank();

        assertFalse(preth.paused(), "Contract is still paused");
    }
}

contract PRETHUpdateLRTConfig is PrimeStakedETHTest {
    function setUp() public override {
        super.setUp();
        preth.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);

        preth.updateLRTConfig(address(lrtConfig));
        vm.stopPrank();
    }

    function test_RevertWhenLRTConfigIsZeroAddress() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        preth.updateLRTConfig(address(0));
        vm.stopPrank();
    }

    function test_UpdateLRTConfig() external {
        address newLRTConfigAddress = makeAddr("MockNewLRTConfig");
        ILRTConfig newLRTConfig = ILRTConfig(newLRTConfigAddress);

        vm.startPrank(admin);
        expectEmit();
        emit UpdatedLRTConfig(address(newLRTConfig));
        preth.updateLRTConfig(address(newLRTConfig));
        vm.stopPrank();

        assertEq(address(newLRTConfig), address(preth.lrtConfig()), "LRT config address is not set");
    }
}
