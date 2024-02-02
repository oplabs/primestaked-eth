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
| ProxyFactory            | 0x71626BD4f31Cb6B10D581E5715a76eeacAd01fa4     |
| ProxyAdmin              | 0x22b65a789d3778c0bA1A5bc7C01958e657703fA8     |
| ProxyAdmin Owner        | 0xb3d125BCab278bD478CA251ae6b34334ad89175f     |

### Contract Implementations
| Contract Name           | Implementation Address                         |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x266e084412E0DeF3Cc49Bc75534F93f4Ba9DC0c8     |
| PrimeStakedETH          | 0x6C7Ec5Fd2a69F32b77e32AE308c182f305856f4c     |
| LRTDepositPool          | 0x74210d38A0a904816BbC5C1312ed6F4E9DD6Bdd8     |
| LRTOracle               | 0xA51Ffe145664cb2a14DFd9c72Df7c971525311B6     |
| ChainlinkPriceOracle    | 0x0Aea9eaFa79925cd43F19Fb2E591E5f9e40B25F1     |
| EthXPriceOracle         | 0xF63aC2e26868453b8527491707803B46FC163Ea6     |
| NodeDelegator           | 0x91b3792fF160BbeE2D2f6500e01EA335aaEb27B5     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x4BF4cc0e5970Cee11D67f5d716fF1241fA593ca4     |
| PrimeStakedETH          | 0xA265e2387fc0da67CB43eA6376105F3Df834939a     |
| LRTDepositPool          | 0x551125a39bCf4E85e9B62467DfD2c1FeF3998f19     |
| LRTOracle               | 0xDE2336F1a4Ed7749F08F994785f61b5995FcD560     |
| ChainlinkPriceOracle    | 0x46E6D75E5784200F21e4cCB7d8b2ff8e20996f52     |
| EthXPriceOracle         | 0x4df5Cea2954CEafbF079c2d23a9271681D15cf67     |

### NodeDelegator Proxy Addresses
- NodeDelegator proxy 1: 0xfFEB12Eb6C339E1AAD48A7043A98779F6bF03Cfd
- NodeDelegator proxy 2: 0x75ed72715efD40BA7920d8a19f6b10C7e63c7710
- NodeDelegator proxy 3: 0xD0B5758FB00AFd5731fB9FB78882967bD93Ae740
- NodeDelegator proxy 4: 0x1ae9fCD7b7b165F6CDb192446CB42260497eA0D2
- NodeDelegator proxy 5: 0xf7867381f562e47F0b3243FCC51552bcf6757A63


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
| ChainlinkPriceOracle    | 0x0000000000000000000000000000000000000000     |
| EthXPriceOracle         | 0x0000000000000000000000000000000000000000     |
| SfrxETHPriceOracle      | 0x0000000000000000000000000000000000000000     |
| NodeDelegator           | 0x0000000000000000000000000000000000000000     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF     |
| PrimeStakedETH          | 0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615     |
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

