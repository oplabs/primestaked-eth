const addresses = {};

// Utility addresses
addresses.zero = "0x0000000000000000000000000000000000000000";
addresses.dead = "0x0000000000000000000000000000000000000001";
addresses.ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

addresses.mainnet = {};
addresses.goerli = {};

// TODO read the addresses from the Solidity Addresses library

// LSTs
addresses.mainnet.OETH_TOKEN = "0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3";
addresses.mainnet.SFRXETH_TOKEN = "0xac3E018457B222d93114458476f3E3416Abbe38F";
addresses.mainnet.METH_TOKEN = "0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa";
addresses.mainnet.STETH_TOKEN = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
addresses.mainnet.RETH_TOKEN = "0xae78736Cd615f374D3085123A210448E74Fc6393";
addresses.mainnet.SWETH_TOKEN = "0xf951E335afb289353dc249e82926178EaC7DEd78";
addresses.mainnet.ETHX_TOKEN = "0xA35b1B31Ce002FBF2058D22F30f95D405200A15b";
addresses.mainnet.WETH_TOKEN = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
addresses.mainnet.SSV_TOKEN = "0x9D65fF81a3c488d585bBfb0Bfe3c7707c7917f54";

// Prime Staked contracts

addresses.mainnet.PRIME_STAKED_ETH = "0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615";
addresses.mainnet.LRT_CONFIG = "0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF";
addresses.mainnet.LRT_ORACLE = "0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32";
addresses.mainnet.LRT_DEPOSIT_POOL = "0xA479582c8b64533102F6F528774C536e354B8d32";
addresses.mainnet.NODE_DELEGATOR = "0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2";
addresses.mainnet.NODE_DELEGATOR_NATIVE_STAKING = "0x18169Ee0CED9AA744F3CD01Adc6E2EB2E8FB0087";
addresses.mainnet.EIGEN_POD = "0x42791AA09bF53b5D2c0c74ac948e74a66A2fe35e";
addresses.mainnet.CHAINLINK_ORACLE_PROXY = "0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09";

addresses.mainnet.PROXY_ADMIN = "0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758";

addresses.mainnet.ADMIN_MULTISIG = "0xEc574b7faCEE6932014EbfB1508538f6015DCBb0";
addresses.mainnet.RELAYER = "0x5De069482Ac1DB318082477B7B87D59dfB313f91";

addresses.goerli.NODE_DELEGATOR = "0x134ed22982EDE4ED69aC8c3ee5B29874bC0492F9";
addresses.goerli.NODE_DELEGATOR_NATIVE_STAKING = "0x03f754CC229C916cb0dd936F5a332c4De32aAb29";
addresses.goerli.EIGEN_POD = "0x4b4DC934Dd44A1B48C822c70997eFb4a828118c8";
addresses.goerli.WETH_TOKEN = "0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6";
addresses.goerli.SSV_TOKEN = "0x3a9f01091c446bde031e39ea8354647afef091e7";
addresses.goerli.WETH_TOKEN = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";
module.exports = addresses;
