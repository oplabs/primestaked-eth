const { logTxDetails } = require("../utils/txLogger");
const { resolveAsset } = require("../utils/assets");
const addresses = require("../utils/addresses");
const { formatUnits, parseEther } = require("ethers").utils;

const log = require("../utils/logger")("task:deposits");

const depositAssetEL = async ({ signer, depositPool, nodeDelegator, symbol, minDeposit, index }) => {
  const asset = await resolveAsset(symbol, signer);

  const balance = await asset.balanceOf(addresses.mainnet.LRT_DEPOSIT_POOL);
  const minDepositBN = parseEther(minDeposit.toString());

  if (balance.gte(minDepositBN)) {
    const assetAddress = await asset.address;

    log(`About to transfer ${formatUnits(balance)} ${symbol} to Node Delegator with index ${index}`);
    const tx1 = await depositPool.connect(signer).transferAssetToNodeDelegator(0, assetAddress, balance);
    await logTxDetails(tx1, "transferAssetToNodeDelegator");

    log(`About to deposit ${symbol} to EigenLayer`);
    const tx2 = await nodeDelegator.connect(signer).depositAssetIntoStrategy(assetAddress);
    await logTxDetails(tx2, "depositAssetIntoStrategy");
  } else {
    log(`Skipping deposit of ${await asset.symbol()} as the balance is ${formatUnits(balance)}`);
  }
};

const depositAllEL = async ({ signer, depositPool, nodeDelegator, minDeposit, index }) => {
  const assetAddresses = [
    addresses.mainnet.OETH,
    addresses.mainnet.sfrxETH,
    addresses.mainnet.mETH,
    addresses.mainnet.stETH,
    addresses.mainnet.rETH,
    addresses.mainnet.swETH,
    addresses.mainnet.ETHx,
  ];

  const minDepositBN = parseEther(minDeposit.toString());

  const depositAssets = [];
  const symbols = [];

  for (const assetAddress of assetAddresses) {
    const asset = await resolveAsset(assetAddress, signer);
    const symbol = await asset.symbol();

    const balance = await asset.balanceOf(addresses.mainnet.LRT_DEPOSIT_POOL);
    if (balance.gte(minDepositBN)) {
      log(`Will deposit ${formatUnits(balance)} ${symbol}`);
      depositAssets.push(assetAddress);
      symbols.push(symbol);
    } else {
      log(`Skipping deposit of ${formatUnits(balance)} ${symbol}`);
    }
  }

  if (depositAssets.length > 0) {
    console.log(`About to transfer assets ${symbols} to Node Delegator with index ${index}`);
    const tx1 = await depositPool.connect(signer).transferAssetsToNodeDelegator(0, depositAssets);
    await logTxDetails(tx1, "transferAssetToNodeDelegator");

    log(`About to deposit assets to EigenLayer`);
    const tx2 = await nodeDelegator.connect(signer).depositAssetsIntoStrategy(depositAssets);
    await logTxDetails(tx2, "depositAssetIntoStrategy");
  } else {
    console.log("No assets to deposit");
  }
};

module.exports = { depositAssetEL, depositAllEL };
