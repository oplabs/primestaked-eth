
# primeETH
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -o PrimeStakedETH.svg
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -hv -hf -he -hs -hl -hi -o PrimeStakedETHHierarchy.svg
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -s -hp -hm -ht -d 0 -o PrimeStakedETHPublicSquashed.svg
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -s -d 0 -o PrimeStakedETHSquashed.svg
sol2uml storage 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -c PrimeStakedETH -o PrimeStakedETHStorage.svg --hideExpand  __gap
sol2uml storage 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -s 0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615 -d -c PrimeStakedETH -o PrimeStakedETHStorageData.svg --hideExpand  __gap

# LRTDepositPool
sol2uml 0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2 -v -o LRTDepositPool.svg
sol2uml 0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2 -v -hv -hf -he -hs -hl -o LRTDepositPoolHierarchy.svg
sol2uml 0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2 -v -s -hp -hm -ht -d 0 -b LRTDepositPool -o LRTDepositPoolPublicSquashed.svg
sol2uml 0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2 -v -s -d 0 -b LRTDepositPool -o LRTDepositPoolSquashed.svg
sol2uml storage 0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2 -v -c LRTDepositPool -o LRTDepositPoolStorage.svg --hideExpand  __gap
sol2uml storage 0x93c9390DD6a17561D8E0ef3c96E2eD3633b119e2 -v -c LRTDepositPool -s 0xA479582c8b64533102F6F528774C536e354B8d32 -d -o LRTDepositPoolStorageData.svg -a 7 --hideExpand  __gap

# NodeDelegator
sol2uml 0xe5d7792DF6F6F11Dc584ECD91f472090f454A373 -v -o NodeDelegator.svg
sol2uml 0xe5d7792DF6F6F11Dc584ECD91f472090f454A373 -v -hv -hf -he -hs -hl -hi -o  NodeDelegatorHierarchy.svg
sol2uml 0xe5d7792DF6F6F11Dc584ECD91f472090f454A373 -v -s -hp -hm -ht -d 0 -o  NodeDelegatorPublicSquashed.svg
sol2uml 0xe5d7792DF6F6F11Dc584ECD91f472090f454A373 -v -s -d 0 -o  NodeDelegatorSquashed.svg
sol2uml storage 0xe5d7792DF6F6F11Dc584ECD91f472090f454A373 -v -c  NodeDelegator -o NodeDelegatorStorage.svg --hideExpand  __gap
sol2uml storage 0xe5d7792DF6F6F11Dc584ECD91f472090f454A373 -v -d -s 0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2 -c NodeDelegator -o NodeDelegatorStorageData.svg --hideExpand  __gap

# Config
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -o LRTConfig.svg
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -hv -hf -he -hs -hl -hi -o  LRTConfigHierarchy.svg
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -s -hp -hm -ht -d 0 -o  LRTConfigPublicSquashed.svg
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -s -d 0 -o  LRTConfigSquashed.svg
sol2uml storage 0xcdfD989e689872506E2897316b10e29c84AB087F -v -c  LRTConfig -o LRTConfigStorage.svg --hideExpand  __gap
sol2uml storage 0xcdfD989e689872506E2897316b10e29c84AB087F -v -d -s 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF -c LRTConfig -o LRTConfigStorageData.svg --hideExpand  __gap

# Oracle
sol2uml 0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14 -v -o LRTOracle.svg
sol2uml 0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14 -v -hv -hf -he -hs -hl -hi -o  LRTOracleHierarchy.svg
sol2uml 0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14 -v -s -hp -hm -ht -d 0 -o  LRTOraclePublicSquashed.svg
sol2uml 0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14 -v -s -d 0 -o  LRTOracleSquashed.svg
sol2uml storage 0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14 -v -c  LRTOracle -o LRTOracleStorage.svg --hideExpand  __gap
sol2uml storage 0x76f6f696869Cc42c49A24acB4fbaB17E3B8fEE14 -v -d -s 0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32 -c LRTOracle -o LRTOracleStorageData.svg --hideExpand  __gap
