const { logTxDetails } = require("../utils/txLogger");
const { parseEther } = require("ethers/lib/utils");

const log = require("../utils/logger")("task:ssv");

const approveSSV = async ({ signer, nodeDelegator }) => {
  log(`About to approve the SSV Network to transfer SSV tokens from NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).approveSSV();
  await logTxDetails(tx2, "approveSSV");
};

const depositSSV = async ({ signer, nodeDelegator, amount }) => {
  const amountBN = parseEther(amount.toString());

  // TODO get operatorIds and Cluster details
  log(`About to deposit more SSV tokens to the SSV Network from NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).depositSSV(amountBN);
  await logTxDetails(tx2, "depositSSV");
};

const pauseDelegator = async ({ signer, nodeDelegator }) => {
  log(`About to pause NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).pause();
  await logTxDetails(tx2, "pause");
};

const unpauseDelegator = async ({ signer, nodeDelegator }) => {
  log(`About to unpause NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).unpause();
  await logTxDetails(tx2, "unpause");
};

module.exports = { approveSSV, depositSSV, pauseDelegator, unpauseDelegator };
