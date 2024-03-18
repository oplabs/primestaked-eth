# EigneLayer Mainnet M1 contracts

## Strategy Manager
sol2uml 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb -v -o StrategyManager.svg
sol2uml 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb -v -hv -hf -he -hs -hl -hi -o  StrategyManagerHierarchy.svg
sol2uml 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb -v -s -d 0 -o  StrategyManagerSquashed.svg
sol2uml 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb -v -s -hp -hm -ht -d 0 -o  StrategyManagerPublicSquashed.svg
sol2uml storage 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb -v -c  StrategyManager -o StrategyManagerStorage.svg --hideExpand  __gap
sol2uml storage 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb -v -hv -d -s 0x858646372CC42E1A627fcE94aa7A7033e7CF075A \
    -c StrategyManager -o StrategyManagerStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### diff M1 to M2 StrategyManager interface
sol2uml diff 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb 0x506C21f43e81D9d231d8A13831b42A2a2B5540E4 --bNetwork goerli -af "src/contracts/interfaces/IStrategyManager.sol"

## Delegation Manager
sol2uml 0xf97e97649da958d290e84e6d571c32f4b7f475e4 -v -o DelegationManager.svg
sol2uml 0xf97e97649da958d290e84e6d571c32f4b7f475e4 -v -hv -hf -he -hs -hl -hi -o  DelegationManagerHierarchy.svg
sol2uml 0xf97e97649da958d290e84e6d571c32f4b7f475e4 -v -s -d 0 -o  DelegationManagerSquashed.svg
sol2uml 0xf97e97649da958d290e84e6d571c32f4b7f475e4 -v -s -hp -hm -ht -d 0 -o  DelegationManagerPublicSquashed.svg
sol2uml storage 0xf97e97649da958d290e84e6d571c32f4b7f475e4 -v -c  DelegationManager -o DelegationManagerStorage.svg --hideExpand  __gap
sol2uml storage 0xf97e97649da958d290e84e6d571c32f4b7f475e4 -v -d -s 0x39053d51b77dc0d36036fc1fcc8cb819df8ef37a \
    -c DelegationManager -o DelegationManagerStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103

## EigenPodManager
sol2uml 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 -v -o EigenPodManager.svg
sol2uml 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 -v -hv -hf -he -hs -hl -hi -o  EigenPodManagerHierarchy.svg
sol2uml 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 -v -s -d 0 -o  EigenPodManagerSquashed.svg
sol2uml 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 -v -s -hp -hm -ht -d 0 -o  EigenPodManagerPublicSquashed.svg
sol2uml storage 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 -v -c  EigenPodManager -o EigenPodManagerStorage.svg --hideExpand  __gap
sol2uml storage 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 -v -d -s 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338 \
    -c EigenPodManager -o EigenPodManagerStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### diff M1 to M2 EigenPodManager interface
sol2uml diff 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 0xDA9B60D3dC7adD40C0e35c628561Ff71C13a189f --bNetwork goerli -af "src/contracts/interfaces/IEigenPodManager.sol"


## StrategyBaseTVLLimits
sol2uml 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -o Strategy.svg
sol2uml 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -hv -hf -he -hs -hl -hi -o  StrategyHierarchy.svg
sol2uml 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -s -hp -hm -ht -d 0 -o  StrategyPublicSquashed.svg
sol2uml 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -s -d 0 -o  StrategySquashed.svg
sol2uml storage 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -c  StrategyBaseTVLLimits -o StrategyStorage.svg --hideExpand  __gap
# stETH Strategy
sol2uml storage 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -d -s 0x93c4b944D05dfe6df7645A86cd2206016c51564D \
    -c StrategyBaseTVLLimits -o stETHStrategyStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
## OETH Strategy
sol2uml storage 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -d -s 0xa4C637e0F704745D182e4D38cAb7E7485321d059 \
    -c StrategyBaseTVLLimits -o OETHStrategyStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### diff M1 to M2 StrategyBaseTVLLimits interface
sol2uml diff 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 0x81E94e16949AC397d508B5C2557a272faD2F8ebA --bNetwork goerli -af "src/contracts/interfaces/IStrategyManager.sol"

# Slasher
sol2uml 0xef31c292801f24f16479DD83197F1E6AeBb8d6d8 -v -o Slasher.svg
sol2uml 0xef31c292801f24f16479DD83197F1E6AeBb8d6d8 -v -hv -hf -he -hs -hl -hi -o  SlasherHierarchy.svg
sol2uml 0xef31c292801f24f16479DD83197F1E6AeBb8d6d8 -v -s -d 0 -o  SlasherSquashed.svg
sol2uml 0xef31c292801f24f16479DD83197F1E6AeBb8d6d8 -v -s -hp -hm -ht -d 0 -o  SlasherPublicSquashed.svg
sol2uml storage 0xef31c292801f24f16479DD83197F1E6AeBb8d6d8 -v -c  Slasher -o SlasherStorage.svg --hideExpand  __gap
sol2uml storage 0xef31c292801f24f16479DD83197F1E6AeBb8d6d8 -v -d -s 0xD92145c07f8Ed1D392c1B88017934E301CC1c3Cd -c Slasher -o SlasherStorageData.svg --hideExpand  __gap

