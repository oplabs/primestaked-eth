const { ethereumAddress } = require("../utils/regex");
const { logTxDetails } = require("../utils/txLogger");

const log = require("../utils/logger")("task:withdrawals");

const delegate = async ({ signer, nodeDelegator, operator }) => {
  if (!operator.match(ethereumAddress)) {
    throw new Error(`EigenLayer Operator address "${operator}" is not valid`);
  }

  log(`About to delegate to EigenLayer Operator ${operator}`);
  const tx = await nodeDelegator.connect(signer).delegateTo(operator);
  await logTxDetails(tx, "delegateTo");
};

module.exports = { delegate, undelegate };
