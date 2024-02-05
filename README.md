# Prime Staked ETH

[Prime Staked ETH](https://www.primestaked.com/) is liquid restaking built on top of
[EigenLayer](https://www.eigenlayer.xyz/).

# Contracts

![Base Prime Staked Contracts](./docs/plantuml/primeBaseContracts.png)

## Mainnet Deployment

### Proxied contracts

| Contract Name                                                | Proxy Address                                                                                                              | Implementation Address                                                                                                     |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| [PrimeStakedETH](./contracts/README.md#primestakedeth)       | [0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615](https://etherscan.io/address/0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615#code) | [0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2](https://etherscan.io/address/0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2#code) |
| [LRTDepositPool](./contracts/README.md#lrtdepositpool)       | [0xA479582c8b64533102F6F528774C536e354B8d32](https://etherscan.io/address/0xA479582c8b64533102F6F528774C536e354B8d32#code) | [0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0](https://etherscan.io/address/0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0#code) |
| [LRTConfig](./contracts/README.md#lrtconfig)                 | [0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF](https://etherscan.io/address/0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF#code) | [0xcdfD989e689872506E2897316b10e29c84AB087F](https://etherscan.io/address/0xcdfD989e689872506E2897316b10e29c84AB087F#code) |
| [LRTOracle](./contracts/README.md#lrtoracle)                 | [0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32](https://etherscan.io/address/0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32#code) | [0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce](https://etherscan.io/address/0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce#code) |
| [NodeDelegator](./contracts/README.md#nodedelegator) index 0 | [0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2](https://etherscan.io/address/0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2#code) | [0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4](https://etherscan.io/address/0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4#code) |
| [NodeDelegator](./contracts/README.md#nodedelegator) index 1 | 0x0000000000000000000000000000000000000000                                                                                 | 0x0000000000000000000000000000000000000000                                                                                 |

### Immutable Contracts

The following are [Open Zeppelin](https://www.openzeppelin.com/contracts) contracts.

| Contract Name | Address                                                                                                                    |
| ------------- | -------------------------------------------------------------------------------------------------------------------------- |
| ProxyFactory  | [0x279b272E8266D2fd87e64739A8ecD4A5c94F953D](https://etherscan.io/address/0x279b272E8266D2fd87e64739A8ecD4A5c94F953D#code) |
| ProxyAdmin    | [0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758](https://etherscan.io/address/0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758#code) |

### Operational Roles

The protocol is currently managed by a [Gnosis Safe](https://safe.global), 3 of 7 multi-signature wallet.

| Contract Name    | Address                                                                                                                    |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------- |
| ProxyAdmin Owner | [0xEc574b7faCEE6932014EbfB1508538f6015DCBb0](https://etherscan.io/address/0xEc574b7faCEE6932014EbfB1508538f6015DCBb0#code) |
| Admin            | [0xEc574b7faCEE6932014EbfB1508538f6015DCBb0](https://etherscan.io/address/0xEc574b7faCEE6932014EbfB1508538f6015DCBb0#code) |
| Manager          | [0xEc574b7faCEE6932014EbfB1508538f6015DCBb0](https://etherscan.io/address/0xEc574b7faCEE6932014EbfB1508538f6015DCBb0#code) |
| Operator         | [0xEc574b7faCEE6932014EbfB1508538f6015DCBb0](https://etherscan.io/address/0xEc574b7faCEE6932014EbfB1508538f6015DCBb0#code) |

![Prime Staked Accounts](./docs/plantuml/primeAccountContracts.png)

### Supported Liquid Staking Tokens (LSTs)

| Contract Name         | Address                                                                                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Origin (OETH)         | [0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3](https://etherscan.io/token/0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3) |
| Mantle (mETH)         | [0xd5f7838f5c461feff7fe49ea5ebaf7728bb0adfa](https://etherscan.io/token/0xd5f7838f5c461feff7fe49ea5ebaf7728bb0adfa) |
| Stader (ETHx)         | [0xA35b1B31Ce002FBF2058D22F30f95D405200A15b](https://etherscan.io/token/0xA35b1B31Ce002FBF2058D22F30f95D405200A15b) |
| Lido (stETH)          | [0xae7ab96520de3a18e5e111b5eaab095312d7fe84](https://etherscan.io/token/0xae7ab96520de3a18e5e111b5eaab095312d7fe84) |
| Staked Frax (sfrxETH) | [0xac3E018457B222d93114458476f3E3416Abbe38F](https://etherscan.io/token/0xac3E018457B222d93114458476f3E3416Abbe38F) |
| Rocket Pool (rETH)    | [0xae78736cd615f374d3085123a210448e74fc6393](https://etherscan.io/token/0xae78736cd615f374d3085123a210448e74fc6393) |
| Swell (swETH)         | [0xf951E335afb289353dc249e82926178EaC7DEd78](https://etherscan.io/token/0xf951E335afb289353dc249e82926178EaC7DEd78) |

### Oracle contracts

![Prime Staked Oracle contracts](./docs/plantuml/primeOracleContracts.png)

| Contract Name                                                        | Proxy Address                              | Implementation Address                     |
| -------------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------ |
| [ChainlinkPriceOracle](./contracts/oracles/ChainlinkPriceOracle.sol) | 0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09 | 0x255C082Fb505212BA2396EDbF621d8aF1e5D29A5 |
| [OETHPriceOracle](./contracts/oracles/OETHPriceOracle.sol)           | 0xc513bDfbC308bC999cccc852AF7C22aBDF44A995 | 0xd91d3bEC19E921e911A487394B155da552953917 |
| [SfrxETHPriceOracle](./contracts/oracles/SfrxETHPriceOracle.sol)     | 0x407d53b380A4A05f8dce5FBd775DF51D1DC0D294 | 0xE6BebE3072fF42a7c2A4A5a9864b30Bc5608d9C3 |
| [EthXPriceOracle](./contracts/oracles/EthXPriceOracle.sol)           | 0x85B4C05c9dC3350c220040BAa48BD0aD914ad00C | 0xd101bd159968106595d48948677fee9e8a0450a9 |
| [MEthPriceOracle ](./contracts/oracles/MEthPriceOracle.sol)          | 0xE709cee865479Ae1CF88f2f643eF8D7e0be6e369 | 0x91Fad4007FF129ABFB72d0701C200f0957e9a0D8 |

### EigenLayer contracts

[EigenLayer's mainnet contract addresses](https://github.com/Layr-Labs/eigenlayer-contracts?tab=readme-ov-file#current-mainnet-deployment)

![EigenLayer contracts](./docs/plantuml/primeEigenContracts.png)

# Developer Guide

## Setup

1. Install dependencies

```bash
npm install

forge install
```

2. copy .env.example to .env and fill in the values

```bash
cp .env.example .env
```

## Usage

This is a list of the most frequently needed commands.

### Clean

Delete the build artifacts and cache directories:

```sh
forge clean
```

### Compile

Compile the contracts:

```bash
forge build
```

### Format

Format the contracts:

```bash
forge fmt
```

### Lint

Lint the contracts:

```bash
$ npm lint
```

## Testing

### Unit Tests

```sh
make unit-test
```

### Fork Tests

Run the fork tests against mainnet or a local. The `FORK_RPC_URL` env var controls whether the fork tests run against
mainnet or a local forked node.

```bash
make fork-test
```

### Integration Tests

Run the integration tests against Goerli

```bash
make int-test
```

### Test Coverage

Generate test coverage and output result to the terminal:

```sh
$ npm test:coverage
```

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ npm test:coverage:report
```

### Gas Usage

Get a gas report:

```bash
$ forge test --gas-report
```

## Deploy

### Deploy to testnet

```bash
make deploy-lrt-testnet
```

### For tests (mainnet) using Anvil:

In one terminal run the Anvil node forking the mainnet

```bash
make node-fork
```

In another terminal apply the deploys that are not yet on mainnet.

```bash
make pool-deleg-oracle-fork
make add-assets-fork
```

### Deploy to Anvil:

```bash
make deploy-lrt-local-test
```

### General Deploy Script Instructions

Create a Deploy script in `script/Deploy.s.sol`:

and run the script:

```bash
forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Verify Contracts

Follow this pattern `contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet`

Example:

```bash
contractAddress=0x0000000000000000000000000000000000000000 contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
```

# Credits

This repo was originally forked from [Kelp DAO](https://github.com/kelp-DAO/KelpDAO-contracts/). It's been further
developed by [Origin Protocol](https://www.originprotocol.com/) since January 2024.
