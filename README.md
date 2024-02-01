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

### Goerli testnet

| Contract Name           | Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x0000000000000000000000000000000000000000     |
| ProxyAdmin              | 0x0000000000000000000000000000000000000000     |
| ProxyAdmin Owner        | 0x0000000000000000000000000000000000000000     |

### Contract Implementations
| Contract Name           | Implementation Address                         |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x0000000000000000000000000000000000000000     |
| PrimeStakedETH                   | 0x0000000000000000000000000000000000000000     |
| LRTDepositPool          | 0x0000000000000000000000000000000000000000     |
| LRTOracle               | 0x0000000000000000000000000000000000000000     |
| ChainlinkPriceOracle    | 0x0000000000000000000000000000000000000000     |
| EthXPriceOracle         | 0x0000000000000000000000000000000000000000     |
| NodeDelegator           | 0x0000000000000000000000000000000000000000     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x0000000000000000000000000000000000000000     |
| PrimeStakedETH                   | 0x0000000000000000000000000000000000000000     |
| LRTDepositPool          | 0x0000000000000000000000000000000000000000     |
| LRTOracle               | 0x0000000000000000000000000000000000000000     |
| ChainlinkPriceOracle    | 0x0000000000000000000000000000000000000000     |
| EthXPriceOracle         | 0x0000000000000000000000000000000000000000     |

### NodeDelegator Proxy Addresses
- NodeDelegator proxy 1: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy 2: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy 3: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy 4: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy 5: 0x0000000000000000000000000000000000000000


### ETH Mainnet

| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x0000000000000000000000000000000000000000     |
| ProxyAdmin              | 0x0000000000000000000000000000000000000000     |
| ProxyAdmin Owner        | 0x0000000000000000000000000000000000000000    |

### Contract Implementations
| Contract Name           | Implementation Address                         |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x0000000000000000000000000000000000000000     |
| PrimeStakedETH                   | 0x0000000000000000000000000000000000000000     |
| LRTDepositPool          | 0x0000000000000000000000000000000000000000     |
| LRTOracle               | 0x0000000000000000000000000000000000000000     |
| ChainlinkPriceOracle    | 0x0000000000000000000000000000000000000000     |
| EthXPriceOracle         | 0x0000000000000000000000000000000000000000     |
| SfrxETHPriceOracle      | 0x0000000000000000000000000000000000000000     |
| NodeDelegator           | 0x0000000000000000000000000000000000000000     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x0000000000000000000000000000000000000000     |
| PrimeStakedETH                   | 0x0000000000000000000000000000000000000000     |
| LRTDepositPool          | 0x0000000000000000000000000000000000000000     |
| LRTOracle               | 0x0000000000000000000000000000000000000000     |
| ChainlinkPriceOracle    | 0x0000000000000000000000000000000000000000     |
| SfrxETHPriceOracle      | 0x0000000000000000000000000000000000000000     |
| EthXPriceOracle         | 0x0000000000000000000000000000000000000000     |

### NodeDelegator Proxy Addresses
- NodeDelegator proxy index 0: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy index 1: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy index 2: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy index 3: 0x0000000000000000000000000000000000000000
- NodeDelegator proxy index 4: 0x0000000000000000000000000000000000000000


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

