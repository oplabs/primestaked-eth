const addresses = require("../utils/addresses");

const log = require("../utils/logger")("utils:addressParser");

// Parse an address from the Solidity Addresses file
const parseAddress = async (name) => {
  log(`network: ${hre.network.name}`);

  const network = await hre.ethers.provider.getNetwork();
  const address = network.chainId === 1 ? addresses.mainnet[name] : addresses.goerli[name];

  if (!address) {
    throw Error(`Address not found for "${name}" with chain id ${network.chainId}.`);
  }

  log(`Using address ${address} from with chain id ${network.chainId}.`);

  return address;
};

module.exports = {
  parseAddress,
};
