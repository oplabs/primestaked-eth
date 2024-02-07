const { logTxDetails } = require("../utils/txLogger");
const { resolveAddress } = require("../utils/assets");

const log = require("../utils/logger")("task:prime");

async function depositEL({ signer, depositPool, nodeDelegator, symbol, index }) {
  const assetAddress = resolveAddress(symbol);

  log(`About to transfer ${symbol} to Node Delegator with index ${index}`);
  const tx1 = await depositPool.connect(signer).transferAssetsToNodeDelegator(0, [assetAddress]);
  await logTxDetails(tx1, "transferAssetsToNodeDelegator", false);

  log(`About to deposit ${symbol} to EigenLayer`);
  const tx2 = await nodeDelegator.connect(signer).depositAssetIntoStrategy(assetAddress);
  await logTxDetails(tx2, "depositAssetIntoStrategy", false);
}

module.exports = { depositEL };
