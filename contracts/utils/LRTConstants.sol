// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

library LRTConstants {
    //tokens
    //rETH token
    bytes32 public constant R_ETH_TOKEN = keccak256("R_ETH_TOKEN");
    //stETH token
    bytes32 public constant ST_ETH_TOKEN = keccak256("ST_ETH_TOKEN");
    //cbETH token
    bytes32 public constant CB_ETH_TOKEN = keccak256("CB_ETH_TOKEN");
    //ETHX token
    bytes32 public constant ETHX_TOKEN = keccak256("ETHX_TOKEN");

    // OETH token
    bytes32 public constant OETH_TOKEN = keccak256("OETH_TOKEN");

    // mETH token
    bytes32 public constant M_ETH_TOKEN = keccak256("M_ETH_TOKEN");

    // swETH token
    bytes32 public constant SWETH_TOKEN = keccak256("SWETH_TOKEN");

    // WETH token
    bytes32 public constant WETH_TOKEN = keccak256("WETH_TOKEN");

    // SSV
    bytes32 public constant SSV_TOKEN = keccak256("SSV_TOKEN");
    bytes32 public constant SSV_NETWORK = keccak256("SSV_NETWORK");

    //contracts
    bytes32 public constant LRT_ORACLE = keccak256("LRT_ORACLE");
    bytes32 public constant LRT_DEPOSIT_POOL = keccak256("LRT_DEPOSIT_POOL");
    bytes32 public constant EIGEN_STRATEGY_MANAGER = keccak256("EIGEN_STRATEGY_MANAGER");

    //Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // updated library variables
    bytes32 public constant SFRXETH_TOKEN = keccak256("SFRXETH_TOKEN");
    // add new vars below
    bytes32 public constant EIGEN_POD_MANAGER = keccak256("EIGEN_POD_MANAGER");

    // Operator Role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    bytes32 internal constant SALT = keccak256(abi.encodePacked("Prime-Staked"));
}
