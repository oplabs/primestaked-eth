# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
-include .env

# forge coverage

coverage :; forge coverage --report lcov && lcov --remove lcov.info  -o lcov.info 'test/*' 'script/*'

# deployment commands
deploy-lrt-testnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url goerli  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

deploy-lrt-mainnet :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

deploy-lrt-local-test :; forge script script/foundry-scripts/DeployLRT.s.sol:DeployLRT --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deployment commands:LRTDepositPool
deploy-lrt-depositPool-testnet :; forge script script/foundry-scripts/DeployLRTDepositPool.s.sol:DeployLRTDepositPool --rpc-url goerli  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

deploy-lrt-depositPool-mainnet :; forge script script/foundry-scripts/DeployLRTDepositPool.s.sol:DeployLRTDepositPool --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

deploy-lrt-depositPool-local-test :; forge script script/foundry-scripts/DeployLRTDepositPool.s.sol:DeployLRTDepositPool --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deployment commands:PRETHRate
deploy-preth-rate-provider :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateProvider --rpc-url ${MAINNET_RPC_URL}   --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

deploy-preth-rate-receiver :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateReceiver --rpc-url ${POLYGON_ZKEVM_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${POLYSCAN_ZKEVM_API_KEY} --verify -vvv

deploy-preth-rate-local-test :; forge script script/foundry-scripts/cross-chain/PRETHRate.s.sol:DeployPRETHRateReceiver --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# upgrade commands
upgrade-lrt-testnet :; forge script script/foundry-scripts/UpgradeLRT.s.sol:UpgradeLRT --rpc-url goerli  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

upgrade-lrt-mainnet :; forge script script/foundry-scripts/UpgradeLRT.s.sol:UpgradeLRT --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

upgrade-lrt-local-test :; forge script script/foundry-scripts/UpgradeLRT.s.sol:UpgradeLRT --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# verify commands
## example: contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet
## example: contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
verify-lrt-proxy-testnet :; forge verify-contract --chain-id 5 --watch --etherscan-api-key ${GOERLI_ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}

verify-lrt-proxy-mainnet :; forge verify-contract --chain-id 1 --watch --etherscan-api-key ${ETHERSCAN_API_KEY} ${contractAddress} ${contractPath}

# transfer the ownership of the contracts to Multisig
transfer-ownership-testnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url goerli  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

transfer-ownership-mainnet :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

transfer-ownership-local-test :; forge script script/foundry-scripts/TransferOwnership.s.sol:TransferOwnership --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# deploy minimal setup
minimal-deploy-testnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url goerli  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

minimal-deploy-mainnet :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

minimal-deploy-local-test :; forge script script/foundry-scripts/DeployMinimal.s.sol:DeployMinimal --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv

# upgrade prime staked eth token contract
upgrade-token-testnet :; forge script script/foundry-scripts/UpgradePimeStakedToken.s.sol:UpgradePimeStakedToken --rpc-url goerli  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

upgrade-token-mainnet :; forge script script/foundry-scripts/UpgradePimeStakedToken.s.sol:UpgradePimeStakedToken --rpc-url ${MAINNET_RPC_URL}  --private-key ${DEPLOYER_PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify -vvv

upgrade-token-local-test :; forge script script/foundry-scripts/UpgradePimeStakedToken.s.sol:UpgradePimeStakedToken --rpc-url localhost --private-key ${LOCAL_DEPLOYER_PRIVATE_KEY} --broadcast -vvv