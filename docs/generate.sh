
# primeETH
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -o PrimeStakedETH.svg
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -hv -hf -he -hs -hl -hi -o PrimeStakedETHHierarchy.svg
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -s -hp -hm -ht -d 0 -o PrimeStakedETHPublicSquashed.svg
sol2uml 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -s -d 0 -o PrimeStakedETHSquashed.svg
sol2uml storage 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -c PrimeStakedETH -o PrimeStakedETHStorage.svg --hideExpand  __gap
sol2uml storage 0xd2fA8845c0998b327E25CcE94dbf8cafE8D234A2 -v -s 0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615 -d -c PrimeStakedETH -o PrimeStakedETHStorageData.svg --hideExpand  __gap

# LRTDepositPool
sol2uml 0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0 -v -o LRTDepositPool.svg
sol2uml 0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0 -v -hv -hf -he -hs -hl -o LRTDepositPoolHierarchy.svg
sol2uml 0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0 -v -s -hp -hm -ht -d 0 -b LRTDepositPool -o LRTDepositPoolPublicSquashed.svg
sol2uml 0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0 -v -s -d 0 -b LRTDepositPool -o LRTDepositPoolSquashed.svg
sol2uml storage 0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0 -v -c LRTDepositPool -o LRTDepositPoolStorage.svg --hideExpand  __gap
sol2uml storage 0x8fb3c5152EeE3e2E3531f741DADd54323e9b2fa0 -v -c LRTDepositPool -s 0xA479582c8b64533102F6F528774C536e354B8d32 -d -o LRTDepositPoolStorageData.svg -a 7 --hideExpand  __gap

# NodeDelegator
sol2uml 0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4 -v -o NodeDelegator.svg
sol2uml 0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4 -v -hv -hf -he -hs -hl -hi -o  NodeDelegatorHierarchy.svg
sol2uml 0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4 -v -s -hp -hm -ht -d 0 -o  NodeDelegatorPublicSquashed.svg
sol2uml 0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4 -v -s -d 0 -o  NodeDelegatorSquashed.svg
sol2uml storage 0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4 -v -c  NodeDelegator -o NodeDelegatorStorage.svg --hideExpand  __gap
sol2uml storage 0x319Be66FfFb11b2058bb9D0Bb17665089e82dbf4 -v -d -s 0x8bBBCB5F4D31a6db3201D40F478f30Dc4F704aE2 -c NodeDelegator -o NodeDelegatorStorageData.svg --hideExpand  __gap

# Config
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -o LRTConfig.svg
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -hv -hf -he -hs -hl -hi -o  LRTConfigHierarchy.svg
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -s -hp -hm -ht -d 0 -o  LRTConfigPublicSquashed.svg
sol2uml 0xcdfD989e689872506E2897316b10e29c84AB087F -v -s -d 0 -o  LRTConfigSquashed.svg
sol2uml storage 0xcdfD989e689872506E2897316b10e29c84AB087F -v -c  LRTConfig -o LRTConfigStorage.svg --hideExpand  __gap
sol2uml storage 0xcdfD989e689872506E2897316b10e29c84AB087F -v -d -s 0xF879c7859b6DE6FAdaFB74224Ff05b16871646bF -c LRTConfig -o LRTConfigStorageData.svg --hideExpand  __gap

# Oracle
sol2uml 0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce -v -o LRTOracle.svg
sol2uml 0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce -v -hv -hf -he -hs -hl -hi -o  LRTOracleHierarchy.svg
sol2uml 0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce -v -s -hp -hm -ht -d 0 -o  LRTOraclePublicSquashed.svg
sol2uml 0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce -v -s -d 0 -o  LRTOracleSquashed.svg
sol2uml storage 0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce -v -c  LRTOracle -o LRTOracleStorage.svg --hideExpand  __gap
sol2uml storage 0xeF8c39489A83467B1c994B8E4c62cBE26DEB69ce -v -d -s 0xA755c18CD2376ee238daA5Ce88AcF17Ea74C1c32 -c LRTOracle -o LRTOracleStorageData.svg --hideExpand  __gap
