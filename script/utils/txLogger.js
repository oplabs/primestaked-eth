const { formatUnits } = require("ethers").utils;

const log = require("./logger")("utils:txLogger");

/**
 * Log transaction details after the tx has been sent and mined.
 * @param {ContractTransaction} tx transaction sent to the network
 * @param {string} method description of the tx. eg method name
 * @returns {ContractReceipt} transaction receipt
 */
async function logTxDetails(tx, method, confirm = true) {
  log(`Sent ${method} transaction with hash ${tx.hash} from ${tx.from} with nonce ${tx.nonce}`);

  if (!confirm) return;
  const receipt = await tx.wait();

  // Calculate tx cost in Wei
  const txCost = receipt.gasUsed.mul(tx.gasPrice ?? 0);
  log(
    `Processed ${method} tx in block ${receipt.blockNumber}, using ${receipt.gasUsed} gas costing ${formatUnits(
      txCost,
    )} ETH`,
  );

  return receipt;
}

module.exports = {
  logTxDetails,
};
