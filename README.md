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
| [LRTDepositPool](./contracts/README.md#lrtdepositpool)       | [0xA479582c8b64533102F6F528774C536e354B8d32](https://etherscan.io/address/0xA479582c8b64533102F6F528774C536e354B8d32#code) | [0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2](https://etherscan.io/address/0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2#code) |
| [LRTConfig](./contracts/README.md#lrtconfig)                 | [0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF](https://etherscan.io/address/0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF#code) | [0xcdfD989e689872506E2897316b10e29c84AB087F](https://etherscan.io/address/0xcdfD989e689872506E2897316b10e29c84AB087F#code) |
| [LRTOracle](./contracts/README.md#lrtoracle)                 | [0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32](https://etherscan.io/address/0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32#code) | [0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14](https://etherscan.io/address/0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14#code) |
| [NodeDelegator](./contracts/README.md#nodedelegator) index 0 | [0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2](https://etherscan.io/address/0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2#code) | [0xe5d7792DF6F6F11Dc584ECD91f472090f454A373](https://etherscan.io/address/0xe5d7792DF6F6F11Dc584ECD91f472090f454A373#code) |
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

| Contract Name                                                        | Proxy Address                                                                                                              | Implementation Address                                                                                                     |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| [ChainlinkPriceOracle](./contracts/oracles/ChainlinkPriceOracle.sol) | [0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09](https://etherscan.io/address/0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09#code) | [0x84D4bA56A033abf1FEa28217cb86EC8A611B3E8E](https://etherscan.io/address/0x84D4bA56A033abf1FEa28217cb86EC8A611B3E8E#code) |
| [OETHPriceOracle](./contracts/oracles/OETHPriceOracle.sol)           | [0xc513bDfbC308bC999cccc852AF7C22aBDF44A995](https://etherscan.io/address/0xc513bDfbC308bC999cccc852AF7C22aBDF44A995#code) | [0xd91d3bEC19E921e911A487394B155da552953917](https://etherscan.io/address/0xd91d3bEC19E921e911A487394B155da552953917#code) |
| [SfrxETHPriceOracle](./contracts/oracles/SfrxETHPriceOracle.sol)     | [0x407d53b380A4A05f8dce5FBd775DF51D1DC0D294](https://etherscan.io/address/0x407d53b380A4A05f8dce5FBd775DF51D1DC0D294#code) | [0xE6BebE3072fF42a7c2A4A5a9864b30Bc5608d9C3](https://etherscan.io/address/0xE6BebE3072fF42a7c2A4A5a9864b30Bc5608d9C3#code) |
| [EthXPriceOracle](./contracts/oracles/EthXPriceOracle.sol)           | [0x85B4C05c9dC3350c220040BAa48BD0aD914ad00C](https://etherscan.io/address/0x85B4C05c9dC3350c220040BAa48BD0aD914ad00C#code) | [0xd101bd159968106595d48948677fee9e8a0450a9](https://etherscan.io/address/0xd101bd159968106595d48948677fee9e8a0450a9#code) |
| [MEthPriceOracle ](./contracts/oracles/MEthPriceOracle.sol)          | [0xE709cee865479Ae1CF88f2f643eF8D7e0be6e369](https://etherscan.io/address/0xE709cee865479Ae1CF88f2f643eF8D7e0be6e369#code) | [0x91Fad4007FF129ABFB72d0701C200f0957e9a0D8](https://etherscan.io/address/0x91Fad4007FF129ABFB72d0701C200f0957e9a0D8#code) |

| LST                   | Price Provider                                                                 | Price Source                                                                                                          |
| --------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| Origin (OETH)         | fixed 1 ETH                                                                    |                                                                                                                       |
| Mantle (mETH)         | `mETHToETH` on Mantle Staking                                                  | [0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f](https://etherscan.io/address/0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f) |
| Stader (ETHx)         | `getExchangeRate` on Stake Pools Manager                                       | [0xcf5EA1b38380f6aF39068375516Daf40Ed70D299](https://etherscan.io/address/0xcf5EA1b38380f6aF39068375516Daf40Ed70D299) |
| Lido (stETH)          | [ChainLink](https://data.chain.link/feeds/ethereum/mainnet/steth-eth)          | [0x86392dC19c0b719886221c78AB11eb8Cf5c52812](https://etherscan.io/address/0x86392dC19c0b719886221c78AB11eb8Cf5c52812) |
| Staked Frax (sfrxETH) | [Frax Dual Oracle](https://docs.frax.finance/frax-oracle/frax-oracle-overview) | [0x584902BCe4282003E420Cf5b7ae5063D6C1c182a](https://etherscan.io/address/0x584902BCe4282003E420Cf5b7ae5063D6C1c182a) |
| Rocket Pool (rETH)    | [ChainLink](https://data.chain.link/feeds/base/base/reth-eth)                  | [0xf397bF97280B488cA19ee3093E81C0a77F02e9a5](https://etherscan.io/address/0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09) |
| Swell (swETH)         | [RedStone](https://app.redstone.finance/#/app/token/SWETH\ETH)                 | [0x061bB36F8b67bB922937C102092498dcF4619F86](https://etherscan.io/address/0x061bB36F8b67bB922937C102092498dcF4619F86) |

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

## Open Zeppelin Defender

[Open Zeppelin Defender v2](https://docs.openzeppelin.com/defender/v2/) is used to manage the Operations account and
automate AMM operational jobs like updating the primeETH exchange rate.

### Generate Relayer API key

The `Prime Staked` operator account is a [Defender v2 Relayer](https://defender.openzeppelin.com/v2/#/manage/relayers)
account with address
[0x5De069482Ac1DB318082477B7B87D59dfB313f91](https://etherscan.io/address/0x5De069482Ac1DB318082477B7B87D59dfB313f91).

To create an API key for the Relayer account go to the `Manage` tab on the top right of the Defender UI.

Click `Relayers` on the left menu and select the
[Prime Staked](https://defender.openzeppelin.com/v2/#/manage/relayers?relayerId=970f29e6-7063-4732-95c8-f80ccf8975e2)
Relayer.

Click the `Create new API Key` to get the new API key and secret.

Add the API key and secret to the `.env` file.

```bash
# Open Zeppelin Defender Relayer account API key
DEFENDER_RELAYER_KEY=
DEFENDER_RELAYER_SECRET=
```

> :warning: Remember to delete the API key when you are done using it.

### Deploying Defender Actions

Actions are used to run operational jobs are specific times or intervals.

[rollup](https://rollupjs.org/) is used to bundle Actions source code in
[/script/defender-actions](./script/defender-actions) into a single file that can be uploaded to Defender. The
implementation was based off
[Defender Actions example using Rollup](https://github.com/OpenZeppelin/defender-autotask-examples/tree/master/rollup).
The rollup config is in [/script/defender-actions/rollup.config.cjs](./script/defender-actions/rollup.config.cjs). The
outputs are written to task specific folders under [/script/defender-actions/dist](./script/defender-actions/dist/).

The [defender-autotask CLI](https://www.npmjs.com/package/@openzeppelin/defender-autotask-client) is used to upload the
Action code to Defender. For this to work, a Defender Team API key with `Manage Actions` capabilities is needed. This
can be generated by a Defender team admin under the `Manage` tab on the top right of the UI and then `API Keys` on the
left menu. Best to unselect all capabilities except `Manage Actions`.

Save the Defender Team API key and secret to your `.env` file.

```
# Open Zeppelin Defender Team API key
DEFENDER_TEAM_KEY=
DEFENDER_TEAM_SECRET=
```

The following will bundle the Actions code ready for upload.

```
cd ./script/defender-actions

npx rollup -c
```

The following will upload the different Action bundles to Defender.

```
# Deposit to EigenLayer
npx defender-autotask update-code 184e6533-9413-48be-ac01-4a63f87c3035 ./dist/depositAllEL
# Set the DEBUG environment variable to prime* for the Defender Action
npx hardhat setActionVars --id 184e6533-9413-48be-ac01-4a63f87c3035
```

`rollup` and `defender-autotask` can be installed globally to avoid the `npx` prefix.

### Defender Actions

| Name                           | ID                                                                                                                                    | Source Code                                                                          |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Prime - Deposit to EigenLayer  | [184e6533-9413-48be-ac01-4a63f87c3035](https://defender.openzeppelin.com/v2/#/actions/automatic/184e6533-9413-48be-ac01-4a63f87c3035) | [/script/defender-actions/updateRates.js](./script/defender-actions/depositAllEL.js) |
| Prime - primeETH Price Updater | [e5ab3a21-ed4d-4b0a-b07a-c3127a59895c](https://defender.openzeppelin.com/v2/#/actions/automatic/e5ab3a21-ed4d-4b0a-b07a-c3127a59895c) |                                                                                      |

# Credits

This repo was originally forked from [Kelp DAO](https://github.com/kelp-DAO/KelpDAO-contracts/). It's been further
developed by [Origin Protocol](https://www.originprotocol.com/) since January 2024.
