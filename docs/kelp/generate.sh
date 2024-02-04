# contracts/buyback
# sol2uml .. -v -hv -hf -he -hs -hl -b LRTDepositPool -o LRTDepositPool.svg
# sol2uml .. -s -d 0 -b LRTDepositPool -o LRTDepositPoolSquashed.svg
# sol2uml storage .. -c LRTDepositPool -o LRTDepositPoolStorage.svg

# LRTDepositPool
sol2uml 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7 -v -o LRTDepositPool.svg
sol2uml 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7 -v -hv -hf -he -hs -hl -o LRTDepositPoolHierarchy.svg
sol2uml 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7 -s -hp -hm -ht -d 0 -b LRTDepositPool -o LRTDepositPoolPublicSquashed.svg
sol2uml 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7 -s -d 0 -b LRTDepositPool -o LRTDepositPoolSquashed.svg
sol2uml storage 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7 -c LRTDepositPool -o LRTDepositPoolStorage.svg --hideExpand  __gap
sol2uml storage 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7 -c LRTDepositPool -s 0x036676389e48133B63a802f8635AD39E752D375D -d -o LRTDepositPoolStorageData.svg -a 7 --hideExpand  __gap

## Deposit tx
### xETH
tx2uml value 0xaa22ff76569729693357b29ca92f24bb4abc0b9fad6f929dbc556101cf0d90d6 -v 
tx2uml 0xaa22ff76569729693357b29ca92f24bb4abc0b9fad6f929dbc556101cf0d90d6 -v 
tx2uml -x 0xaa22ff76569729693357b29ca92f24bb4abc0b9fad6f929dbc556101cf0d90d6 -v 
### stETH
tx2uml value 0xe55da86992e590385490bcf45e444d205d6b757036eac284759416f7c2e46c8b -v

## transferAssetToNodeDelegator
tx2uml value 0xfa778085646ab15552a91df4d22bd86a730e9f37dda5f1b5760e7ec28b305002 -v
tx2uml 0xfa778085646ab15552a91df4d22bd86a730e9f37dda5f1b5760e7ec28b305002 -v

# RSETH
sol2uml 0x8e2fe2f55f295f3f141213789796fa79e709ef23 -v -o RSETH.svg
sol2uml 0x8e2fe2f55f295f3f141213789796fa79e709ef23 -v -hv -hf -he -hs -hl -hi -o RSETHHierarchy.svg
sol2uml 0x8e2fe2f55f295f3f141213789796fa79e709ef23 -v -s -hp -hm -ht -d 0 -o RSETHPublicSquashed.svg
sol2uml 0x8e2fe2f55f295f3f141213789796fa79e709ef23 -v -s -d 0 -o RSETHSquashed.svg
sol2uml storage 0x8e2fe2f55f295f3f141213789796fa79e709ef23 -v -c RSETH -o RSETHStorage.svg --hideExpand  __gap
sol2uml storage 0x8e2fe2f55f295f3f141213789796fa79e709ef23 -v -s 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7 -d -c RSETH -o RSETHStorageData.svg --hideExpand  __gap

# NodeDelegator
sol2uml 0xed510dea149d14c1eb5f973004e0111afdb3b179 -v -o NodeDelegator.svg
sol2uml 0xed510dea149d14c1eb5f973004e0111afdb3b179 -v -hv -hf -he -hs -hl -hi -o  NodeDelegatorHierarchy.svg
sol2uml 0xed510dea149d14c1eb5f973004e0111afdb3b179 -v -s -hp -hm -ht -d 0 -o  NodeDelegatorPublicSquashed.svg
sol2uml 0xed510dea149d14c1eb5f973004e0111afdb3b179 -v -s -d 0 -o  NodeDelegatorSquashed.svg
sol2uml storage 0xed510dea149d14c1eb5f973004e0111afdb3b179 -v -c  NodeDelegator -o NodeDelegatorStorage.svg --hideExpand  __gap
sol2uml storage 0xed510dea149d14c1eb5f973004e0111afdb3b179 -v -d -s 0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473 -c NodeDelegator -o NodeDelegatorStorageData.svg --hideExpand  __gap

## depositAssetIntoStrategy
tx2uml value 0xaf14c06a2a453a65a27132e7788f8b3e6a997c6b5d9df012c88a53fabf6352d5 -v
tx2uml 0xaf14c06a2a453a65a27132e7788f8b3e6a997c6b5d9df012c88a53fabf6352d5 -v

# Config
sol2uml 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594 -v -o LRTConfig.svg
sol2uml 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594 -v -hv -hf -he -hs -hl -hi -o  LRTConfigHierarchy.svg
sol2uml 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594 -v -s -hp -hm -ht -d 0 -o  LRTConfigPublicSquashed.svg
sol2uml 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594 -v -s -d 0 -o  LRTConfigSquashed.svg
sol2uml storage 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594 -v -c  LRTConfig -o LRTConfigStorage.svg --hideExpand  __gap
sol2uml storage 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594 -v -d -s 0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7 -c LRTConfig -o LRTConfigStorageData.svg --hideExpand  __gap


# Oracle
sol2uml 0xf1bed40dbee8fc0f324fa06322f2bbd62d11c97d -v -o LRTOracle.svg
sol2uml 0xf1bed40dbee8fc0f324fa06322f2bbd62d11c97d -v -hv -hf -he -hs -hl -hi -o  LRTOracleHierarchy.svg
sol2uml 0xf1bed40dbee8fc0f324fa06322f2bbd62d11c97d -v -s -hp -hm -ht -d 0 -o  LRTOraclePublicSquashed.svg
sol2uml 0xf1bed40dbee8fc0f324fa06322f2bbd62d11c97d -v -s -d 0 -o  LRTOracleSquashed.svg
sol2uml storage 0xf1bed40dbee8fc0f324fa06322f2bbd62d11c97d -v -c  LRTOracle -o LRTOracleStorage.svg --hideExpand  __gap
sol2uml storage 0xf1bed40dbee8fc0f324fa06322f2bbd62d11c97d -v -d -s 0x349A73444b1a310BAe67ef67973022020d70020d -c LRTOracle -o LRTOracleStorageData.svg --hideExpand  __gap
