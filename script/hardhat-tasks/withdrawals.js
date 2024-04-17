const { formatUnits, parseEther } = require("ethers").utils;

const { parseAddress } = require("../utils/addressParser");
const { resolveAddress } = require("../utils/assets");
const { logTxDetails } = require("../utils/txLogger");

const log = require("../utils/logger")("task:withdrawals");

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
  const withdrawal = await getWithdrawalData(signer, requestTx, delegationManager);

  log(`About to claim withdrawal from Prime Staked ETH`);
  const tx = await depositPool.connect(signer).claimWithdrawal(assetAddress, withdrawal);
  await logTxDetails(tx, "claimWithdrawal");
};

const requestInternalWithdrawal = async ({ signer, nodeDelegator, shares, symbol }) => {
  const strategyAddress = await parseAddress(`${symbol.toUpperCase()}_EIGEN_STRATEGY`);
  const shareUnits = parseEther(shares.toString());

  log(`About to request internal withdrawal of ${shares} ${symbol} shares from EigenLayer strategy`);
  const tx = await nodeDelegator.connect(signer).requestInternalWithdrawal(strategyAddress, shareUnits);
  await logTxDetails(tx, "requestInternalWithdrawal");
};

const claimInternalWithdrawal = async ({ signer, symbol, nodeDelegator, requestTx, delegationManager }) => {
  const assetAddress = await resolveAddress(symbol);
  const withdrawal = await getWithdrawalData(signer, requestTx, delegationManager);

  log(`About to claim internal withdrawal from EigenLayer strategy`);
  const tx = await nodeDelegator.connect(signer).claimInternalWithdrawal(assetAddress, withdrawal);
  await logTxDetails(tx, "claimInternalWithdrawal");
};

const getWithdrawalData = async (signer, requestTx, delegationManager) => {
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

  return withdrawal;
};

module.exports = { requestWithdrawal, claimWithdrawal, requestInternalWithdrawal, claimInternalWithdrawal };
