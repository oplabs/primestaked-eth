const { logTxDetails } = require("../utils/txLogger");
const { ethereumAddress } = require("../utils/regex");
const { constants, utils } = require("ethers");

const log = require("../utils/logger")("task:proxy");

async function grantRole({ config, signer, role, account }) {
  if (!account.match(ethereumAddress)) {
    throw new Error(`Invalid account address: ${account}`);
  }

  const roleHash = role === "default" ? constants.HashZero : utils.keccak256(utils.toUtf8Bytes(role));

  log(`About to grant role ${role} to ${account}`);
  const tx = await config.connect(signer).grantRole(roleHash, account);
  await logTxDetails(tx, "grantRole");
}

async function revokeRole({ config, signer, role, account }) {
  if (!account.match(ethereumAddress)) {
    throw new Error(`Invalid account address: ${account}`);
  }

  const roleHash = role === "default" ? constants.HashZero : utils.keccak256(utils.toUtf8Bytes(role));

  log(`About to revoke role ${role} to ${account}`);
  const tx = await config.connect(signer).revokeRole(roleHash, account);
  await logTxDetails(tx, "revokeRole");
}

module.exports = {
  grantRole,
  revokeRole,
};
