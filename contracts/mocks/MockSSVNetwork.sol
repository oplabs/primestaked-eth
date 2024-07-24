// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";

contract MockSSVNetwork {
    address public ssvToken;

    constructor(address _ssvToken) {
        ssvToken = _ssvToken;
    }

    function deposit(
        address clusterOwner,
        uint64[] memory operatorIds,
        uint256 amount,
        Cluster memory cluster
    )
        public
    {
        IERC20(ssvToken).transferFrom(msg.sender, address(this), amount);
    }

    function registerValidator(
        bytes memory publicKey,
        uint64[] memory operatorIds,
        bytes memory sharesData,
        uint256 amount,
        Cluster memory cluster
    )
        external
    {
        IERC20(ssvToken).transferFrom(msg.sender, address(this), amount);
    }

    function bulkRegisterValidator(
        bytes[] calldata publicKeys,
        uint64[] memory operatorIds,
        bytes[] calldata sharesData,
        uint256 amount,
        Cluster memory cluster
    )
        external
    { }

    function exitValidator(bytes memory publicKey, uint64[] memory operatorIds) external { }

    function bulkExitValidator(bytes[] memory publicKeys, uint64[] memory operatorIds) external { }

    function removeValidator(bytes memory publicKey, uint64[] memory operatorIds, Cluster memory cluster) external { }

    function bulkRemoveValidator(
        bytes[] calldata publicKeys,
        uint64[] memory operatorIds,
        Cluster memory cluster
    )
        external
    { }
}
