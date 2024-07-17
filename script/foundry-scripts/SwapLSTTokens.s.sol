// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import { Addresses } from "contracts/utils/Addresses.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapLSTTokens is Script {
    LRTDepositPool public depositPool;
    LRTOracle public oracle;

    function run() external {
        depositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        oracle = LRTOracle(Addresses.LRT_ORACLE);

        vm.startPrank(Addresses.MANAGER_ROLE);

        doSwap(Addresses.STETH_TOKEN);

        vm.stopPrank();
    }

    function doApprovalTx(address token, address spender, uint256 amount) internal {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", spender, amount);

        (bool success,) = token.call(data);

        console.log("----------- Approval Tx -----------");
        console.log("To:", token);
        console.log("Data:");
        console.logBytes(data);
        console.log("-----------------------------------");

        require(success, "Approval simulation failed");
    }

    function getTokenData(address token) internal view returns (uint256 balance, uint256 oethValue) {
        IERC20 tokenContract = IERC20(token);

        balance = tokenContract.balanceOf(address(depositPool));

        uint256 assetPrice = oracle.getAssetPrice(token);

        // OETH is always assumed to be pegged to 1 ETH
        // fromAmount = (toAmount * toPrice) / fromPrice
        oethValue = (balance * assetPrice) / 1 ether;

        console.log("------------ Token Info -----------");
        console.log("Balance in DepositPool:", balance);
        console.log("Asset Price:", assetPrice);
        console.log("Asset Value in OETH:", assetPrice);
        console.log("-----------------------------------");
    }

    function doSwap(address targetToken) internal {
        (uint256 toAmount, uint256 fromAmount) = getTokenData(targetToken);

        doApprovalTx(Addresses.OETH_TOKEN, address(depositPool), fromAmount);

        bytes memory data = abi.encodeWithSignature(
            "swapAssetWithinDepositPool(address,address,uint256,uint256)",
            Addresses.OETH_TOKEN,
            targetToken,
            fromAmount,
            // Account for rounding issues on stETH
            (targetToken == Addresses.STETH_TOKEN) ? toAmount - 1 : toAmount
        );

        console.log("------------ Swap Info ------------");
        console.log("From Amount:", fromAmount);
        console.log("To Amount:", toAmount);
        console.log("-----------------------------------");
        console.log("To:", address(depositPool));
        console.log("Data:");
        console.logBytes(data);
        console.log("-----------------------------------");

        (bool success,) = address(depositPool).call(data);

        require(success, "Swap simulation failed");
    }
}
