const { subtask, task, types } = require("hardhat/config");
const { KeyValueStoreClient } = require("defender-kvstore-client");

const { depositPrime, depositAssetEL, depositAllEL } = require("./deposits");
const { operateValidators, registerVal, stakeEth } = require("./p2p");
const { snapshot } = require("./snapshot");
const {
  approveSSV,
  depositSSV,
  pauseDelegator,
  unpauseDelegator,
  printClusterInfo,
  splitValidatorKey,
} = require("./ssv");
const { setActionVars } = require("./defender");
const { tokenAllowance, tokenBalance, tokenApprove, tokenTransfer, tokenTransferFrom } = require("./tokens");
const { getSigner } = require("../utils/signers");
const { parseAddress } = require("../utils/addressParser");
const { depositWETH, withdrawWETH } = require("./weth");
const { resolveAsset } = require("../utils/assets");
const { deployNodeDelegator } = require("./deploy");

const log = require("../utils/logger")("task");

// Prime Staked
subtask("depositPrime", "Deposit an asset to Prime Staked ETH")
  .addParam("symbol", "Symbol of the token. eg OETH, stETH, mETH or WETH", "OETH", types.string)
  .addParam("amount", "Deposit amount", undefined, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();
    const depositPoolAddress = await parseAddress("LRT_DEPOSIT_POOL");
    const depositPool = await ethers.getContractAt("LRTDepositPool", depositPoolAddress);
    const network = await ethers.provider.getNetwork();

    await depositPrime({ signer, depositPool, networkId: network.chainId, ...taskArgs });
  });
task("depositPrime").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("depositEL", "Deposit an asset to EigenLayer")
  .addParam("symbol", "Symbol of the token. eg OETH, stETH, mETH or ETHx", "WETH", types.string)
  .addParam("index", "Index of Node Delegator", 1, types.int)
  .addOptionalParam("minDeposit", "Minimum ETH deposit amount", 32, types.float)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();
    const depositPoolAddress = await parseAddress("LRT_DEPOSIT_POOL");
    const depositPool = await ethers.getContractAt("LRTDepositPool", depositPoolAddress);

    const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
    const nodeDelegatorAddress = await parseAddress(addressName);
    const nodeDelegator = await ethers.getContractAt("NodeDelegator", nodeDelegatorAddress);

    if (taskArgs.symbol === "ALL") {
      const assets = [
        await resolveAsset("OETH", signer),
        await resolveAsset("SFRXETH", signer),
        await resolveAsset("METH", signer),
        await resolveAsset("STETH", signer),
        await resolveAsset("RETH", signer),
        await resolveAsset("SWETH", signer),
        await resolveAsset("ETHX", signer),
      ];
      await depositAllEL({ signer, depositPool, nodeDelegator, assets, ...taskArgs });
    } else {
      const asset = await resolveAsset(taskArgs.symbol, signer);
      await depositAssetEL({ signer, depositPool, nodeDelegator, asset, ...taskArgs });
    }
  });
task("depositEL").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("snap", "Display the assets in the different layers of PrimeETH").setAction(snapshot);
task("snap").setAction(async (_, __, runSuper) => {
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

subtask("splitValidatorKey", "Splits the full validator key in DVT share key")
  .addParam(
    "operatorids",
    /* The nonce of the owner within the SSV contract (increments after each validator registration)
     * the nonce is required to generate the sharesData.
     *
     * id 60: https://goerli.explorer.ssv.network/operators/60
     * key: LS0tLS1CRUdJTiBSU0EgUFVCTElDIEtFWS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMHZPbHNpTzVCV0dDTEM1TUxDQW8KYkN0ZDI5NmNvaFN0MGhhMmtpRjMwNi9NR2Y5OVRORCs0TmpRWXNEQVlFYVJjZFhNUjY1bjdHTk4yUkkxdTg0aQpTZm04NElKTTdIRGsxeUpVTGdGcnRmQ00yWG03ZzFYODZ3ZkZGT2JrWUJSQmNIZnZSZUxHcDdzdjFpSFh1M2s3CkszVzJvUnZhV2U4V3k3MGdXS25jeWROakZpWDJIQ2psQnIyRjhJT0Z0SHI3cGpyWnZqa0ROcDFkMnprK2V6YncKdCticUMySnFSaVF4MGI5d0d4d3h0UERERjY0amVtWDRpMkJPWXNvUkx6dkN6dWtaeHB3UlNJOW1wTHE1UktOaApIY1pEcWg3RUV5VFloUG1BTTcvT2luMWROZCtNUi9VRU5mTkJqMGZMVURhZWJWSUVVMEhzRzMzdHV3MmR5RksxCnRRSURBUUFCCi0tLS0tRU5EIFJTQSBQVUJMSUMgS0VZLS0tLS0K
     * id 79: https://goerli.explorer.ssv.network/operators/79
     * key: LS0tLS1CRUdJTiBSU0EgUFVCTElDIEtFWS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBbzRtb2hUcVdKRGhyYkp5MlhXeXUKQjZIOFU3OXpxS2VhdGdweGRIcS9iWkxrTHpNcE10SVNNOEd3ckUxVlhmMUZ1RWhqcXhTQko0V1hnb0RxWGZTNQp4Q0RIeUdwSld1STF5Q3V5Z3NLRE96QkU4OWZaZEZlY1BsQTZpbzYxR0ROWkJPOWNEOGY2VnFiblN1TDRIMEZjCnkwdk5SdmdROWhEUFJZcHhMVER6N1gyU1RYZWk5eGcyVVdBYm01QUZVbm9WR01yZ2R4YkY5ZjlaNDZDZVk0TFgKL3pqQW1DNFl5YVlYZk9TL2lzQkZkYTN3RlFZZmVhcVVWb2huOCt6ZFg3Y2p4SVZrdDVtQ2FqVFo2bXJzWEFBNApzTDQxaEM4Z0NKYmdESDhIcEZaVXViYUFFUEswV1dZOENCUEhMY1dtWWxLeEJhVEdaU25SM2ZBN3hRcU5lK3VvCkl3SURBUUFCCi0tLS0tRU5EIFJTQSBQVUJMSUMgS0VZLS0tLS0K
     * id 220: https://goerli.explorer.ssv.network/operators/220
     * key: LS0tLS1CRUdJTiBSU0EgUFVCTElDIEtFWS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBeUtiUGc2SXRnTGJSTHpHK0VhMUcKSGdSQm45a3J2N2pXN09ocGxqQWg3MUtCVnFNVldtZi9LRVlBUis1Qnp2bGdwV3ptc3pxZ3MyeDN6UzB5MHd0Zgp6WkVLZ2NrMDJIcXVTMzIwTUJ2QTBLN3B0OFc4Qm9ZM3ozS3d4bUpwUnNwZ3p5dm80TGIyU3RsL1FBNFE4cjZsCjVOWjdrRVNHVktFTFA3R3JrQTlYajBOS0wxZU5uYTRocnpEcnpJS1FwMGZkcjBpWWFxRnhNWUZBZ0FUcVp2b1kKbGxDWG16TmdaUDdtaERRWTdWSk9kenJkSTBrOEdISTZpWUFlWUExRVR1Y01mckpzMmd0a0FPRlR6TjhYYW5VWgpkQis1c0g2V0UwSGhvVGFCeGYwcHpnTFpvenROdTdpUzFmRlZOTUNnR3BCc3MxMDcxMEZFNE1aYW1uWFMxeWt5ClN3SURBUUFCCi0tLS0tRU5EIFJTQSBQVUJMSUMgS0VZLS0tLS0K
     * id 349: https://goerli.explorer.ssv.network/operators/349
     * key: LS0tLS1CRUdJTiBSU0EgUFVCTElDIEtFWS0tLS0tCk1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBd1l0MEdGdmRORTA3L1NuNGdSSnUKNkhlWHU0S3RkL1k1ZGkweGFFNUNyYXZyenU3ZXNIZzg0SXRmcURVbTQrVTNJQm9LelFkdUNKdkw5L1FwTG5LaApTanRzcEpid0gxd2liYXppcVFuM08zbVljb0tYWjAvWDVJamoyUG9hVG13cUkrTFlLbUNXNWFQR3psWklpYUF2ClNGQ2V6M3BFTllQOFNlMFRObm1UaWNuMGRkVkIwMU9uRzJxZEZIMXhBRGNxckFwTE52NmVhMzF6eUdRTG9FbHoKTzFMK2VjZzB3SHRON0hqYnZGUDczcDF5TTA4UU1LRzV6ellKUTVJWmEwL3lWK213blJpSjZTcTZEUkgxd1JwYQpHeXpYQWNqYTBJSER0ckJPdCtOQ2grZS8vVU1Gd3B3OS8zMG5rN2JBRVBOcDY3Qks3Q0tnU0FHLzhxcmt4bHRVCi93SURBUUFCCi0tLS0tRU5EIFJTQSBQVUJMSUMgS0VZLS0tLS0K
     */
    "4 operator ids separated with a dot: same as IP format. E.g. 60.79.220.349",
    "",
    types.string,
  )
  .addParam(
    "operatorkeys",
    "4 operator keys separated with a dot: same as IP format. E.g. (without the square brackets)  [LS0tLS1CR...].[LS0tLS1CR...].[LS0tLS1CR...].[LS0tLS1CR]",
    "",
    types.string,
  )
  .addParam("keystorelocation", "location of the full validator key", "", types.string)
  .addParam("keystorepass", "password for the keystore", "", types.string)
  .addOptionalParam("owner", "Address of the cluster owner. Default to NodeDelegator", undefined, types.string)
  .setAction(async (taskArgs) => {
    let ownerAddress;
    if (taskArgs.owner) {
      ownerAddress = taskArgs.owner;
    } else {
      const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
      ownerAddress = await parseAddress(addressName);
    }

    const network = await ethers.provider.getNetwork();
    const ssvNetwork = await parseAddress("SSV_NETWORK");

    await splitValidatorKey({
      ownerAddress,
      chainId: network.chainId,
      ssvNetwork,
      ...taskArgs,
    });
  });
task("splitValidatorKey").setAction(async (_, __, runSuper) => {
  return runSuper();
});

subtask("getClusterInfo", "Print out information regarding SSV cluster")
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .addParam(
    "operatorids",
    "4 operator ids separated with a dot: same as IP format. E.g. 60.79.220.349",
    "",
    types.string,
  )
  .addOptionalParam("owner", "Address of the cluster owner. Default to NodeDelegator", undefined, types.string)
  .setAction(async (taskArgs) => {
    let ownerAddress;
    if (taskArgs.owner) {
      ownerAddress = taskArgs.owner;
    } else {
      const addressName = taskArgs.index === 1 ? "NODE_DELEGATOR_NATIVE_STAKING" : "NODE_DELEGATOR";
      ownerAddress = await parseAddress(addressName);
    }

    const network = await ethers.provider.getNetwork();
    const ssvNetwork = await parseAddress("SSV_NETWORK");

    log(
      `Fetching cluster info for cluster owner ${ownerAddress} with operator ids: ${taskArgs.operatorids} from the ${network.name} network.`,
    );
    await printClusterInfo({ ownerAddress, chainId: network.chainId, ssvNetwork, ...taskArgs });
  });
task("getClusterInfo").setAction(async (_, __, runSuper) => {
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
subtask("operateValidators", "Creates a new SSV validator and stakes 32 ether")
  .addOptionalParam("index", "Index of Node Delegator", 1, types.int)
  .addOptionalParam("stake", "Stake 32 ether after registering a new SSV validator", true, types.boolean)
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

    const eigenPodAddress = await parseAddress("EIGEN_POD");

    const network = await ethers.provider.getNetwork();
    const p2p_api_key = network.chainId === 1 ? process.env.P2P_MAINNET_API_KEY : process.env.P2P_GOERLI_API_KEY;
    if (!p2p_api_key) {
      throw new Error("P2P API key environment variable is not set. P2P_MAINNET_API_KEY or P2P_GOERLI_API_KEY");
    }
    const p2p_base_url = network.chainId === 1 ? "api.p2p.org" : "api-test.p2p.org";

    const config = {
      eigenPodAddress,
      p2p_api_key,
      p2p_base_url,
      // how much SSV (expressed in days of runway) gets deposited into SSV
      // network contract on validator registration.
      validatorSpawnOperationalPeriodInDays: 90,
      stake: taskArgs.stake,
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

subtask("stakeEth", "Stake ETH into validator for testing purposes")
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

subtask("decode", "Util to decode tx data")
  .addParam("data", "data field of tx", undefined, types.string)
  .addOptionalParam("name", "Identifier of the address in the Solidity addresses file", "SSV_NETWORK", types.string)
  .addOptionalParam("contract", "Name of the contract or interface", "ISSVNetwork", types.string)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();
    const nodeDelegatorAddress = await parseAddress(taskArgs.name);
    const contract = await ethers.getContractAt(taskArgs.contract, nodeDelegatorAddress);

    const txData = contract.interface.parseTransaction({ data: taskArgs.data });
    console.log(txData);
  });
task("decode").setAction(async (_, __, runSuper) => {
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

subtask("deployNodeDelegator", "Deploy and initialize a new Node Delegator contract via the Defender Relayer")
  .addParam("index", "Index of Node Delegator", undefined, types.int)
  .setAction(async (taskArgs) => {
    const signer = await getSigner();

    const wethAddress = await parseAddress("WETH_TOKEN");
    const weth = await ethers.getContractAt("IWETH", wethAddress);

    await deployNodeDelegator({ weth, signer, ...taskArgs });
  });
task("deployNodeDelegator").setAction(async (_, __, runSuper) => {
  return runSuper();
});
