const { logTxDetails } = require("../utils/txLogger");
const { ethereumAddress } = require("../utils/regex");

const log = require("../utils/logger")("task:proxy");

async function upgradeProxy({ proxy, impl, signer, proxyAdmin }) {
  if (!proxy.match(ethereumAddress)) {
    throw new Error(`Invalid proxy address: ${proxy}`);
  }
  if (!impl.match(ethereumAddress)) {
    throw new Error(`Invalid implementation contract address: ${impl}`);
  }

  log(`About to upgrade proxy ${proxy} to implementation ${impl}`);
  const tx = await proxyAdmin.connect(signer).upgrade(proxy, impl);
  await logTxDetails(tx, "proxy upgrade");
}

module.exports = {
  upgradeProxy,
};
