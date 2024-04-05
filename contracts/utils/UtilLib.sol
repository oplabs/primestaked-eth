// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

/// @title UtilLib - Utility library
/// @notice Utility functions
library UtilLib {
    error ZeroAddressNotAllowed(); // 0x8579befe

    /// @dev zero address check modifier
    /// @param address_ address to check
    function checkNonZeroAddress(address address_) internal pure {
        if (address_ == address(0)) revert ZeroAddressNotAllowed();
    }
}
