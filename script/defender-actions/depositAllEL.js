const { DefenderRelaySigner, DefenderRelayProvider } = require("defender-relay-client/lib/ethers");
const { ethers } = require("ethers");

const { depositAllEL } = require("../hardhat-tasks/deposits.js");
const { abi: depositPoolAbi } = require("../../out/LRTDepositPool.sol/LRTDepositPool.json");
const { abi: nodeDelegatorAbi } = require("../../out/NodeDelegator.sol/NodeDelegator.json");

// Entrypoint for the Defender Action
const handler = async (event) => {
  // Initialize defender relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: "fastest" });

  console.log(`DEBUG env var in handler before being set: "${process.env.DEBUG}"`);

  const depositPoolAddress = await parseAddress("LRT_DEPOSIT_POOL");
  const depositPool = new ethers.Contract(depositPoolAddress, depositPoolAbi, signer);

  const nodeDelegatorAddress = await parseAddress("NODE_DELEGATOR");
  const nodeDelegator = new ethers.Contract(nodeDelegatorAddress, nodeDelegatorAbi, signer);

  await depositAllEL({
    signer,
    depositPool,
    nodeDelegator,
    index: 0,
    minDeposit: 0.001,
  });
};

module.exports = { handler };
