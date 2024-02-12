# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
-include .env

# forge coverage

coverage :; forge coverage --report lcov && lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*'

# deployment commands
deploy-lrt-testnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url goerli  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-lrt-mainnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-lrt-local-test :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url localhost --broadcast -vvv

# deployment commands:PRETHRate
deploy-preth-rate-provider :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateProvider --rpc-url ${MAINNET_RPC_URL}   --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-preth-rate-receiver :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateReceiver --rpc-url ${POLYGON_ZKEVM_RPC_URL}  --broadcast --etherscan-api-key ${POLYSCAN_ZKEVM_API_KEY} --verify -vvv
deploy-preth-rate-local-test :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateReceiver --rpc-url localhost --broadcast -vvv

# verify commands
## example: contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet
## example: contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
verify-lrt-proxy-testnet :; forge verify-contract --chain-id 5 --watch --etherscan-api-key ${GOERLI_ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}
verify-lrt-proxy-mainnet :; forge verify-contract --chain-id 1 --watch --etherscan-api-key ${ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}

# transfer the ownership of the contracts to Multisig
transfer-ownership-testnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url goerli  --broadcast -vvv
transfer-ownership-mainnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${MAINNET_RPC_URL}  --broadcast -vvv -resume
transfer-ownership-fork :; IS_FORK=true forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url localhost --broadcast -vvv

# deploy minimal setup
minimal-deploy-testnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url goerli  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-mainnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-local-test :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url localhost --broadcast -vvv

# Deploy DeployPrimeStakedETH
deploy-token-testnet :; forge script script/foundry-scripts/DeployPrimeStakedETH.s.sol:DeployPrimeStakedETH --rpc-url goerli  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-token-mainnet :; forge script script/foundry-scripts/DeployPrimeStakedETH.s.sol:DeployPrimeStakedETH --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-token-fork :; IS_FORK=true forge script script/foundry-scripts/DeployPrimeStakedETH.s.sol:DeployPrimeStakedETH --rpc-url localhost --broadcast -vvv

# deploy the Assets
add-assets-mainnet :; forge script script/foundry-scripts/AddAssets.s.sol:AddAssets --rpc-url ${MAINNET_RPC_URL}  --broadcast -vvv
add-assets-fork :; IS_FORK=true forge script script/foundry-scripts/AddAssets.s.sol:AddAssets --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast -vvv

# set max depsoits
deposit-limits-mainnet :; forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url ${MAINNET_RPC_URL}  --broadcast
deposit-limits-fork :; IS_FORK=true forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast

# Deploy LRTDepositPool
deploy-deposit-pool-mainnet :; forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-deposit-pool-testnet :; forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url goerli  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-deposit-delegator-fork :; IS_FORK=true forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url localhost --broadcast -vvv
upgrade-deposit-delegator-local :; forge script script/foundry-scripts/DeployDepositPool.s.sol:DeployDepositPool --rpc-url localhost --broadcast -vvv

# Deploy NodeDelegator
deploy-node-delegator-mainnet :; forge script script/foundry-scripts/DeployNodeDelegator.s.sol:DeployNodeDelegator --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-node-delegator-fork :; IS_FORK=true forge script script/foundry-scripts/DeployNodeDelegator.s.sol:DeployNodeDelegator --rpc-url localhost --broadcast -vvv
upgrade-node-delegator-local :; forge script script/foundry-scripts/NodeDeDeployNodeDelegatorlegator.s.sol:DeployNodeDelegator --rpc-url localhost --broadcast -vvv

# Deploy LRTOracle
deploy-oracle-mainnet :; forge script script/foundry-scripts/DeployOracle.s.sol:DeployOracle --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-oracle-fork :; IS_FORK=true forge script script/foundry-scripts/DeployOracle.s.sol:DeployOracle --rpc-url localhost --broadcast -vvv
upgrade-oracle-local :; forge script script/foundry-scripts/DeployOracle.s.sol:DeployOracle --rpc-url localhost --broadcast -vvv

# Deploy ChainlinkPriceOracle
deploy-chainlink-mainnet :; forge script script/foundry-scripts/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-chainlink-fork :; IS_FORK=true forge script script/foundry-scripts/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle --rpc-url localhost --broadcast -vvv
upgrade-chainlink-local :; forge script script/foundry-scripts/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle --rpc-url localhost --broadcast -vvv

# Deploy NodeDelegator for native staking
deploy-nativeNodeDelegator-mainnet :; forge script script/foundry-scripts/DeployNativeStakingNodeDelegator.s.sol:DeployNativeStakingNodeDelegator --rpc-url ${MAINNET_RPC_URL}  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-nativeNodeDelegator-testnet :; forge script script/foundry-scripts/DeployNativeStakingNodeDelegator.s.sol:DeployNativeStakingNodeDelegator --rpc-url goerli  --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-nativeNodeDelegator-fork :; IS_FORK=true forge script script/foundry-scripts/upgradeNativeStakingNodeDelegator.s.sol:DeployNativeStakingNodeDelegator --rpc-url localhost --broadcast -vvv
upgrade-nativeNodeDelegator-local :; forge script script/foundry-scripts/DeployNativeStakingNodeDelegator.s.sol:DeployNativeStakingNodeDelegator --rpc-url localhost --broadcast -vvv

# Started a local forked node
ifneq ($(BLOCK_NUMBER),)
    BLOCK_PARAM=--fork-block-number=${BLOCK_NUMBER}
endif
node-fork:; anvil --fork-url ${MAINNET_RPC_URL} --auto-impersonate ${BLOCK_PARAM}

# test commands
unit-test:; forge test --no-match-contract "(Skip|IntegrationTest|ForkTest)"
int-test:; MAINNET_RPC_URL=localhost forge test --match-contract "IntegrationTest" --no-match-contract "Skip"
fork-test:; forge test --match-contract "ForkTest" --no-match-contract "Skip" -vv
fork-test-ci:; forge test --match-contract "ForkTest" --no-match-contract "Skip"