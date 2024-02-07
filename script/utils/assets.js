const addresses = require("./addresses");
const { ethereumAddress } = require("./regex");
// Commented out as Hardhat will load a version of ethers with helper function getContractAt
// which comes from the @nomicfoundation/hardhat-ethers package.
// The following needs to be uncommented if building for an Autotask
// const { ethers } = require("ethers");

const log = require("../utils/logger")("utils:assets");

/**
 * Resolves a token symbol to a ERC20 token contract.
 * @param {string} symbol token symbol of the asset. eg OUSD, USDT, stETH, CRV...
 */
const resolveAddress = (symbol) => {
  const assetAddr = addresses.mainnet[symbol] || addresses.mainnet[symbol + "Proxy"] || symbol;
  if (!assetAddr) {
    throw Error(`Failed to resolve symbol "${symbol}" to an address`);
  }
  log(`Resolved ${symbol} to ${assetAddr}`);
  return assetAddr;
};

/**
 * Resolves a token symbol to a ERC20 token contract.
 * @param {string} symbol token symbol of the asset. eg OUSD, USDT, stETH, CRV...
 */
const resolveAsset = async (symbol) => {
  const assetAddr = addresses.mainnet[symbol] || addresses.mainnet[symbol + "Proxy"] || symbol;
  if (!assetAddr) {
    throw Error(`Failed to resolve symbol "${symbol}" to an address`);
  }
  if (!symbol.match(ethereumAddress)) {
    log(`Resolved ${symbol} to ${assetAddr}`);
  }
  const asset = await ethers.getContractAt("IERC20Metadata", assetAddr);

  if (symbol.match(ethereumAddress)) {
    log(`Resolved ${symbol} to ${await asset.symbol()} asset`);
  }
  return asset;
};

module.exports = {
  resolveAddress,
  resolveAsset,
};
