# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
-include .env

# forge coverage

coverage :; forge coverage --report lcov && lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*'

# Deploy to Goerli testnet
deploy-testnet :; forge script script/foundry-scripts/goerli/deployGoerli.s.sol:DeployGoerli --rpc-url ${GOERLI_RPC_URL}  --broadcast --etherscan-api-key ${GOERLI_ETHERSCAN_API_KEY} --verify --slow -vvv
deploy-testnet-local :; forge script script/foundry-scripts/goerli/deployGoerli.s.sol:DeployGoerli --rpc-url localhost --broadcast --slow -vvv
deploy-testnet-fork :; IS_FORK=true forge script script/foundry-scripts/goerli/deployGoerli.s.sol:DeployGoerli --rpc-url localhost -vvv

# verify commands
## example: contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet
## example: contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
verify-contract-testnet :; forge verify-contract --chain-id 5 --watch --etherscan-api-key ${GOERLI_ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}
verify-contract-mainnet :; forge verify-contract --chain-id 1 --watch --etherscan-api-key ${ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}

# transfer the ownership of the contracts to Multisig
transfer-ownership-testnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${GOERLI_RPC_URL}  --broadcast -vvv
transfer-ownership-mainnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${MAINNET_RPC_URL}  --broadcast -vvv -resume
transfer-ownership-fork :; IS_FORK=true forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url localhost --broadcast -vvv

# deploy minimal setup
minimal-deploy-testnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${GOERLI_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
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
node-test-fork:; anvil --fork-url ${GOERLI_RPC_URL} --auto-impersonate ${BLOCK_PARAM}

# test commands
unit-test:; forge test --no-match-contract "(Skip|IntegrationTest|Fork)"
int-test:; MAINNET_RPC_URL=localhost forge test --match-contract "IntegrationTest" --no-match-contract "Skip"
fork-test:; IS_FORK=true forge test --match-contract "ForkTest" --no-match-contract "Skip" -vv
fork-test-goerli:; IS_FORK=true forge test --match-contract "ForkGoerliTest" -vv
fork-test-ci:; IS_FORK=true forge test --match-contract "ForkTest" --no-match-contract "Skip"