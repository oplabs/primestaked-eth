const { logTxDetails } = require("../utils/txLogger");
const { parseEther } = require("ethers/lib/utils");
const { ClusterScanner, NonceScanner } = require("ssv-scanner");
const { SSVKeys, KeyShares, KeySharesItem, SSVKeysException } = require("ssv-keys");
const path = require("path");
const fsp = require("fs").promises;

const log = require("../utils/logger")("task:ssv");

const approveSSV = async ({ signer, nodeDelegator }) => {
  log(`About to approve the SSV Network to transfer SSV tokens from NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).approveSSV();
  await logTxDetails(tx2, "approveSSV");
};

const depositSSV = async ({ signer, nodeDelegator, amount }) => {
  const amountBN = parseEther(amount.toString());

  // TODO get operatorIds and Cluster details
  log(`About to deposit more SSV tokens to the SSV Network from NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).depositSSV(amountBN);
  await logTxDetails(tx2, "depositSSV");
};

const pauseDelegator = async ({ signer, nodeDelegator }) => {
  log(`About to pause NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).pause();
  await logTxDetails(tx2, "pause");
};

const unpauseDelegator = async ({ signer, nodeDelegator }) => {
  log(`About to unpause NodeDelegator ${nodeDelegator.address}`);
  const tx2 = await nodeDelegator.connect(signer).unpause();
  await logTxDetails(tx2, "unpause");
};

const splitValidatorKey = async ({
  keystorelocation,
  keystorepass,
  operatorids,
  operatorkeys,
  ownerAddress,
  chainId,
  ssvNetwork,
}) => {
  const operatorIds = operatorids.split(".").map((id) => parseInt(id));
  const operatorKeys = operatorkeys.split(".");
  const keystoreLocation = path.join(__dirname, "..", "..", keystorelocation);
  const { nextNonce } = await getClusterInfo({ ownerAddress, operatorids, chainId, ssvNetwork });

  log(`Reading keystore location: ${keystoreLocation}`);
  log(`For operatorIds: ${operatorIds}`);
  log(`Next SSV register validator nonce for owner ${ownerAddress}: ${nextNonce}`);
  // TODO: 30+ start and end character of operators are the same. how to represent this?
  log(
    "Operator keys: ",
    operatorKeys.map((key) => `${key.slice(0, 10)}...${key.slice(-10)}`),
  );

  const keystoreJson = require(keystoreLocation);

  // 1. Initialize SSVKeys SDK and read the keystore file
  const ssvKeys = new SSVKeys();
  const { publicKey, privateKey } = await ssvKeys.extractKeys(keystoreJson, keystorepass);

  const operators = operatorKeys.map((operatorKey, index) => ({
    id: operatorIds[index],
    operatorKey,
  }));

  // 2. Build shares from operator IDs and public keys
  const encryptedShares = await ssvKeys.buildShares(privateKey, operators);
  const keySharesItem = new KeySharesItem();
  await keySharesItem.update({ operators });
  await keySharesItem.update({ ownerAddress: ownerAddress, ownerNonce: nextNonce, publicKey });

  // 3. Build final web3 transaction payload and update keyshares file with payload data
  await keySharesItem.buildPayload(
    {
      publicKey,
      operators,
      encryptedShares,
    },
    {
      ownerAddress: ownerAddress,
      ownerNonce: nextNonce,
      privateKey,
    },
  );

  const keyShares = new KeyShares();
  keyShares.add(keySharesItem);

  const keystoreFilePath = path.join(
    __dirname,
    "..",
    "..",
    "validator_key_data",
    "keyshares_data",
    `${publicKey.slice(0, 10)}_keyshares.json`,
  );
  log(`Saving distributed validator shares_data into: ${keystoreFilePath}`);
  await fsp.writeFile(keystoreFilePath, keyShares.toJson(), { encoding: "utf-8" });
};

const getClusterInfo = async ({ ownerAddress, operatorids, chainId, ssvNetwork }) => {
  const operatorIds = operatorids.split(".").map((id) => parseInt(id));

  const ssvNetworkName = chainId === 1 ? "MAINNET" : "PRATER";
  const providerUrl = chainId === 1 ? process.env.MAINNET_RPC_URL : process.env.GOERLI_RPC_URL;

  const params = {
    nodeUrl: providerUrl, // this can be an Infura, or Alchemy node, necessary to query the blockchain
    contractAddress: ssvNetwork, // this is the address of SSV smart contract
    ownerAddress, // this is the wallet address of the cluster owner
    /* Based on the network they fetch contract ABIs. See code: https://github.com/bloxapp/ssv-scanner/blob/v1.0.3/src/lib/contract.provider.ts#L16-L22
     * and the ABIs are fetched from here: https://github.com/bloxapp/ssv-scanner/tree/v1.0.3/src/shared/abi
     *
     * Prater seems to work for Goerli at the moment
     */
    network: ssvNetworkName,
    operatorIds: operatorIds, // this is a list of operator IDs chosen by the owner for their cluster
  };

  // ClusterScanner is initialized with the given parameters
  const clusterScanner = new ClusterScanner(params);
  // and when run, it returns the Cluster Snapshot
  const result = await clusterScanner.run(params.operatorIds);
  const cluster = {
    block: result.payload.Block,
    "cluster snapshot": result.cluster,
    cluster: Object.values(result.cluster),
  };
  const nonceScanner = new NonceScanner(params);
  const nextNonce = await nonceScanner.run();
  return { cluster, nextNonce };
};

const printClusterInfo = async (options) => {
  const { cluster, nextNonce } = await getClusterInfo(options);
  console.log(JSON.stringify(cluster, null, "  "));
  console.log("Next Nonce:", nextNonce);
};

module.exports = {
  approveSSV,
  depositSSV,
  pauseDelegator,
  unpauseDelegator,
  printClusterInfo,
  getClusterInfo,
  splitValidatorKey,
};
