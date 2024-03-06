require("dotenv").config();
const { ethers } = require("ethers");
const utils = ethers.utils

async function signAndBroadcast() {
  console.log("Started");

  // Enter the serialized transaction
  const rawTransaction = process.env.RAW_TRANSACTION;

  // Enter the private key of the address used to transfer the stake amount
  const privateKey = process.env.GOERLI_DEPLOYER_PRIVATE_KEY;

  // Enter the selected RPC URL
  const rpcURL = process.env.GOERLI_RPC_URL;

  // Initialize the provider using the RPC URL
  const provider = new ethers.providers.JsonRpcProvider(rpcURL);

  // Initialize a new Wallet instance
  const wallet = new ethers.Wallet(privateKey, provider);

  // Parse the raw transaction
  const tx = ethers.utils.parseTransaction(rawTransaction);

  const newTx = {
    to: tx.to,
    data: tx.data,
    chainId: tx.chainId,
    value: tx.value,
    gasLimit: tx.gasLimit,
    type: 2,

    nonce: await provider.getTransactionCount(wallet.address),
    // Enter the max fee per gas and prirorty fee
    maxFeePerGas: ethers.utils.parseUnits("5", "gwei"),
    maxPriorityFeePerGas: ethers.utils.parseUnits("1", "gwei"),
  };

  if (process.env.TX_TYPE="register_ssv_validator") {
    const registerTransactionParams = utils.defaultAbiCoder.decode(
      ["bytes", "uint64[]", "bytes", "uint256", '"tuple(uint32, uint64, uint64, bool, uint256)'],
      utils.hexDataSlice(tx.data, 4),
    );

    const [publicKey, operatorIds, sharesData, amount, cluster] = registerTransactionParams;
    console.log(`About to register validator with:`);
    console.log(`publicKey: ${publicKey}`);
    console.log(`operatorIds: ${operatorIds}`);
    console.log(`sharesData: ${sharesData}`);
    console.log(`amount: ${amount}`);
    console.log(`cluster: ${cluster}`);

    return 
  }

  if (process.env.TX_TYPE="remove_ssv_validator") {

    return
  }
}

