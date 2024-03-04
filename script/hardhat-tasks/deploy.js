const { defaultAbiCoder } = require("ethers/lib/utils");
const { logTxDetails } = require("../utils/txLogger");
const { parseAddress } = require("../utils/addressParser");

const log = require("../utils/logger")("task:deploy");

// Used to deploy a new NodeDelegator contract via the Defender Relayer
const deployNodeDelegator = async ({ index, signer, weth }) => {
  let nodeDelegatorFactory = await ethers.getContractFactory("NodeDelegator", signer);
  let implementation = await nodeDelegatorFactory.deploy(weth.address);
  await implementation.deployTransaction.wait();

  log(`NodeDelegator implementation deployed at: %s`, implementation.address);

  const proxyFactoryAddress = await parseAddress("PROXY_FACTORY");
  const proxyAdminAddress = await parseAddress("PROXY_ADMIN");
  const proxyFactory = await ethers.getContractAt("ProxyFactory", proxyFactoryAddress);

  const saltString = "Prime-Staked-nodeDelegator";
  const encodedSalt = defaultAbiCoder.encode(["string", "uint256"], [saltString, index]);
  const salt = ethers.utils.keccak256(encodedSalt);
  log(`Salt ${salt} created from "${saltString}" and index ${index}`);

  const newProxyAddress = await proxyFactory.callStatic.create(implementation.address, proxyAdminAddress, salt);
  log(`NodeDelegator proxy will be deployed at: %s`, newProxyAddress);
  const tx1 = await proxyFactory.create(implementation.address, proxyAdminAddress, salt);
  await logTxDetails(tx1, "ProxyFactory.create");

  const nodeDelegator = await nodeDelegatorFactory.attach(newProxyAddress);

  const lrtConfigAddress = await parseAddress("LRT_CONFIG");
  const tx2 = await nodeDelegator.initialize(lrtConfigAddress);
  await logTxDetails(tx2, "NodeDelegator.initialize");
};

module.exports = { deployNodeDelegator };
