# EigneLayer M2 contracts on Holesky

## Strategy Manager
sol2uml 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 -v -o StrategyManager.svg -n holesky
sol2uml 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 -v -hv -hf -he -hs -hl -hi -o  StrategyManagerHierarchy.svg -n holesky
sol2uml 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 -v -s -d 0 -o  StrategyManagerSquashed.svg -n holesky
sol2uml 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 -v -s -hp -hm -ht -d 0 -o  StrategyManagerPublicSquashed.svg -n holesky
sol2uml storage 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 -v -c  StrategyManager -o StrategyManagerStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 -v -hv -d -s 0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6 -n holesky \
    -c StrategyManager -o StrategyManagerStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### M1 to M2 diff
sol2uml diff 0x5d25EEf8CfEdaA47d31fE2346726dE1c21e342Fb 0x59f766A603C53f3AC8Be43bBe158c1519b193a18 --bNetwork holesky -af "src/contracts/interfaces/IStrategyManager.sol"

## Delegation Manager
sol2uml 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 -v -o DelegationManager.svg -n holesky
sol2uml 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 -v -hv -hf -he -hs -hl -hi -o  DelegationManagerHierarchy.svg -n holesky
sol2uml 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 -v -s -d 0 -o  DelegationManagerSquashed.svg -n holesky
sol2uml 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 -v -s -hp -hm -ht -d 0 -o  DelegationManagerPublicSquashed.svg -n holesky
sol2uml storage 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 -v -c  DelegationManager -o DelegationManagerStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 -v -d -s 0xA44151489861Fe9e3055d95adC98FbD462B948e7 -n holesky \
    -c DelegationManager -o DelegationManagerStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### M1 to M2 diff
sol2uml diff 0xf97E97649Da958d290e84E6D571c32F4b7F475e4 0x83f8F8f0BB125F7870F6bfCf76853f874C330D76 --bNetwork holesky -af "src/contracts/interfaces/IDelegationManager.sol"


## EigenPodManager
sol2uml 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B -v -o EigenPodManager.svg -n holesky
sol2uml 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B -v -hv -hf -he -hs -hl -hi -o  EigenPodManagerHierarchy.svg -n holesky
sol2uml 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B -v -s -d 0 -o  EigenPodManagerSquashed.svg -n holesky
sol2uml 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B -v -s -hp -hm -ht -d 0 -o  EigenPodManagerPublicSquashed.svg -n holesky
sol2uml storage 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B -v -c  EigenPodManager -o EigenPodManagerStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B -v -d -s 0x30770d7E3e71112d7A6b7259542D1f680a70e315 -n holesky \
    -c EigenPodManager -o EigenPodManagerStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### M1 to M2 diff
sol2uml diff 0xEB86a5c40FdE917E6feC440aBbCDc80E3862e111 0x5265C162f7d5F3fE3175a78828ab16bf5E324a7B --bNetwork holesky -af "src/contracts/interfaces/IEigenPodManager.sol"


## StrategyBaseTVLLimits
sol2uml 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 -v -o Strategy.svg -n holesky
sol2uml 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 -v -hv -hf -he -hs -hl -hi -o  StrategyHierarchy.svg -n holesky
sol2uml 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 -v -s -hp -hm -ht -d 0 -o  StrategyPublicSquashed.svg -n holesky
sol2uml 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 -v -s -d 0 -o  StrategySquashed.svg -n holesky
sol2uml storage 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 -v -c  StrategyBaseTVLLimits -o StrategyStorage.svg --hideExpand  __gap -n holesky
# M2 on holesky stETH Strategy
sol2uml storage 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 -v -d -s 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3 -n holesky \
    -c StrategyBaseTVLLimits -o stETHStrategyStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
## M1 on mainnet OETH Strategy
sol2uml storage 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 -v -d -s 0xa4C637e0F704745D182e4D38cAb7E7485321d059 \
    -c StrategyBaseTVLLimits -o OETHStrategyStorageData.svg --hideExpand  __gap \
    --slotNames 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143,0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50,0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
### M1 to M2 diff
sol2uml diff 0xdfdA04f980bE6A64E3607c95Ca26012Ab9aA46d3 0xFb83e1D133D0157775eC4F19Ff81478Df1103305 --bNetwork holesky -af "src/contracts/interfaces/IStrategyManager.sol"

# Slasher
sol2uml 0x99715D255E34a39bE9943b82F281CA734bcF345A -v -o Slasher.svg -n holesky
sol2uml 0x99715D255E34a39bE9943b82F281CA734bcF345A -v -hv -hf -he -hs -hl -hi -o  SlasherHierarchy.svg -n holesky
sol2uml 0x99715D255E34a39bE9943b82F281CA734bcF345A -v -s -d 0 -o  SlasherSquashed.svg -n holesky
sol2uml 0x99715D255E34a39bE9943b82F281CA734bcF345A -v -s -hp -hm -ht -d 0 -o  SlasherPublicSquashed.svg -n holesky
sol2uml storage 0x99715D255E34a39bE9943b82F281CA734bcF345A -v -c  Slasher -o SlasherStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x99715D255E34a39bE9943b82F281CA734bcF345A -v -d -s 0xcAe751b75833ef09627549868A04E32679386e7C -c Slasher -o SlasherStorageData.svg --hideExpand  __gap -n holesky

