const addresses = {};

// Utility addresses
addresses.zero = "0x0000000000000000000000000000000000000000";
addresses.dead = "0x0000000000000000000000000000000000000001";
addresses.ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

addresses.mainnet = {};
addresses.goerli = {};

// TODO read the addresses from the Solidity Addresses library

// LSTs
addresses.mainnet.OETH = "0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3";
addresses.mainnet.sfrxETH = "0xac3E018457B222d93114458476f3E3416Abbe38F";
addresses.mainnet.mETH = "0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa";
addresses.mainnet.stETH = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
addresses.mainnet.rETH = "0xae78736Cd615f374D3085123A210448E74Fc6393";
addresses.mainnet.swETH = "0xf951E335afb289353dc249e82926178EaC7DEd78";
addresses.mainnet.ETHx = "0xA35b1B31Ce002FBF2058D22F30f95D405200A15b";
addresses.mainnet.WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// Prime Staked contracts

addresses.mainnet.PRIME_STAKED_ETH = "0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615";
addresses.mainnet.LRT_CONFIG = "0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF";
addresses.mainnet.LRT_ORACLE = "0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32";
addresses.mainnet.LRT_DEPOSIT_POOL = "0xA479582c8b64533102F6F528774C536e354B8d32";
addresses.mainnet.NODE_DELEGATOR = "0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2";
// TODO update after deployment
addresses.mainnet.NODE_DELEGATOR_NATIVE_STAKING = "0x08c314E8CFb3588371415bffBE3900332BC6d6E9";
addresses.mainnet.CHAINLINK_ORACLE_PROXY = "0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09";

addresses.mainnet.PROXY_ADMIN = "0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758";

addresses.mainnet.ADMIN_MULTISIG = "0xEc574b7faCEE6932014EbfB1508538f6015DCBb0";
addresses.mainnet.RELAYER = "0x5De069482Ac1DB318082477B7B87D59dfB313f91";

addresses.goerli.NODE_DELEGATOR = "0x7f4A403f1bd6ed182a3ABd1F840e02B5A360a538";
addresses.goerli.NODE_DELEGATOR_NATIVE_STAKING = "0xff54d60e6e4F9d1d454b09B4Fc0f7C06977f22D9";
addresses.goerli.WETH = "0xb4fbf271143f4fbf7b91a5ded31805e42b2208d6";
module.exports = addresses;
