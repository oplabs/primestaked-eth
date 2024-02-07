const { logTxDetails } = require("../utils/txLogger");
const { resolveAddress, resolveAsset } = require("../utils/assets");
const addresses = require("../utils/addresses");
const { formatUnits, parseEther } = require("ethers");

const log = require("../utils/logger")("task:prime");

const depositAssetEL = async ({ signer, depositPool, nodeDelegator, symbol, index, confirm }) => {
  const assetAddress = resolveAddress(symbol);

  log(`About to transfer ${symbol} to Node Delegator with index ${index}`);
  const tx1 = await depositPool.connect(signer).transferAssetsToNodeDelegator(0, [assetAddress]);
  await logTxDetails(tx1, "transferAssetsToNodeDelegator", confirm);

  log(`About to deposit ${symbol} to EigenLayer`);
  const tx2 = await nodeDelegator.connect(signer).depositAssetIntoStrategy(assetAddress);
  await logTxDetails(tx2, "depositAssetIntoStrategy", confirm);
};

const depositAllEL = async (options) => {
  const { minDeposit } = options;

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

  for (const assetAddress of assetAddresses) {
    const asset = await resolveAsset(assetAddress);
    const balance = await asset.balanceOf(addresses.mainnet.LRT_DEPOSIT_POOL);
    const resolvedSymbol = await asset.symbol();
    if (balance > minDepositBN) {
      log(`About to deposit ${formatUnits(balance)} ${resolvedSymbol} to EigenLayer`);
      depositAssetEL({ ...options, symbol: resolvedSymbol });
    } else {
      log(`Skipping deposit of ${resolvedSymbol} as the balance is ${formatUnits(balance)}`);
    }
  }
};

module.exports = { depositAssetEL, depositAllEL };
