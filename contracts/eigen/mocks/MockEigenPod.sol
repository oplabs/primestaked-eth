// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { BeaconChainProofs } from "../interfaces/IEigenPod.sol";

contract MockEigenPod {
    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata withdrawalCredentialProofs,
        bytes32[][] calldata validatorFields
    )
        external
    { }

    function verifyBalanceUpdates(
        uint64 oracleTimestamp,
        uint40[] calldata validatorIndices,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    )
        external
    { }

    receive() external payable { }
}
