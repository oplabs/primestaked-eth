const { parseUnits, formatUnits } = require("ethers").utils;

const { resolveAsset } = require("../utils/assets");
const { getSigner } = require("../utils/signers");
const { logTxDetails } = require("../utils/txLogger");
const { ethereumAddress } = require("../utils/regex");
const { getBlockNumber } = require("./block");

const log = require("../utils/logger")("task:tokens");

async function balance({ account, block, symbol }) {
  const signer = await getSigner();

  const blockTag = await getBlockNumber(block);
  log(`block tag: ${blockTag}`);

  const accountAddr = account || (await signer.getAddress());

  // If ETH balance
  if (symbol === "ETH") {
    log(`About to get ETH balance of ${accountAddr}`);
    // send ETH in a transaction
    const balance = await signer.provider.getBalance(accountAddr, blockTag);
    console.log(`${accountAddr} has ${formatUnits(balance)} ETH`);
    return;
  }

  const asset = await resolveAsset(symbol, signer);

  const balance = await asset.connect(signer).balanceOf(accountAddr, { blockTag });

  const decimals = await asset.decimals();
  console.log(`${accountAddr} has ${formatUnits(balance, decimals)} ${symbol}`);
}

async function tokenAllowance({ block, owner, spender, symbol }) {
  const signer = await getSigner();

  const asset = await resolveAsset(symbol, signer);
  const ownerAddr = owner || (await signer.getAddress());

  const blockTag = await getBlockNumber(block);

  const balance = await asset.connect(signer).allowance(ownerAddr, spender, { blockTag });

  const decimals = await asset.decimals();
  console.log(`${ownerAddr} has allowed ${spender} to spend ${formatUnits(balance, decimals)} ${symbol}`);
}

async function tokenApprove({ amount, symbol, spender }) {
  const signer = await getSigner();

  if (!spender.match(ethereumAddress)) {
    throw new Error(`Invalid Ethereum address: ${spender}`);
  }

  const asset = await resolveAsset(symbol, signer);
  const assetUnits = parseUnits(amount.toString(), await asset.decimals());

  log(`About to approve ${spender} to spend ${amount} ${symbol}`);
  const tx = await asset.connect(signer).approve(spender, assetUnits);
  await logTxDetails(tx, "approve");
}

async function tokenTransfer({ amount, symbol, to }) {
  const signer = await getSigner();

  if (!to.match(ethereumAddress)) {
    throw new Error(`Invalid Ethereum address: ${to}`);
  }

  // If ETH transfer
  if (symbol === "ETH") {
    log(`About to send ${amount} ${symbol} to ${to}`);
    // send ETH in a transaction
    const tx = await signer.sendTransaction({
      to,
      value: parseUnits(amount.toString()),
    });
    await logTxDetails(tx, "send");
    return;
  }

  const asset = await resolveAsset(symbol, signer);
  const assetUnits = parseUnits(amount.toString(), await asset.decimals());

  log(`About to transfer ${amount} ${symbol} to ${to}`);
  const tx = await asset.connect(signer).transfer(to, assetUnits);
  await logTxDetails(tx, "transfer");
}

async function tokenTransferFrom({ amount, symbol, from, to }) {
  const signer = await getSigner();

  if (!from.match(ethereumAddress)) {
    throw new Error(`Invalid from Ethereum address: ${to}`);
  }
  if (to && !to.match(ethereumAddress)) {
    throw new Error(`Invalid to Ethereum address: ${to}`);
  }
  const toAddr = to || (await signer.getAddress());

  const asset = await resolveAsset(symbol, signer);
  const assetUnits = parseUnits(amount.toString(), await asset.decimals());

  log(`About to transfer ${amount} ${symbol} from ${from} to ${toAddr}`);
  const tx = await asset.connect(signer).transferFrom(from, toAddr, assetUnits);
  await logTxDetails(tx, "transferFrom");
}

module.exports = {
  tokenAllowance,
  balance,
  tokenApprove,
  tokenTransfer,
  tokenTransferFrom,
};
