const { DefenderRelaySigner, DefenderRelayProvider } = require("defender-relay-client/lib/ethers");
const { ethers } = require("ethers");
const { KeyValueStoreClient } = require("defender-kvstore-client");

const { operateValidators } = require("../hardhat-tasks/p2p");
const addresses = require("../utils/addresses");
const { abi: nodeDelegatorAbi } = require("../../out/NodeDelegator.sol/NodeDelegator.json");
const { abi: erc20Abi } = require("../../out/ERC20.sol/ERC20.json");

const log = require("../utils/logger")("action:operateValidators");

// Entrypoint for the Defender Action
const handler = async (event) => {
  const store = new KeyValueStoreClient(event);

  // Initialize defender relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: "fastest" });

  console.log(`DEBUG env var in handler before being set: "${process.env.DEBUG}"`);

  const network = await provider.getNetwork();
  const networkName = network.chainId === 1 ? "mainnet" : "goerli";
  log(`Network: ${networkName} with chain id (${network.chainId})`);

  const eigenPodAddress = addresses[networkName].EIGEN_POD;
  log(`Resolved EIGEN_POD address to ${eigenPodAddress}`);

  const wethAddress = addresses[networkName].WETH_TOKEN;
  log(`Resolved WETH_TOKEN address to ${wethAddress}`);
  const WETH = new ethers.Contract(wethAddress, erc20Abi, signer);

  const nodeDelegatorAddress = addresses[networkName].NODE_DELEGATOR_NATIVE_STAKING;
  log(`Resolved NODE_DELEGATOR_NATIVE_STAKING address to ${nodeDelegatorAddress}`);
  const nodeDelegator = new ethers.Contract(nodeDelegatorAddress, nodeDelegatorAbi, signer);

  const contracts = {
    nodeDelegator,
    WETH,
  };

  const p2p_api_key = network.chainId === 1 ? event.secrets.P2P_MAINNET_API_KEY : event.secrets.P2P_GOERLI_API_KEY;
  if (!p2p_api_key) {
    throw new Error("Secret with P2P API key not set. Add the P2P_MAINNET_API_KEY or P2P_GOERLI_API_KEY secret");
  }
  const p2p_base_url = network.chainId === 1 ? "api.p2p.org" : "api-test.p2p.org";

  const config = {
    eigenPodAddress,
    p2p_api_key,
    p2p_base_url,
    // how much SSV (expressed in days of runway) gets deposited into SSV
    // network contract on validator registration.
    validatorSpawnOperationalPeriodInDays: 90,
    stake: true,
  };

  await operateValidators({
    signer,
    contracts,
    store,
    config,
  });
};

module.exports = { handler };
