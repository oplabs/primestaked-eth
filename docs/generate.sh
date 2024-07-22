
# primeETH
sol2uml 0x5991C233B26278d6d31b6A9d06444de3cb7C74A3 -v -o PrimeStakedETH.svg -n holesky
sol2uml 0x5991C233B26278d6d31b6A9d06444de3cb7C74A3 -v -hv -hf -he -hs -hl -hi -o PrimeStakedETHHierarchy.svg -n holesky
sol2uml 0x5991C233B26278d6d31b6A9d06444de3cb7C74A3 -v -s -hp -hm -ht -d 0 -o PrimeStakedETHPublicSquashed.svg -n holesky
sol2uml 0x5991C233B26278d6d31b6A9d06444de3cb7C74A3 -v -s -d 0 -o PrimeStakedETHSquashed.svg -n holesky
sol2uml storage 0x5991C233B26278d6d31b6A9d06444de3cb7C74A3 -v -c PrimeStakedETH -o PrimeStakedETHStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x5991C233B26278d6d31b6A9d06444de3cb7C74A3 -v -s 0x32f189fD8d33603055D58CF7B342bF44cc91C46B -d -c PrimeStakedETH -o PrimeStakedETHStorageData.svg --hideExpand  __gap -n holesky

# LRTDepositPool
sol2uml 0x700e67F5aD018CdFe9aaF4C9f98Fe011d9c9513a -v -o LRTDepositPool.svg -n holesky
sol2uml 0x700e67F5aD018CdFe9aaF4C9f98Fe011d9c9513a -v -hv -hf -he -hs -hl -hi -o LRTDepositPoolHierarchy.svg -n holesky
sol2uml 0x700e67F5aD018CdFe9aaF4C9f98Fe011d9c9513a -v -s -hp -hm -ht -d 0 -b LRTDepositPool -o LRTDepositPoolPublicSquashed.svg -n holesky
sol2uml 0x700e67F5aD018CdFe9aaF4C9f98Fe011d9c9513a -v -s -d 0 -b LRTDepositPool -o LRTDepositPoolSquashed.svg -n holesky
sol2uml storage 0x700e67F5aD018CdFe9aaF4C9f98Fe011d9c9513a -v -c LRTDepositPool -o LRTDepositPoolStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x700e67F5aD018CdFe9aaF4C9f98Fe011d9c9513a -v -c LRTDepositPool -s 0x7C0c0Df65778709524d7b048D184c45E90DE041d -d -o LRTDepositPoolStorageData.svg -a 7 --hideExpand  __gap -n holesky

# NodeDelegatorLST
sol2uml 0x93668e0aD0EaA88a00eB76f0E6aC97dff8De5622 -v -o NodeDelegatorLST.svg -n holesky
sol2uml 0x93668e0aD0EaA88a00eB76f0E6aC97dff8De5622 -v -hv -hf -he -hs -hl -hi -o  NodeDelegatorLSTHierarchy.svg -n holesky
sol2uml 0x93668e0aD0EaA88a00eB76f0E6aC97dff8De5622 -v -s -hp -hm -ht -d 0 -o  NodeDelegatorLSTPublicSquashed.svg -n holesky
sol2uml 0x93668e0aD0EaA88a00eB76f0E6aC97dff8De5622 -v -s -d 0 -o  NodeDelegatorLSTSquashed.svg -n holesky
sol2uml storage 0x93668e0aD0EaA88a00eB76f0E6aC97dff8De5622 -v -c  NodeDelegatorLST -o NodeDelegatorLSTStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x93668e0aD0EaA88a00eB76f0E6aC97dff8De5622 -v -d -s 0x326EdC668E286cc71272154977DB2bCf780d42B4 -c NodeDelegatorLST -o NodeDelegatorLSTStorageData.svg --hideExpand  __gap -n holesky

# NodeDelegatorETH
sol2uml 0x48070E13C07c258d76775a0D7f6Fb6dE4141f3fC -v -o NodeDelegatorETH.svg -n holesky
sol2uml 0x48070E13C07c258d76775a0D7f6Fb6dE4141f3fC -v -hv -hf -he -hs -hl -hi -o  NodeDelegatorETHHierarchy.svg -n holesky
sol2uml 0x48070E13C07c258d76775a0D7f6Fb6dE4141f3fC -v -s -hp -hm -ht -d 0 -o  NodeDelegatorETHPublicSquashed.svg -n holesky
sol2uml 0x48070E13C07c258d76775a0D7f6Fb6dE4141f3fC -v -s -d 0 -o  NodeDelegatorETHSquashed.svg -n holesky
sol2uml storage 0x48070E13C07c258d76775a0D7f6Fb6dE4141f3fC -v -c  NodeDelegatorETH -o NodeDelegatorETHStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x48070E13C07c258d76775a0D7f6Fb6dE4141f3fC -v -d -s 0x94B5ac4A1Ae76F150A25537Ec1684B94fe8025CD -c NodeDelegatorETH -o NodeDelegatorETHStorageData.svg --hideExpand  __gap -n holesky

# Config
sol2uml 0xF5bc3c3F492240CE49B18CbF78443dB527b31A94 -v -o LRTConfig.svg -n holesky
sol2uml 0xF5bc3c3F492240CE49B18CbF78443dB527b31A94 -v -hv -hf -he -hs -hl -hi -o  LRTConfigHierarchy.svg -n holesky
sol2uml 0xF5bc3c3F492240CE49B18CbF78443dB527b31A94 -v -s -hp -hm -ht -d 0 -o  LRTConfigPublicSquashed.svg -n holesky
sol2uml 0xF5bc3c3F492240CE49B18CbF78443dB527b31A94 -v -s -d 0 -o  LRTConfigSquashed.svg -n holesky
sol2uml storage 0xF5bc3c3F492240CE49B18CbF78443dB527b31A94 -v -c  LRTConfig -o LRTConfigStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0xF5bc3c3F492240CE49B18CbF78443dB527b31A94 -v -d -s 0xC1b4F3B373c7a766C5f8587940180396593Acfe7 -c LRTConfig -o LRTConfigStorageData.svg --hideExpand  __gap -n holesky

# Oracle
sol2uml 0x494e02e12a97ACb614167030123b9Ee5BE15AEAF -v -o LRTOracle.svg -n holesky
sol2uml 0x494e02e12a97ACb614167030123b9Ee5BE15AEAF -v -hv -hf -he -hs -hl -hi -o  LRTOracleHierarchy.svg -n holesky
sol2uml 0x494e02e12a97ACb614167030123b9Ee5BE15AEAF -v -s -hp -hm -ht -d 0 -o  LRTOraclePublicSquashed.svg -n holesky
sol2uml 0x494e02e12a97ACb614167030123b9Ee5BE15AEAF -v -s -d 0 -o  LRTOracleSquashed.svg -n holesky
sol2uml storage 0x494e02e12a97ACb614167030123b9Ee5BE15AEAF -v -c  LRTOracle -o LRTOracleStorage.svg --hideExpand  __gap -n holesky
sol2uml storage 0x494e02e12a97ACb614167030123b9Ee5BE15AEAF -v -d -s 0x60d01fb0a13a5dECf42dEFADB48E2288A9c0acd1 -c LRTOracle -o LRTOracleStorageData.svg --hideExpand  __gap -n holesky

# PrimeZapper
sol2uml 0x090cEeF3E7A9733F47988984F182F2680bFfdDac -v -o PrimeZapper.svg -n holesky
sol2uml 0x090cEeF3E7A9733F47988984F182F2680bFfdDac -v -s -hp -hm -ht -d 0 -o  PrimeZapperPublicSquashed.svg -n holesky
sol2uml 0x090cEeF3E7A9733F47988984F182F2680bFfdDac -v -s -d 0 -o  PrimeZapperSquashed.svg -n holesky
