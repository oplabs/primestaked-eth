# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
-include .env

# forge coverage

coverage :; forge coverage --report lcov && lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*'

# deployment commands
deploy-lrt-testnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url goerli  --private-key ${GOERLI_DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-lrt-mainnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-lrt-local-test :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deployment commands:LRTDepositPool
deploy-lrt-depositPool-testnet :; forge script script/foundry-scripts/DeployLRTDepositPool.s.sol:DeployLRTDepositPool --rpc-url goerli  --private-key ${GOERLI_DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-lrt-depositPool-mainnet :; forge script script/foundry-scripts/DeployLRTDepositPool.s.sol:DeployLRTDepositPool --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-lrt-depositPool-local-test :; forge script script/foundry-scripts/DeployLRTDepositPool.s.sol:DeployLRTDepositPool --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deployment commands:PRETHRate
deploy-preth-rate-provider :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateProvider --rpc-url ${MAINNET_RPC_URL}   --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
deploy-preth-rate-receiver :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateReceiver --rpc-url ${POLYGON_ZKEVM_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${POLYSCAN_ZKEVM_API_KEY} --verify -vvv
deploy-preth-rate-local-test :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateReceiver --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# upgrade commands
upgrade-lrt-testnet :; forge script script/foundry-scripts/UpgradeLRT.s.sol:UpgradeLRT --rpc-url goerli  --private-key ${GOERLI_DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-lrt-mainnet :; forge script script/foundry-scripts/UpgradeLRT.s.sol:UpgradeLRT --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-lrt-local-test :; forge script script/foundry-scripts/UpgradeLRT.s.sol:UpgradeLRT --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# verify commands
## example: contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet
## example: contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
verify-lrt-proxy-testnet :; forge verify-contract --chain-id 5 --watch --etherscan-api-key ${GOERLI_ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}
verify-lrt-proxy-mainnet :; forge verify-contract --chain-id 1 --watch --etherscan-api-key ${ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}

# transfer the ownership of the contracts to Multisig
transfer-ownership-testnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url goerli  --private-key ${GOERLI_DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
transfer-ownership-mainnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
transfer-ownership-fork :; IS_FORK=true forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deploy minimal setup
minimal-deploy-testnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url goerli  --private-key ${GOERLI_DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-mainnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
minimal-deploy-local-test :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# upgrade prime staked eth token contract
upgrade-token-testnet :; forge script script/foundry-scripts/UpgradePimeStakedToken.s.sol:UpgradePrimeStakedToken --rpc-url goerli  --private-key ${GOERLI_DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-token-mainnet :; forge script script/foundry-scripts/UpgradePimeStakedToken.s.sol:UpgradePrimeStakedToken --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
upgrade-token-fork :; IS_FORK=true forge script script/foundry-scripts/UpgradePrimeStakedToken.s.sol:UpgradePimeStakedToken --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deploy the Deposit pool, node delegator and LRTOracle
pool-deleg-oracle-mainnet :; forge script script/foundry-scripts/DeployDelegatorPoolOracle.s.sol:DeployDelegatorPoolOracle --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv
pool-deleg-oracle-fork :; IS_FORK=true forge script script/foundry-scripts/DeployDelegatorPoolOracle.s.sol:DeployDelegatorPoolOracle --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast -vvv

# deploy the Assets
add-assets-mainnet :; forge script script/foundry-scripts/AddAssets.s.sol:AddAssets --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast -vvv
add-assets-fork :; IS_FORK=true forge script script/foundry-scripts/AddAssets.s.sol:AddAssets --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast -vvv

# set max depsoits
deposit-limits-mainnet :; forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast
deposit-limits-fork :; IS_FORK=true forge script script/foundry-scripts/UpdateDepositLimits.s.sol:UpdateDepositLimits --rpc-url localhost --sender ${MAINNET_PROXY_AMIN_OWNER} --unlocked --broadcast

# utils
node-fork:; anvil --fork-url ${MAINNET_RPC_URL} --auto-impersonate

# test commands
unit-test:; forge test --no-match-contract "(Skip|IntegrationTest|ForkTest)"
int-test:; MAINNET_RPC_URL=localhost forge test --match-contract "IntegrationTest" --no-match-contract "Skip"
fork-test:; forge test --match-contract "ForkTest" --no-match-contract "Skip" -vvv
fork-test-ci:; forge test --match-contract "ForkTest" --no-match-contract "Skip"