const { parseEther, formatUnits } = require("ethers").utils;

const { parseAddress } = require("../utils/addressParser");
const { resolveAddress } = require("../utils/assets");
const { logTxDetails } = require("../utils/txLogger");
const { getWithdrawal, getWithdrawals } = require("../utils/withdrawalParser");

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

const claimWithdrawal = async ({ signer, depositPool, requestTx, delegationManager, symbol }) => {
  const withdrawal = await getWithdrawal(signer, requestTx, delegationManager);

  if (symbol == "OETH") {
    log(`About to claim OETH withdrawal from Prime Staked ETH`);
    const tx = await depositPool.connect(signer).claimWithdrawal(withdrawal);
    await logTxDetails(tx, "claimWithdrawal");
  } else if (symbol === "ynLSDe") {
    log(`About to claim ynLSDe withdrawal from Prime Staked ETH`);
    const tx = await depositPool.connect(signer).claimWithdrawalYn(withdrawal);
    await logTxDetails(tx, "claimWithdrawalYn");
  } else {
    throw new Error(`Can only claim withdrawals to OETH or ynLSDe, not "${symbol}"`);
  }
};

const requestInternalWithdrawal = async ({ signer, nodeDelegator, shares, symbol }) => {
  const strategyAddress = await parseAddress(`${symbol.toUpperCase()}_EIGEN_STRATEGY`);

  let shareUnits;
  if (!shares) {
    const strategy = await ethers.getContractAt("IStrategy", strategyAddress);
    shareUnits = await strategy.shares(nodeDelegator.address);
    log(`The NodeDelegator has ${formatUnits(shareUnits, 18)} ${symbol} shares in the EigenLayer strategy`);
  } else {
    shareUnits = parseEther(shares.toString());
  }

  log(
    `About to request internal withdrawal of ${formatUnits(shareUnits, 18)} ${symbol} shares from EigenLayer strategy`,
  );
  const tx = await nodeDelegator.connect(signer).requestInternalWithdrawal(strategyAddress, shareUnits);
  await logTxDetails(tx, "requestInternalWithdrawal");
};

const claimInternalWithdrawal = async ({ signer, nodeDelegator, requestTx, delegationManager }) => {
  const withdrawal = await getWithdrawal(signer, requestTx, delegationManager);

  log(`About to claim internal withdrawal from EigenLayer strategy`);
  const tx = await nodeDelegator.connect(signer).claimInternalWithdrawal(withdrawal);
  await logTxDetails(tx, "claimInternalWithdrawal");
};

const claimInternalWithdrawals = async ({ signer, nodeDelegator, requestTx, delegationManager }) => {
  const withdrawals = await getWithdrawals(signer, requestTx, delegationManager);

  for (const withdrawal of withdrawals) {
    log(`About to claim internal withdrawal from EigenLayer strategy ${withdrawal.strategies[0]}`);
    const tx = await nodeDelegator.connect(signer).claimInternalWithdrawal(withdrawal);
    await logTxDetails(tx, "claimInternalWithdrawal");
  }
};

const requestEthWithdrawal = async ({ signer, nodeDelegator }) => {
  log(`About to request Ether withdrawal from EigenLayer's EigenPod contract`);
  const tx = await nodeDelegator.connect(signer).requestEthWithdrawal();
  await logTxDetails(tx, "requestEthWithdrawal");
};

const claimEthWithdrawal = async ({ signer, nodeDelegator }) => {
  log(`About to claim Ether withdrawal from EigenLayer's DelayedWithdrawalRouter contract`);
  const tx = await nodeDelegator.connect(signer).claimEthWithdrawal();
  await logTxDetails(tx, "claimEthWithdrawal");
};

module.exports = {
  requestWithdrawal,
  claimWithdrawal,
  requestInternalWithdrawal,
  claimInternalWithdrawal,
  claimInternalWithdrawals,
  requestEthWithdrawal,
  claimEthWithdrawal,
};
