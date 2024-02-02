// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployLRTDepositPool is Script {
    address public proxyAdminOwner;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    PrimeStakedETH public PRETHProxy;

    NodeDelegator public nodeDelegatorProxy1;
    NodeDelegator public nodeDelegatorProxy2;
    NodeDelegator public nodeDelegatorProxy3;
    NodeDelegator public nodeDelegatorProxy4;
    NodeDelegator public nodeDelegatorProxy5;
    address[] public nodeDelegatorContracts;

    function setUpByAdmin() private {
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));

        // add minter role to lrtDepositPool so it mint primeETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));
        address oldDepositPoolProxy = 0x55052ba1a135c43a17cf6CeE58a59c782CeF1Bcf;
        lrtConfigProxy.revokeRole(LRTConstants.MINTER_ROLE, oldDepositPoolProxy);

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy2));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy3));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy4));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy5));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);
    }

    /* This deploy script is used to point the LRTDepositPool Proxy to the new implementation
     * 
     */
    function run() external {
        vm.startBroadcast();
        console.log("Deployment started...");

        // Proxy factory from DeployLRT
        proxyFactory = ProxyFactory(0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab);
        // ProxyAdmin from DeployLRT
        proxyAdmin = ProxyAdmin(0x60fF8354e9C0E78e032B7daeA8da2c3265287dBd);
        proxyAdminOwner = proxyAdmin.owner();
        // LRTConfig proxy from DeployLRT
        lrtConfigProxy = LRTConfig(0x5E598B1A8658a5a1434CEAA6988D43aeB028F430);
        // PrimeStakedETH proxy proxy from DeployLRT
        PRETHProxy = PrimeStakedETH(0xE8EC01e3546E2967C9a46b58E5e70608D313b650);
        // NodeDelegator proxyies proxy proxy from DeployLRT
        nodeDelegatorProxy1 = NodeDelegator(payable(0x275Df49898F7BBc8ca62A9487584aee3586ad775));
        nodeDelegatorProxy2 = NodeDelegator(payable(0x136cE661972Ad469D5Abecff69712bAA9bF280Cc));
        nodeDelegatorProxy3 = NodeDelegator(payable(0x743491173ee03f580aFd4Db4Ad32FCf0251bb8e4));
        nodeDelegatorProxy4 = NodeDelegator(payable(0x3c85c49a81a5DC3CD3ef6C0BE46757FE703d745d));
        nodeDelegatorProxy5 = NodeDelegator(payable(0xf97A629754fA65C34fc03cfe36328B6bD308eC8a));

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Owner of ProxyAdmin: ", proxyAdminOwner);
        console.log("LRTConfig proxy present at: ", address(lrtConfigProxy));

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        bytes32 salt = keccak256(abi.encodePacked("LRT-Origin"));
        lrtDepositPoolProxy = LRTDepositPool(
            payable(proxyFactory.create(address(lrtDepositPoolImplementation), address(proxyAdmin), salt))
        );
        // init LRTDepositPool
        lrtDepositPoolProxy.initialize(address(lrtConfigProxy));
        console.log("LRTDepositPool proxy deployed at: ", address(lrtDepositPoolProxy));

        setUpByAdmin();

        console.log("Deployment Done.");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
    }
}
