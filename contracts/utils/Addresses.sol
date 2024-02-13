// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

library Addresses {
    address public constant ADMIN_MULTISIG = 0xEc574b7faCEE6932014EbfB1508538f6015DCBb0;
    address public constant RELAYER = 0x5De069482Ac1DB318082477B7B87D59dfB313f91;

    address public constant ADMIN_ROLE = ADMIN_MULTISIG;
    address public constant MANAGER_ROLE = ADMIN_MULTISIG;
    address public constant OPERATOR_ROLE = RELAYER;

    address public constant PROXY_OWNER = ADMIN_MULTISIG;
    address public constant PROXY_FACTORY = 0x279b272E8266D2fd87e64739A8ecD4A5c94F953D;
    address public constant PROXY_ADMIN = 0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758;

    address public constant PRIME_STAKED_ETH = 0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615;

    address public constant LRT_CONFIG = 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF;
    address public constant LRT_ORACLE = 0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32;
    address public constant LRT_DEPOSIT_POOL = 0xA479582c8b64533102F6F528774C536e354B8d32;
    address public constant NODE_DELEGATOR = 0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2;

    address public constant CHAINLINK_ORACLE_PROXY = 0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09;

    address public constant OETH_TOKEN = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
    address public constant OETH_EIGEN_STRATEGY = 0xa4C637e0F704745D182e4D38cAb7E7485321d059;
    address public constant OETH_ORACLE_PROXY = 0xc513bDfbC308bC999cccc852AF7C22aBDF44A995;

    address public constant SFRXETH_TOKEN = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant SFRXETH_EIGEN_STRATEGY = 0x8CA7A5d6f3acd3A7A8bC468a8CD0FB14B6BD28b6;
    address public constant SFRXETH_ORACLE_PROXY = 0x407d53b380A4A05f8dce5FBd775DF51D1DC0D294;
    address public constant FRAX_DUAL_ORACLE = 0x584902BCe4282003E420Cf5b7ae5063D6C1c182a;

    address public constant METH_TOKEN = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    address public constant METH_EIGEN_STRATEGY = 0x298aFB19A105D59E74658C4C334Ff360BadE6dd2;
    address public constant METH_ORACLE_PROXY = 0xE709cee865479Ae1CF88f2f643eF8D7e0be6e369;
    address public constant METH_STAKING = 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f;

    address public constant STETH_TOKEN = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant STETH_EIGEN_STRATEGY = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
    address public constant STETH_ORACLE = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;

    address public constant RETH_TOKEN = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant RETH_EIGEN_STRATEGY = 0x1BeE69b7dFFfA4E2d53C2a2Df135C388AD25dCD2;
    address public constant RETH_ORACLE = 0x536218f9E9Eb48863970252233c8F271f554C2d0;

    address public constant SWETH_TOKEN = 0xf951E335afb289353dc249e82926178EaC7DEd78;
    address public constant SWETH_EIGEN_STRATEGY = 0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6;
    address public constant SWETH_ORACLE = 0x061bB36F8b67bB922937C102092498dcF4619F86;

    address public constant ETHX_TOKEN = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address public constant ETHX_EIGEN_STRATEGY = 0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d;
    address public constant ETHX_ORACLE_PROXY = 0x85B4C05c9dC3350c220040BAa48BD0aD914ad00C;
    address public constant STADER_STAKING_POOL_MANAGER = 0xcf5EA1b38380f6aF39068375516Daf40Ed70D299;

    address public constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // TODO add after oracle is deployed
    address public constant WETH_ORACLE_PROXY = address(1);

    address public constant EIGEN_UNPAUSER = 0x369e6F597e22EaB55fFb173C6d9cD234BD699111;
    address public constant EIGEN_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
    address public constant EIGEN_POD_MANAGER = 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
}

library AddressesGoerli {
    // address public constant ADMIN_MULTISIG = ;
    address public constant DEPLOYER = 0xFD9E6005187F448957a0972a7d0C0A6dA2911236;
    address public constant RELAYER = 0x41738Cf30cc59e00f090B2C1af57dBf60316AfED;

    address public constant ADMIN_ROLE = DEPLOYER;
    address public constant MANAGER_ROLE = DEPLOYER;
    address public constant OPERATOR_ROLE = DEPLOYER;

    // address public constant PROXY_OWNER = ADMIN_MULTISIG;
    address public constant PROXY_FACTORY = 0xe58F6e65dB9D82b668C480565e20024887850186;
    address public constant PROXY_ADMIN = 0x941B4A6C9F37A5e6E00a2c895467839F4dEDe048;

    // address public constant PRIME_STAKED_ETH = ;

    address public constant LRT_CONFIG = 0x4ABe68F6e0D6D23EEF42494CfaEaa6a3398cf0f2;
    // address public constant LRT_ORACLE = ;
    address public constant LRT_DEPOSIT_POOL = 0x2aC2754d8722F28319928d10e7C526bdc560A248;
    // address public constant NODE_DELEGATOR = ;

    // address public constant CHAINLINK_ORACLE_PROXY = ;

    address public constant STETH_TOKEN = 0x2C40141Cd278746C9666288d12EbF434Eadef700;
    address public constant STETH_EIGEN_STRATEGY = 0xB613E78E2068d7489bb66419fB1cfa11275d14da;
    // address public constant STETH_ORACLE = ;

    address public constant ETHX_TOKEN = 0x3338eCd3ab3d3503c55c931d759fA6d78d287236;
    address public constant ETHX_EIGEN_STRATEGY = 0x5d1E9DC056C906CBfe06205a39B0D965A6Df7C14;
    // address public constant ETHX_ORACLE_PROXY = ;
    address public constant STADER_STAKING_POOL_MANAGER = 0xd0e400Ec6Ed9C803A9D9D3a602494393E806F823;

    address public constant WETH_TOKEN = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    address public constant EIGEN_UNPAUSER = 0x3d9C2c2B40d890ad53E27947402e977155CD2808;
    address public constant EIGEN_STRATEGY_MANAGER = 0x779d1b5315df083e3F9E94cB495983500bA8E907;
    address public constant EIGEN_POD_MANAGER = 0xa286b84C96aF280a49Fe1F40B9627C2A2827df41;
}
