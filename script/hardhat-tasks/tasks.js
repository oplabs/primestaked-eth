const { subtask, task, types } = require("hardhat/config");
const { KeyValueStoreClient } = require("defender-kvstore-client");

const { depositPrime, depositAssetEL, depositAllEL } = require("./deposits");
const { operateValidators, registerVal, stakeEth } = require("./p2p");
const { approveSSV, depositSSV, pauseDelegator, unpauseDelegator } = require("./ssv");
const { setActionVars } = require("./defender");
const { tokenAllowance, tokenBalance, tokenApprove, tokenTransfer, tokenTransferFrom } = require("./tokens");
const { getSigner } = require("../utils/signers");
const { parseAddress } = require("../utils/addressParser");
const { abi: erc20Abi } = require("../../out/ERC20.sol/ERC20.json");
const { depositWETH, withdrawWETH } = require("./weth");
const { resolveAsset } = require("../utils/assets");

const log = require("../utils/logger")("task");

// Prime Staked
subtask("depositPrime", "Deposit an asset to Prime Staked ETH")
  .addParam("symbol", "Symbol of the token. eg OETH, stETH, mETH or WETH", "OETH", types.string)
  .addParam("amount", "Deposit amount", undefined, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();
    const depositPoolAddress = await parseAddress("LRT_DEPOSIT_POOL");
    const depositPool = await ethers.getContractAt("LRTDepositPool", depositPoolAddress);

    await depositPrime({ signer, depositPool, ...taskArgs });
  });
task("depositPrime").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("depositEL", "Deposit an asset to EigenLayer")
  .addParam("symbol", "Symbol of the token. eg OETH, stETH, mETH or ETHx", "ALL", types.string)
  .addParam("index", "Index of Node Delegator", 1, types.int)
  .addOptionalParam("minDeposit", "Minimum ETH deposit amount", 1, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();
    const depositPoolAddress = await parseAddress("LRT_DEPOSIT_POOL");
    const depositPool = await ethers.getContractAt("LRTDepositPool", depositPoolAddress);
    const nodeDelegatorAddress = await parseAddress("NODE_DELEGATOR");
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);
    if (taskArgs.symbol === "ALL") {
      await depositAllEL({ signer, depositPool, nodeDelegator, ...taskArgs });
    } else {
      await depositAssetEL({ signer, depositPool, nodeDelegator, ...taskArgs });
    }
  });
task("depositEL").setAction(async (_, __, runSuper) => {
  return runSuper();
});

// SSV
subtask("approveSSV", "Approve the SSV Network to transfer SSV tokens from NodeDelegator")
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    await approveSSV({ signer, nodeDelegator, ...taskArgs });
  });
task("approveSSV").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("depositSSV", "Approve the SSV Network to transfer SSV tokens from NodeDelegator")
  .addParam("amount", "Amount of SSV tokens to deposit", undefined, types.float)
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    await depositSSV({ signer, nodeDelegator, ...taskArgs });
  });
task("depositSSV").setAction(async (_, __, runSuper) => {
  return runSuper();
});

// Prime Management
subtask("pauseDelegator", "Manager pause a NodeDelegator")
  .addOptionalParam("index", "Index of Node Delegator", 0, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    await pauseDelegator({ signer, nodeDelegator, ...taskArgs });
  });
task("pauseDelegator").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("unpauseDelegator", "Admin unpause a NodeDelegator")
  .addOptionalParam("index", "Index of Node Delegator", 0, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    await unpauseDelegator({ signer, nodeDelegator, ...taskArgs });
  });
task("unpauseDelegator").setAction(async (_, __, runSuper) => {
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
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .setAction(async (taskArgs) => {
    const storeFilePath = require("path").join(__dirname, "..", "..", ".localKeyValueStorage");

    const store = new KeyValueStoreClient({ path: storeFilePath });
    const signer = await getSigner();

    const WETH = await resolveAsset("WETH", signer);

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    const contracts = {
      nodeDelegator,
      WETH,
    };

    const network = await ethers.provider.getNetwork();
    const p2p_api_key = network.chainId === 1 ? process.env.P2P_MAINNET_API_KEY : process.env.P2P_GOERLI_API_KEY;
    if (!p2p_api_key) {
      throw new Error("P2P API key environment variable is not set. P2P_MAINNET_API_KEY or P2P_GOERLI_API_KEY");
    }
    const p2p_base_url = network.chainId === 1 ? "api.p2p.org" : "api-test.p2p.org";

    const config = {
      p2p_api_key,
      p2p_base_url,
      // how much SSV (expressed in days of runway) gets deposited into SSV
      // network contract on validator registration.
      validatorSpawnOperationalPeriodInDays: 90,
    };

    await operateValidators({
      signer,
      contracts,
      store,
      config,
    });
  });
task("operateValidators").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("registerVal", "Register a validator for testing purposes")
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    await registerVal({ signer, nodeDelegator });
  });
task("registerVal").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("stakeEth", "Stake ETH into validator")
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    await stakeEth({ signer, nodeDelegator });
  });
task("stakeEth").setAction(async (_, __, runSuper) => {
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

// WETH tasks
subtask("depositWETH", "Deposit ETH into WETH")
  .addParam("amount", "Amount of ETH to deposit", undefined, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const wethAddress = await parseAddress("WETH_TOKEN");
    const weth = await ethers.getContractAt("IWETH", wethAddress);

    await depositWETH({ weth, signer, ...taskArgs });
  });
task("depositWETH").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("withdrawWETH", "Withdraw ETH from WETH")
  .addParam("amount", "Amount of ETH to withdraw", undefined, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const wethAddress = await parseAddress("WETH_TOKEN");
    const weth = await ethers.getContractAt("IWETH", wethAddress);

    await withdrawWETH({ weth, signer, ...taskArgs });
  });
task("withdrawWETH").setAction(async (_, __, runSuper) => {
  return runSuper();
});
