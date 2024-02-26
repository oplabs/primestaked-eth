const { logTxDetails } = require("../utils/txLogger");
const { parseEther } = require("ethers/lib/utils");
const { ClusterScanner, NonceScanner } = require("ssv-scanner");

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

module.exports = { approveSSV, depositSSV, pauseDelegator, unpauseDelegator, printClusterInfo, getClusterInfo };
