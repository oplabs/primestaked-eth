# LRT-ETH

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
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

## Deploy to testnet

```bash
make deploy-lrt-testnet
```

## For tests (mainnet) using Anvil:

In one terminal run the Anvil node forking the mainnet
```bash
make node-fork
```

In another terminal apply the deploys that are not yet on mainnet.
```bash
make pool-deleg-oracle-fork
make add-assets-fork
...
```

Run mainnet fork tests (not yet working)
```bash
make test-fork
```

## Deploy to Anvil:

```bash
make deploy-lrt-local-test
```

### General Deploy Script Instructions

Create a Deploy script in `script/Deploy.s.sol`:

and run the script:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.


## Verify Contracts

Follow this pattern
`contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet`

Example:
```bash
contractAddress=0x0000000000000000000000000000000000000000 contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
```


### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ npm lint
```

### Test

Run the tests:

```sh
$ forge test
```

Generate test coverage and output result to the terminal:

```sh
$ npm test:coverage
```

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ npm test:coverage:report
```

## Deployed Contracts

### ETH Mainnet

| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x279b272E8266D2fd87e64739A8ecD4A5c94F953D     |
| ProxyAdmin              | 0xF83cacA1bC89e4C7f93bd17c193cD98fEcc6d758     |
| ProxyAdmin Owner        | 0x7fbd78ae99151A3cfE46824Cd6189F28c8C45168    |

### Contract Implementations
| Contract Name           | Implementation Address                         |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0xcdfD989e689872506E2897316b10e29c84AB087F     |
| PrimeStakedETH          | 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2     |
| LRTDepositPool          | 0x0000000000000000000000000000000000000000     |
| LRTOracle               | 0x0000000000000000000000000000000000000000     |
| ChainlinkPriceOracle    | 0x255C082Fb505212BA2396EDbF621d8aF1e5D29A5     |
| OethPriceOracle         | 0xd91d3bEC19E921e911A487394B155da552953917     |
| EthXPriceOracle         | 0xd101bd159968106595d48948677fee9e8a0450a9     |
| SfrxETHPriceOracle      | 0xE6BebE3072fF42a7c2A4A5a9864b30Bc5608d9C3     |
| NodeDelegator           | 0x0000000000000000000000000000000000000000     |
| MEthPriceOracle         | 0x91Fad4007FF129ABFB72d0701C200f0957e9a0D8     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF     |
| PrimeStakedETH          | 0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615     |
| LRTDepositPool          | 0x0000000000000000000000000000000000000000     |
| LRTOracle               | 0x0000000000000000000000000000000000000000     |
| ChainlinkPriceOracle    | 0xE238124CD0E1D15D1Ab08DB86dC33BDFa545bF09     |
| OethPriceOracle         | 0xc513bDfbC308bC999cccc852AF7C22aBDF44A995     |
| SfrxETHPriceOracle      | 0x407d53b380A4A05f8dce5FBd775DF51D1DC0D294     |
| EthXPriceOracle         | 0x85B4C05c9dC3350c220040BAa48BD0aD914ad00C     |
| MEthPriceOracle         | 0xE709cee865479Ae1CF88f2f643eF8D7e0be6e369     |

### NodeDelegator Proxy Addresses
- NodeDelegator proxy index 0: 0x0000000000000000000000000000000000000000


### Immutable Contracts
#### ETH Mainnet
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| PrimeStakedETHRateProvider       | 0x0000000000000000000000000000000000000000     |
| OneETHPriceOracle       | 0x0000000000000000000000000000000000000000     |
| PRETHPriceFeed (Morph)  | 0x0000000000000000000000000000000000000000     |

#### Polygon ZKEVM
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| PrimeStakedETHRateReceiver       |  0x0000000000000000000000000000000000000000    |

