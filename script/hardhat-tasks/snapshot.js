const { formatUnits, parseEther } = require("ethers").utils;
const { BigNumber } = require("ethers");
const { parseAddress } = require("../utils/addressParser");
const { resolveAsset } = require("../utils/assets");

const log = require("../utils/logger")("task:snap");

const symbolPad = 8;

const snapshot = async () => {
  const assetSymbols = ["OETH", "sfrxETH", "mETH", "stETH", "rETH", "swETH", "ETHx", "WETH"];
  const assets = [];
  for (symbol of assetSymbols) {
    assets.push(await resolveAsset(symbol));
  }

  const depositPool = await ethers.getContractAt("LRTDepositPool", await parseAddress("LRT_DEPOSIT_POOL"));

  const assetBalances = [];
  const assetTotals = [];

  let totalDepositPool = BigNumber.from(0);
  let totalNDC = BigNumber.from(0);
  let totalEL = BigNumber.from(0);
  for (const asset of assets) {
    const balances = await depositPool.getAssetDistributionData(asset.address);
    totalDepositPool = totalDepositPool.add(balances.depositPoolAssets);
    totalNDC = totalNDC.add(balances.ndcAssets);
    totalEL = totalEL.add(balances.eigenAssets);
    assetTotals.push(balances.depositPoolAssets.add(balances.ndcAssets).add(balances.eigenAssets));
    assetBalances.push(balances);
  }
  let totalAll = totalDepositPool.add(totalNDC).add(totalEL);

  // Assets in the DepositPool
  console.log("Assets in the DepositPool:");
  assetBalances.forEach((balance, index) => {
    console.log(`  ${assetSymbols[index].padEnd(symbolPad)}${formatUnits(balance.depositPoolAssets, 18)}`);
  });
  console.log(`Total     ${formatUnits(totalDepositPool, 18)}`);

  // Assets in the LST NodeDelegator
  console.log("\nAssets in NodeDelegators:");
  assetBalances.forEach((balance, index) => {
    console.log(`  ${assetSymbols[index].padEnd(symbolPad)} ${formatUnits(balance.ndcAssets, 18)}`);
  });
  console.log(`Total      ${formatUnits(totalNDC, 18)}`);

  // ETH in in EigenLayer
  console.log("\nAssets in EigenLayer:");
  assetBalances.forEach((balance, index) => {
    console.log(`  ${assetSymbols[index].padEnd(symbolPad)} ${formatUnits(balance.eigenAssets, 18)}`);
  });
  console.log(`Total      ${formatUnits(totalEL, 18)}`);

  // All layers
  console.log("\nAssets in all layers:");
  assetTotals.forEach((assetTotal, index) => {
    const percentage = assetTotal.mul(10000).div(totalAll);
    console.log(
      `  ${assetSymbols[index].padEnd(symbolPad)} ${formatUnits(assetTotal, 18).padEnd(24)} ${formatUnits(percentage, 2).padStart(5)}%`,
    );
  });
  console.log(`Total      ${formatUnits(totalAll, 18)}`);

  // SSV Cluster data
};

module.exports = { snapshot };
