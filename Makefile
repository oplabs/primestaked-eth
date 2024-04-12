# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
-include .env

# forge coverage

coverage :; forge coverage --report lcov && lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*'

# Deploy to Holesky testnet
deploy-holesky :; forge script script/foundry-scripts/holesky/deployHolesky.s.sol:DeployHolesky --rpc-url ${HOLESKY_RPC_URL}  --broadcast --etherscan-api-key ${HOLESKY_ETHERSCAN_API_KEY} --verify --slow -vvv
deploy-holesky-local :; forge script script/foundry-scripts/holesky/deployHolesky.s.sol:DeployHolesky --rpc-url localhost --broadcast --slow -vvv
deploy-holesky-fork :; IS_FORK=true forge script script/foundry-scripts/holesky/deployHolesky.s.sol:DeployHolesky --rpc-url localhost -vvv

# verify commands
## example: contractAddress=<contractAddress> contractPath=<contract-path> make verify-contract-testnet
## example: contractAddress=<contractAddress> contractPath=<contract-path> argsFile=args.txt make verify-contract-testnet
## example: contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-contract-testnet
# example with constructor args
# contractAddress=0x8F4d72289f89C62B4CbA974934FACba7843A28F8 contractPath=contracts/NodeDelegator.sol:NodeDelegator argsFile=args.txt make verify-contract-testnet
ifneq ($(argsFile),)
    CONSTRUCTOR_ARGS=--constructor-args-path ${argsFile}
endif
verify-contract-testnet :; forge verify-contract --chain-id 17000 --watch --etherscan-api-key ${HOLESKY_ETHERSCAN_API_KEY} ${contractAddress} ${contractPath} ${CONSTRUCTOR_ARGS}
verify-contract-mainnet :; forge verify-contract --chain-id 1 --watch --etherscan-api-key ${ETHERSCAN_API_KEY} ${contractAddress} ${contractPath} ${CONSTRUCTOR_ARGS}

# transfer the ownership of the contracts to Multisig
transfer-ownership-testnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${HOLESKY_RPC_URL}  --broadcast -vvv
transfer-ownership-mainnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${MAINNET_RPC_URL}  --broadcast -vvv -resume
transfer-ownership-fork :; IS_FORK=true forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url localhost --broadcast -vvv

# deploy minimal setup
minimal-deploy-testnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${HOLESKY_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-mainnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-local-test :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url localhost --broadcast -vvv

# set max depsoits
deposit-limits-mainnet :; forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url ${MAINNET_RPC_URL}  --broadcast
deposit-limits-fork :; IS_FORK=true forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast

# deploy restaking of Native ETH
deploy-native-mainnet :; forge script script/foundry-scripts/mainnet/10_deployNativeETH.s.sol:DeployNativeETH --rpc-url ${MAINNET_RPC_URL}  --broadcast --slow --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-native-fork :; IS_FORK=true forge script script/foundry-scripts/mainnet/10_deployNativeETH.s.sol:DeployNativeETH --rpc-url localhost -vvv
deploy-native-local :; forge script script/foundry-scripts/mainnet/10_deployNativeETH.s.sol:DeployNativeETH --rpc-url localhost --broadcast --slow -vvv

# Started a local forked node
ifneq ($(BLOCK_NUMBER),)
    BLOCK_PARAM=--fork-block-number=${BLOCK_NUMBER}
endif

node-fork:; anvil --fork-url ${MAINNET_RPC_URL} --auto-impersonate ${BLOCK_PARAM}
node-test-fork:; anvil --fork-url ${HOLESKY_RPC_URL} --auto-impersonate ${BLOCK_PARAM}

# test commands
unit-test:; forge test --no-match-contract "(Skip|IntegrationTest|Fork)"
int-test:; MAINNET_RPC_URL=localhost forge test --match-contract "IntegrationTest" --no-match-contract "Skip"
fork-test:; IS_FORK=true forge test --match-contract "ForkTest" --no-match-contract "Skip" -vv
fork-test-goerli:; IS_FORK=true forge test --match-contract "ForkGoerliTest" -vvip" -vv
fork-test-holesky:; IS_FORK=true forge test --match-contract "ForkHoleskyTest" -vv
fork-test-ci:; IS_FORK=true forge test --match-contract "ForkTest" --no-match-contract "Skip"