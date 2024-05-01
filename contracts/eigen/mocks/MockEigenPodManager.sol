// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { MockEigenPod } from "./MockEigenPod.sol";

contract MockEigenPodManager {
    mapping(address => address) public ownerToPod;

    function createPod() external returns (address pod) {
        pod = ownerToPod[msg.sender];
        if (pod != address(0)) {
            return pod;
        }
        pod = address(new MockEigenPod());
        ownerToPod[msg.sender] = pod;
    }

    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable {
        // do nothing
    }
}