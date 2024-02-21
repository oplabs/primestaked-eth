const { DefenderRelaySigner, DefenderRelayProvider } = require("defender-relay-client/lib/ethers");
const { ethers } = require("ethers");
const { KeyValueStoreClient } = require('defender-kvstore-client');

const { operateValidators } = require("../hardhat-tasks/p2p.js");
const addresses = require("../utils/addresses.js");
const { abi: nodeDelegatorAbi } = require("../../out/NodeDelegator.sol/NodeDelegator.json");
const { abi: erc20Abi } = require("../../out/ERC20.sol/ERC20.json");

// Entrypoint for the Defender Action
const handler = async (event) => {
  const store = new KeyValueStoreClient(event);

  // Initialize defender relayer provider and signer
  const provider = new DefenderRelayProvider(event);
  const signer = new DefenderRelaySigner(event, provider, { speed: "fastest" });

  console.log(`DEBUG env var in handler before being set: "${process.env.DEBUG}"`);

  const WETH = new ethers.Contract(addresses.mainnet.WETH_TOKEN, erc20Abi, signer);
  // TODO: set the correct node delegator that will be
  const nodeDelegator = new ethers.Contract(addresses.mainnet.NODE_DELEGATOR_NATIVE_STAKING, nodeDelegatorAbi, signer);

  const contracts = {
    nodeDelegator,
    WETH,
  }

  const config = {
      p2p_api_key: process.env.P2P_MAINNET_API_KEY,
      p2p_base_url: 'api.p2p.org',
      // how much SSV (expressed in days of runway) gets deposited into SSV
      // network contract on validator registration.
      validatorSpawnOperationalPeriodInDays: 90
    };

  await operateValidators({
    signer,
    contracts,
    store,
    config
  });
};

module.exports = { handler };
