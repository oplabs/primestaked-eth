const { subtask, task, types } = require("hardhat/config");

const { depositAssetEL, depositAllEL } = require("./deposits");
const { setAutotaskVars } = require("./autotask");
const { tokenAllowance, tokenBalance, tokenApprove, tokenTransfer, tokenTransferFrom } = require("./tokens");
const { getSigner } = require("../utils/signers");
const addresses = require("../utils/addresses");

// Prime Staked
subtask("depositEL", "Deposit an asset to EigenLayer")
  .addParam("symbol", "Symbol of the token. eg OETH, stETH, mETH or ETHx", "ALL", types.string)
  .addParam("index", "Index of Node Delegator", 0, types.int)
  .addOptionalParam("minDeposit", "Minimum ETH deposit amount", 1, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();
    const depositPool = await hre.ethers.getContractAt("LRTDepositPool", addresses.mainnet.LRT_DEPOSIT_POOL);
    const nodeDelegator = await hre.ethers.getContractAt("NodeDelegator", addresses.mainnet.NODE_DELEGATOR);
    if (taskArgs.symbol === "ALL") {
      await depositAllEL({ signer, depositPool, nodeDelegator, ...taskArgs });
    } else {
      await depositAssetEL({ signer, depositPool, nodeDelegator, ...taskArgs });
    }
  });
task("depositEL").setAction(async (_, __, runSuper) => {
  return runSuper();
});

// Defender
subtask("setAutotaskVars", "Set environment variables on Defender Autotasks. eg DEBUG=prime*")
  .addOptionalParam("id", "Identifier of the Defender Autotask", "ffcfc580-7b0a-42ed-a4f2-3f0a3add9779", types.string)
  .setAction(setAutotaskVars);
task("setAutotaskVars").setAction(async (_, __, runSuper) => {
  return runSuper();
});

// Token tasks.
subtask("allowance", "Get the token allowance an owner has given to a spender")
  .addParam("symbol", "Symbol of the token. eg OETH, WETH, USDT or OGV", undefined, types.string)
  .addParam("spender", "The address of the account or contract that can spend the tokens")
  .addOptionalParam("owner", "The address of the account or contract allowing the spending. Default to the signer")
  .addOptionalParam("block", "Block number. (default: latest)", undefined, types.int)
  .setAction(tokenAllowance);
task("allowance").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("balance", "Get the token balance of an account or contract")
  .addParam("symbol", "Symbol of the token. eg OETH, WETH, USDT or OGV", undefined, types.string)
  .addOptionalParam("account", "The address of the account or contract. Default to the signer")
  .addOptionalParam("block", "Block number. (default: latest)", undefined, types.int)
  .setAction(tokenBalance);
task("balance").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("approve", "Approve an account or contract to spend tokens")
  .addParam("symbol", "Symbol of the token. eg OETH, WETH, USDT or OGV", undefined, types.string)
  .addParam("amount", "Amount of tokens that can be spent", undefined, types.float)
  .addParam("spender", "Address of the account or contract that can spend the tokens", undefined, types.string)
  .setAction(tokenApprove);
task("approve").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("transfer", "Transfer tokens to an account or contract")
  .addParam("symbol", "Symbol of the token. eg OETH, WETH, USDT or OGV", undefined, types.string)
  .addParam("amount", "Amount of tokens to transfer", undefined, types.float)
  .addParam("to", "Destination address", undefined, types.string)
  .setAction(tokenTransfer);
task("transfer").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("transferFrom", "Transfer tokens from an account or contract")
  .addParam("symbol", "Symbol of the token. eg OETH, WETH, USDT or OGV", undefined, types.string)
  .addParam("amount", "Amount of tokens to transfer", undefined, types.float)
  .addParam("from", "Source address", undefined, types.string)
  .addOptionalParam("to", "Destination address. Default to signer", undefined, types.string)
  .setAction(tokenTransferFrom);
task("transferFrom").setAction(async (_, __, runSuper) => {
  return runSuper();
});
