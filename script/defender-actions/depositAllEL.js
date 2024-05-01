const { DefenderRelaySigner, DefenderRelayProvider } = require("defender-relay-client/lib/ethers");
const { ethers } = require("ethers");

const { depositAllEL } = require("../hardhat-tasks/deposits.js");
const addresses = require("../utils/addresses");
const { abi: depositPoolAbi } = require("../../out/LRTDepositPool.sol/LRTDepositPool.json");
const { abi: nodeDelegatorAbi } = require("../../out/NodeDelegator.sol/NodeDelegator.json");
const { abi: erc20Abi } = require("../../out/IERC20Metadata.sol/IERC20Metadata.json");

const log = require("../utils/logger")("action:depositAllEL");

// Entrypoint for the Defender Action
const handler = async (event) => {
  // Initialize defender relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: "fastest" });

  console.log(`DEBUG env var in handler before being set: "${process.env.DEBUG}"`);

  const network = await provider.getNetwork();
  const networkName = network.chainId === 1 ? "mainnet" : "holesky";
  log(`Network: ${networkName} with chain id (${network.chainId})`);

  const depositPoolAddress = addresses[networkName].LRT_DEPOSIT_POOL;
  const depositPool = new ethers.Contract(depositPoolAddress, depositPoolAbi, signer);

  const nodeDelegatorAddress = addresses[networkName].NODE_DELEGATOR;
  const nodeDelegator = new ethers.Contract(nodeDelegatorAddress, nodeDelegatorAbi, signer);

  const assetAddresses = [
    addresses[networkName].OETH_TOKEN,
    addresses[networkName].SFRXETH_TOKEN,
    addresses[networkName].METH_TOKEN,
    addresses[networkName].STETH_TOKEN,
    addresses[networkName].RETH_TOKEN,
    addresses[networkName].SWETH_TOKEN,
    addresses[networkName].ETHX_TOKEN,
  ];
  const assets = assetAddresses.map((address) => new ethers.Contract(address, erc20Abi, signer));

  await depositAllEL({
    signer,
    depositPool,
    nodeDelegator,
    assets,
    index: 0,
    minDeposit: 0.1,
  });
};

module.exports = { handler };
