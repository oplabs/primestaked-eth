const { subtask, task, types } = require("hardhat/config");

const { depositAssetEL, depositAllEL } = require("./deposits");
const { operateValidators } = require("./p2p");
const { setActionVars } = require("./defender");
const { tokenAllowance, tokenBalance, tokenApprove, tokenTransfer, tokenTransferFrom } = require("./tokens");
const { getSigner } = require("../utils/signers");
const addresses = require("../utils/addresses");
const localStore = require("../utils/localStore");
const { abi: erc20Abi } = require("../../out/ERC20.sol/ERC20.json");

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
subtask("setActionVars", "Set environment variables on a Defender Actions. eg DEBUG=prime*")
  .addParam("id", "Identifier of the Defender Actions", undefined, types.string)
  .setAction(setActionVars);
task("setActionVars").setAction(async (_, __, runSuper) => {
  return runSuper();
});

// Defender
subtask("operateValidators", "Spawns up the required amount of validators and sets them up")
  //.addParam("id", "Identifier of the Defender Actions", undefined, types.string)
  .setAction(async (taskArgs) => {
    const store = localStore();
    const signer = await getSigner();

    const WETH = await hre.ethers.getContractAt(
      erc20Abi, addresses.goerli.WETH
    );
    const nodeDelegator = await hre.ethers.getContractAt(
      "NodeDelegator", addresses.goerli.NODE_DELEGATOR_NATIVE_STAKING
    );

    const contracts = {
      nodeDelegator,
      WETH,
    };
    await operateValidators({
      signer,
      contracts,
      store,
    });
  });

task("operateValidators").setAction(async (_, __, runSuper) => {
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
