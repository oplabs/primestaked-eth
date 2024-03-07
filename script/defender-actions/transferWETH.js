const { DefenderRelaySigner, DefenderRelayProvider } = require("defender-relay-client/lib/ethers");
const { ethers } = require("ethers");

const { depositAssetEL } = require("../hardhat-tasks/deposits.js");
const addresses = require("../utils/addresses");
const { abi: depositPoolAbi } = require("../../out/LRTDepositPool.sol/LRTDepositPool.json");
const { abi: nodeDelegatorAbi } = require("../../out/NodeDelegator.sol/NodeDelegator.json");
const { abi: erc20Abi } = require("../../out/IERC20Metadata.sol/IERC20Metadata.json");

const log = require("../utils/logger")("action:transferWETH");

// Entrypoint for the Defender Action
const handler = async (event) => {
  // Initialize defender relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: "fastest" });

  console.log(`DEBUG env var in handler before being set: "${process.env.DEBUG}"`);

  const network = await provider.getNetwork();
  const networkName = network.chainId === 1 ? "mainnet" : "goerli";
  log(`Network: ${networkName} with chain id (${network.chainId})`);

  const depositPoolAddress = addresses[networkName].LRT_DEPOSIT_POOL;
  log(`Resolved LRT_DEPOSIT_POOL address to ${depositPoolAddress}`);
  const depositPool = new ethers.Contract(depositPoolAddress, depositPoolAbi, signer);

  const nodeDelegatorAddress = addresses[networkName].NODE_DELEGATOR_NATIVE_STAKING;
  log(`Resolved NODE_DELEGATOR_NATIVE_STAKING address to ${nodeDelegatorAddress}`);
  const nodeDelegator = new ethers.Contract(nodeDelegatorAddress, nodeDelegatorAbi, signer);

  const assetAddress = addresses[networkName].WETH_TOKEN;
  log(`Resolved WETH_TOKEN address to ${assetAddress}`);
  const asset = new ethers.Contract(assetAddress, erc20Abi, signer);

  await depositAssetEL({
    signer,
    depositPool,
    nodeDelegator,
    symbol: "WETH",
    asset,
    index: 1,
    minDeposit: 32,
  });
};

module.exports = { handler };
