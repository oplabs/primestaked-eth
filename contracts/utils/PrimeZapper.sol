// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILRTDepositPool } from "../interfaces/ILRTDepositPool.sol";
import { IWETH } from "../interfaces/IWETH.sol";

contract PrimeZapper {
    IERC20 public immutable primeEth;
    ILRTDepositPool public immutable lrtDepositPool;
    // TODO: add a fork test weth is correctly configured
    IWETH public immutable weth;

    /* leaving ETH marker and "asset" in the Zap event just in case in 
     * future we decide to allow for zapping with any other asset.
     */
    address private constant ETH_MARKER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event Zap(address indexed minter, address indexed asset, uint256 amount);

    constructor(address _primeEth, address _lrtDepositPool, address _weth) {
        primeEth = IERC20(_primeEth);
        lrtDepositPool = ILRTDepositPool(_lrtDepositPool);
        weth = IWETH(_weth);
        weth.approve(address(_lrtDepositPool), type(uint256).max);
    }

    /**
     * @dev Deposit ETH and receive primeETH in return.
     * Will not verify minimum amount of primeETH received
     */
    receive() external payable {
        deposit(0, "");
    }

    /**
     * @dev Deposit ETH and receive primeETH in return
     * @param minPrimeEth Minimum amount of primeETH for user to receive
     * @return primeEthAmount the amount of primeETH tokens sent to user
     */
    function deposit(uint256 minPrimeEth, string memory referralId) public payable returns (uint256 primeEthAmount) {
        uint256 balance = address(this).balance;
        weth.deposit{ value: balance }();
        emit Zap(msg.sender, ETH_MARKER, balance);
        primeEthAmount = _deposit(minPrimeEth, referralId);
    }

    /**
     * @dev Internal function to deposit PrimeETH from WETH
     * @param minPrimeEth Minimum amount of PrimeETH for user to receive
     * @return primeEthAmount the amount of primeETH tokens sent to user
     */
    function _deposit(uint256 minPrimeEth, string memory referralId) internal returns (uint256 primeEthAmount) {
        uint256 toDeposit = weth.balanceOf(address(this));
        lrtDepositPool.depositAsset(address(weth), toDeposit, minPrimeEth, referralId);
        primeEthAmount = primeEth.balanceOf(address(this));
        require(primeEthAmount >= minPrimeEth, "Zapper: not enough minted");
        require(primeEth.transfer(msg.sender, primeEthAmount));
    }
}
