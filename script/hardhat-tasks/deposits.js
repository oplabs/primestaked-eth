const { formatUnits, parseEther } = require("ethers").utils;

const { logTxDetails } = require("../utils/txLogger");
const { resolveAsset, resolveAddress } = require("../utils/assets");
const { parseAddress } = require("../utils/addressParser");

const log = require("../utils/logger")("task:deposits");

const depositPrime = async ({ signer, depositPool, amount, symbol }) => {
  const assetAddress = await resolveAddress(symbol);

  const assetUnits = parseEther(amount.toString());

  log(`About to deposit ${symbol} to Prime Staked ETH`);
  const tx = await depositPool.connect(signer).depositAsset(assetAddress, assetUnits, 0, "");
  await logTxDetails(tx, "deposit");
};

const depositAssetEL = async ({ signer, depositPool, nodeDelegator, symbol, minDeposit, index }) => {
  const asset = await resolveAsset(symbol, signer);

  const balance = await asset.balanceOf(depositPool.address);
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
    await parseAddress("OETH_TOKEN"),
    await parseAddress("SFRXETH_TOKEN"),
    await parseAddress("METH_TOKEN"),
    await parseAddress("STETH_TOKEN"),
    await parseAddress("RETH_TOKEN"),
    await parseAddress("SWETH_TOKEN"),
    await parseAddress("ETHX_TOKEN"),
  ];

  const minDepositBN = parseEther(minDeposit.toString());

  const depositAssets = [];
  const symbols = [];

  for (const assetAddress of assetAddresses) {
    const asset = await resolveAsset(assetAddress, signer);
    const symbol = await asset.symbol();

    const balance = await asset.balanceOf(await parseAddress("LRT_DEPOSIT_POOL"));
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

module.exports = { depositPrime, depositAssetEL, depositAllEL };
