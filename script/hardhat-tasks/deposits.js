const { formatUnits, parseEther } = require("ethers").utils;

const { logTxDetails } = require("../utils/txLogger");
const { resolveAddress } = require("../utils/assets");

const log = require("../utils/logger")("task:deposits");

// Calls to the LSTDepositPool contract

const depositPrime = async ({ signer, depositPool, amount, symbol }) => {
  const assetAddress = await resolveAddress(symbol);

  const assetUnits = parseEther(amount.toString());

  log(`About to deposit ${amount} ${symbol} to Prime Staked ETH`);
  const tx = await depositPool.connect(signer).depositAsset(assetAddress, assetUnits, 0, "");
  await logTxDetails(tx, "deposit");
};

const requestWithdrawal = async ({ signer, depositPool, amount, symbol }) => {
  const assetAddress = await resolveAddress(symbol);

  const assetUnits = parseEther(amount.toString());

  // TODO Get primeETH exchange rate to better calculate the max primeETH to withdraw
  const maxPrimeETH = assetUnits.mul(11).div(10);

  log(`About to request withdrawal of ${amount} ${symbol} from Deposit Pool`);
  const tx = await depositPool.connect(signer).requestWithdrawal(assetAddress, assetUnits, maxPrimeETH);
  await logTxDetails(tx, "requestWithdrawal");
};

const claimWithdrawal = async ({ signer, symbol, depositPool, requestTx, delegationManager }) => {
  const assetAddress = await resolveAddress(symbol);

  // Get the tx receipt of the requestWithdrawal tx so we can parse the logs for the Withdrawal struct
  const receipt = await signer.provider.getTransactionReceipt(requestTx);
  // find the WithdrawalQueued event from the tx receipt's logs
  const withdrawalQueuedEvent = receipt?.logs.find(
    (log) => log.topics[0] === "0x9009ab153e8014fbfb02f2217f5cde7aa7f9ad734ae85ca3ee3f4ca2fdd499f9",
  );

  if (!withdrawalQueuedEvent) {
    throw new Error(`Could not find a WithdrawalQueued event in tx ${requestTx}`);
  }

  // Parse the Withdrawal struct from the event
  const { withdrawal } = delegationManager.interface.parseLog(withdrawalQueuedEvent).args;
  log(`Parsed withdrawal: ${JSON.stringify(withdrawal)}`);

  log(`About to claim withdrawal from Prime Staked ETH`);
  const tx = await depositPool.connect(signer).claimWithdrawal(assetAddress, withdrawal);
  await logTxDetails(tx, "claimWithdrawal");
};

const depositAssetEL = async ({ signer, asset, depositPool, nodeDelegator, symbol, minDeposit, index }) => {
  const balance = await asset.balanceOf(depositPool.address);
  const minDepositBN = parseEther(minDeposit.toString());

  if (balance.gte(minDepositBN)) {
    log(`About to transfer ${formatUnits(balance)} ${symbol} to Node Delegator with index ${index}`);
    const tx1 = await depositPool.connect(signer).transferAssetToNodeDelegator(index, asset.address, balance);
    await logTxDetails(tx1, "transferAssetToNodeDelegator");

    if (symbol != "WETH") {
      log(`About to deposit ${symbol} to EigenLayer`);
      const tx2 = await nodeDelegator.connect(signer).depositAssetIntoStrategy(asset.address);
      await logTxDetails(tx2, "depositAssetIntoStrategy");
    }
  } else {
    log(`Skipping deposit of ${await asset.symbol()} as the balance is ${formatUnits(balance)}`);
  }
};

const depositAllEL = async ({ signer, depositPool, nodeDelegator, assets, minDeposit, index }) => {
  const minDepositBN = parseEther(minDeposit.toString());

  const depositAssets = [];
  const symbols = [];

  for (const asset of assets) {
    const symbol = await asset.symbol();

    const balance = await asset.balanceOf(depositPool.address);
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
    const tx1 = await depositPool.connect(signer).transferAssetsToNodeDelegator(index, depositAssets);
    await logTxDetails(tx1, "transferAssetToNodeDelegator");

    log(`About to deposit assets to EigenLayer`);
    const tx2 = await nodeDelegator.connect(signer).depositAssetsIntoStrategy(depositAssets);
    await logTxDetails(tx2, "depositAssetIntoStrategy");
  } else {
    console.log("No assets to deposit");
  }
};

module.exports = { depositPrime, depositAssetEL, depositAllEL, requestWithdrawal, claimWithdrawal };
