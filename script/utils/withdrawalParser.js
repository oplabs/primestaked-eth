const log = require("./logger")("utils:withdrawalParser");

const WithdrawalQueuedTopic = "0x9009ab153e8014fbfb02f2217f5cde7aa7f9ad734ae85ca3ee3f4ca2fdd499f9";

const getWithdrawal = async (signer, requestTx, delegationManager) => {
  // Get the tx receipt of the requestWithdrawal tx so we can parse the logs for the Withdrawal struct
  const receipt = await signer.provider.getTransactionReceipt(requestTx);
  // find the WithdrawalQueued event from the tx receipt's logs
  const withdrawalQueuedEvent = receipt?.logs.find((log) => log.topics[0] === WithdrawalQueuedTopic);

  if (!withdrawalQueuedEvent) {
    throw new Error(`Could not find a WithdrawalQueued event in tx ${requestTx}`);
  }

  // Parse the Withdrawal struct from the event
  const { withdrawal } = delegationManager.interface.parseLog(withdrawalQueuedEvent).args;
  log(`Parsed withdrawal: ${JSON.stringify(withdrawal)}`);

  return withdrawal;
};

const getWithdrawals = async (signer, requestTx, delegationManager) => {
  // Get the tx receipt of the requestWithdrawal tx so we can parse the logs for the Withdrawal struct
  const receipt = await signer.provider.getTransactionReceipt(requestTx);
  // find the WithdrawalQueued event from the tx receipt's logs
  const withdrawalQueuedEvents = receipt?.logs.filter((log) => log.topics[0] === WithdrawalQueuedTopic);

  // Parse the Withdrawal struct from the events
  const withdrawals = withdrawalQueuedEvents.map((event) => {
    const { withdrawal } = delegationManager.interface.parseLog(event).args;
    return withdrawal;
  });

  return withdrawals;
};

module.exports = { getWithdrawal, getWithdrawals };
