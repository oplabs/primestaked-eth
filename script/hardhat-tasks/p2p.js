const fetch = require("node-fetch");
const { BigNumber, utils } = require("ethers");
const { v4: uuidv4 } = require("uuid");

const { sleep } = require("../utils/time");
const { logTxDetails } = require("../utils/txLogger");

const log = require("../utils/logger")("task:p2p");

/* When same UUID experiences and error threshold amount of times it is
 * discarded.
 */
const ERROR_THRESHOLD = 5;
/*
 * Spawns and maintains the required amount of validators throughout
 * their setup cycle which consists of:
 *   - check balance of (W)ETH and crate P2P SSV cluster creation request
 *   - wait for the cluster to become operational
 *   - batch register the cluster on the SSV network
 *   - verify the complete cluster has been registered
 *   - batch stake the ETH to each of the validators
 *
 * Needs to also handle:
 *   - if anytime in the spawn cycle the number of (W)ETH falls below the
 *     required stake amount (withdrawal from Node Operator), mark the spawn
 *     process as failed
 *   - if spawn process gets stuck at any of the above steps and is not able to
 *     recover in X amount of times (e.g. 5 times). Mark the process as failed
 *     and start over.
 */
const operateValidators = async ({ store, signer, contracts, config }) => {
  const { eigenPodAddress, p2p_api_key, validatorSpawnOperationalPeriodInDays, p2p_base_url, stake } = config;

  let currentState = await getState(store);
  log("currentState", currentState);

  if (!(await nodeDelegatorHas32Eth(contracts))) {
    log(`Node delegator doesn't have enough ETH, exiting`);
    return;
  }

  const executeOperateLoop = async () => {
    while (true) {
      if (!currentState) {
        await createValidatorRequest(
          p2p_api_key, // api key
          p2p_base_url,
          contracts.nodeDelegator.address, // node delegator address
          eigenPodAddress, // eigenPod address
          validatorSpawnOperationalPeriodInDays,
          store,
        );
        currentState = await getState(store);
      }

      if (currentState.state === "validator_creation_issued") {
        await confirmValidatorCreatedRequest(p2p_api_key, p2p_base_url, currentState.uuid, store);
        currentState = await getState(store);
      }

      if (currentState.state === "validator_creation_confirmed") {
        await broadcastRegisterValidator(
          signer,
          store,
          currentState.uuid,
          currentState.metadata.validatorRegistrationRawTx.data,
          contracts.nodeDelegator,
        );
        currentState = await getState(store);
      }

      if (currentState.state === "register_transaction_broadcast") {
        await waitForTransactionAndUpdateStateOnSuccess(
          store,
          currentState.uuid,
          contracts.nodeDelegator.provider,
          currentState.metadata.validatorRegistrationTx,
          "registerSsvValidator", // name of transaction we are waiting for
          "validator_registered", // new state when transaction confirmed
        );
        currentState = await getState(store);
      }

      if (!stake) break;

      if (currentState.state === "validator_registered") {
        await depositEth(signer, store, currentState.uuid, contracts.nodeDelegator, currentState.metadata.depositData);
        currentState = await getState(store);
      }

      if (currentState.state === "deposit_transaction_broadcast") {
        await waitForTransactionAndUpdateStateOnSuccess(
          store,
          currentState.uuid,
          contracts.nodeDelegator.provider,
          currentState.metadata.depositTx,
          "stakeEth", // name of transaction we are waiting for
          "deposit_confirmed", // new state when transaction confirmed
        );

        currentState = await getState(store);
      }

      if (currentState.state === "deposit_confirmed") {
        await clearState(currentState.uuid, store);
        break;
      }
      await sleep(1000);
    }
  };

  try {
    if ((await getErrorCount(store)) >= ERROR_THRESHOLD) {
      await clearState(
        currentState.uuid,
        store,
        `Errors have reached the threshold(${ERROR_THRESHOLD}) discarding attempt`,
      );
      return;
    }
    await executeOperateLoop();
  } catch (e) {
    await increaseErrorCount(currentState ? currentState.uuid : "", store, e);
    throw e;
  }
};

const getErrorCount = async (store) => {
  const existingRequest = await getState(store);
  return existingRequest && existingRequest.hasOwnProperty("errorCount") ? existingRequest.errorCount : 0;
};

const increaseErrorCount = async (requestUUID, store, error) => {
  if (!requestUUID) {
    return;
  }

  const existingRequest = await getState(store);
  const existingErrorCount = existingRequest.hasOwnProperty("errorCount") ? existingRequest.errorCount : 0;
  const newErrorCount = existingErrorCount + 1;

  await store.put(
    "currentRequest",
    JSON.stringify({
      ...existingRequest,
      errorCount: newErrorCount,
    }),
  );
  log(`Operate validators loop uuid: ${requestUUID} encountered an error ${newErrorCount} times. Error: `, error);
};

/* Each P2P request has a life cycle that results in the following states stored
 * in the shared Defender key-value storage memory.
 *  - "validator_creation_issued" the create request that creates a validator issued
 *  - "validator_creation_confirmed" confirmation that the validator has been created
 *  - "register_transaction_broadcast" the transaction to register the validator on
 *    the SSV network has been broadcast to the Ethereum network
 *  - "validator_registered" the register transaction has been confirmed
 *  - "deposit_transaction_broadcast" the stake transaction staking 32 ETH has been
 *    broadcast to the Ethereum network
 *  - "deposit_confirmed" transaction to stake 32 ETH has been confirmed
 */
const updateState = async (requestUUID, state, store, metadata = {}) => {
  if (
    ![
      "validator_creation_issued",
      "validator_creation_confirmed",
      "register_transaction_broadcast",
      "validator_registered",
      "deposit_transaction_broadcast",
      "deposit_confirmed",
    ].includes(state)
  ) {
    throw new Error(`Unexpected state: ${state}`);
  }

  const existingRequest = await getState(store);
  const existingMetadata =
    existingRequest && existingRequest.hasOwnProperty("metadata") ? existingRequest.metadata : {};

  await store.put(
    "currentRequest",
    JSON.stringify({
      uuid: requestUUID,
      state: state,
      metadata: { ...existingMetadata, ...metadata },
    }),
  );
};

const clearState = async (uuid, store, error = false) => {
  if (error) {
    log(`Clearing state tracking of ${uuid} request because of an error: ${error}`);
  } else {
    log(`Clearing state tracking of ${uuid} request as it has completed its spawn cycle`);
  }
  await store.del("currentRequest");
};

/* Fetches the state of the current/ongoing cluster creation if there is any
 * returns either:
 *  - false if there is no cluster
 *  -
 */
const getState = async (store) => {
  const currentState = await store.get("currentRequest");
  if (!currentState) {
    return currentState;
  }

  return JSON.parse(await store.get("currentRequest"));
};

const nodeDelegatorHas32Eth = async (contracts) => {
  const address = contracts.nodeDelegator.address;
  const wethBalance = await contracts.WETH.balanceOf(address);
  const ethBalance = await contracts.nodeDelegator.provider.getBalance(address);
  const totalBalance = wethBalance.add(ethBalance);

  log(`Node delegator has ${utils.formatUnits(totalBalance, 18)} ETH in total`);
  return totalBalance.gte(utils.parseEther("32"));
};

/* Make a GET or POST request to P2P service
 * @param api_key: p2p service api key
 * @param method: http method that can either be POST or GET
 * @param body: body object in case of a POST request
 */
const p2pRequest = async (url, api_key, method, body) => {
  const headers = {
    Accept: "application/json",
    Authorization: `Bearer ${api_key}`,
  };

  if (method === "POST") {
    headers["Content-Type"] = "application/json";
  }

  const bodyString = JSON.stringify(body);
  log(`Creating a P2P ${method} request with ${url} `, body != undefined ? ` and body: ${bodyString}` : "");

  const rawResponse = await fetch(url, {
    method,
    headers,
    body: bodyString,
  });

  const response = await rawResponse.json();
  if (response.error != null) {
    log("Request to P2P service failed with an error:", response);
    throw new Error(`Call to P2P has failed: ${JSON.stringify(response.error)}`);
  } else {
    log("Request to P2P service succeeded: ", response);
  }

  return response;
};

const createValidatorRequest = async (
  p2p_api_key,
  p2p_base_url,
  nodeDelegatorAddress,
  eigenPodAddress,
  validatorSpawnOperationalPeriodInDays,
  store,
) => {
  const uuid = uuidv4();
  await p2pRequest(`https://${p2p_base_url}/api/v1/eth/staking/ssv/request/create`, p2p_api_key, "POST", {
    validatorsCount: 1,
    id: uuid,
    withdrawalAddress: eigenPodAddress,
    feeRecipientAddress: nodeDelegatorAddress,
    ssvOwnerAddress: nodeDelegatorAddress,
    type: "without-encrypt-key",
    operationPeriodInDays: validatorSpawnOperationalPeriodInDays,
  });

  await updateState(uuid, "validator_creation_issued", store);
};

const waitForTransactionAndUpdateStateOnSuccess = async (store, uuid, provider, txHash, methodName, newState) => {
  log(`Waiting for transaction with hash "${txHash}" method "${methodName}" and uuid "${uuid}" to be mined...`);
  const tx = await provider.waitForTransaction(txHash);
  if (!tx) {
    throw Error(`Transaction with hash "${txHash}" not found for method "${methodName}" and uuid "${uuid}"`);
  }
  await updateState(uuid, newState, store);
};

const depositEth = async (signer, store, uuid, nodeDelegator, depositData) => {
  const { pubkey, signature, depositDataRoot } = depositData;
  try {
    log(`About to stake ETH with:`);
    log(`pubkey: ${pubkey}`);
    log(`signature: ${signature}`);
    log(`depositDataRoot: ${depositDataRoot}`);
    const tx = await nodeDelegator.connect(signer).stakeEth([
      {
        pubkey,
        signature,
        depositDataRoot,
      },
    ]);

    log(`Transaction to stake ETH has been broadcast with hash: ${tx.hash}`);

    await updateState(uuid, "deposit_transaction_broadcast", store, {
      depositTx: tx.hash,
    });
  } catch (e) {
    log(`Submitting transaction failed with: `, e);
    //await clearState(uuid, store, `Transaction to deposit to validator fails`)
    throw e;
  }
};

const broadcastRegisterValidator = async (signer, store, uuid, registerValidatorData, nodeDelegator) => {
  const registerTransactionParams = utils.defaultAbiCoder.decode(
    ["bytes", "uint64[]", "bytes", "uint256", '"tuple(uint32, uint64, uint64, bool, uint256)'],
    utils.hexDataSlice(registerValidatorData, 4),
  );

  const [publicKey, operatorIds, sharesData, amount, cluster] = registerTransactionParams;
  log(`About to register validator with:`);
  log(`publicKey: ${publicKey}`);
  log(`operatorIds: ${operatorIds}`);
  log(`sharesData: ${sharesData}`);
  log(`amount: ${amount}`);
  log(`cluster: ${cluster}`);

  try {
    const tx = await nodeDelegator
      .connect(signer)
      .registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

    log(`Transaction to register SSV Validator has been broadcast with hash: ${tx.hash}`);

    await updateState(uuid, "register_transaction_broadcast", store, {
      validatorRegistrationTx: tx.hash,
    });
  } catch (e) {
    log(`Submitting transaction failed with: `, e);
    //await clearState(uuid, store, `Transaction to register SSV Validator fails`)
    throw e;
  }
};

const confirmValidatorCreatedRequest = async (p2p_api_key, p2p_base_url, uuid, store) => {
  const doConfirmation = async () => {
    const response = await p2pRequest(
      `https://${p2p_base_url}/api/v1/eth/staking/ssv/request/status/${uuid}`,
      p2p_api_key,
      "GET",
    );
    if (response.error != null) {
      log(`Error processing request uuid: ${uuid} error: ${response}`);
    } else if (response.result.status === "ready") {
      const depositData = response.result.depositData[0];
      await updateState(uuid, "validator_creation_confirmed", store, {
        validatorRegistrationRawTx: response.result.validatorRegistrationTxs[0],
        depositData,
      });
      log(`Validator created using uuid: ${uuid} is ready`);
      log(`Primary key: ${depositData.pubkey}`);
      log(`signature: ${depositData.signature}`);
      log(`depositDataRoot: ${depositData.depositDataRoot}`);
      return true;
    } else {
      log(`Validator created using uuid: ${uuid} not yet ready. State: ${response.result.status}`);
      return false;
    }
  };

  let counter = 0;
  const attempts = 20;
  while (true) {
    if (await doConfirmation()) {
      break;
    }
    counter++;

    if (counter > attempts) {
      log(`Tried validating the validator formation with ${attempts} but failed`);
      await clearState(uuid, store, `Too may attempts(${attempts}) to waiting for validator to be ready.`);
      break;
    }
    await sleep(3000);
  }
};

const registerVal = async ({ nodeDelegator, signer }) => {
  // Hard coded values for testing
  const publicKey =
    "0x9969056e9899b1259375fe12ba724e1e38acf9cdb076b7970553847d05b40d16b6ca368bd2c54291753c04f26bb054f0";
  const operatorIds = [192, 195, 200, 201];
  const sharesData =
    "0x90eadc9e0276d478a9b1f1f906815ec6858ffed4d0eeba8cdee3665ddd67238ff8b8142733e00b7d4817e774f8d233000f35e75b38d7393fc50420fbbb3ac0a37f605e0b0fbe3106dbddd4c28f205e0f297c35423b545766cf396ca8cfcedd02b88d7ebf855c7ebb8cd94b15b2be113b032326d86c50ad288e73448d6b7b889934cd63fde2500f151fb46008dc0b7c0fb8ed68bb8d466e6860a6d776c0ac0c27e1ca75dd6ddd2862c2f2490e2823270183e8e029bd29233ae4c10034c2871d6d9484ef7c26a9e7a416d5fd44996ef6dc30ab808418db936f63484023845bedab4eb7d226e17550a1852221b9b91b11a3839dfa5511ef64d8194f0af748996466aa284d4ca74c708b56c311da532e6bb4e465a1b1cd8f92022a939c26f16ed5ce15b658d6235abdbf9cd46e6f9c7e4a51fdc1e9fb722affec3844d0dc38be41bdef39cc780e1d56cdc8c09c7baa457fd97cad730c647af7eaca9be239c5ef7893d7d1ea3487c8bd87049c8f192cbab0824f4f18e59d7aff709176398efb23590690bb9dba79ac8c4a3d59681acfcd8b4226e03b73754c2bfdfd5930fd47ff19384aae382e31a80b7fcca5aa643d44bb2c156851a9c3e472ba4530d90ed30a44a7d03349b53699b07876e3c119b9ab9600f3e0fa12f921843cdac5d8e9fdbf3bd4f6c2be546d4d4df0a9d747264b075bab6212bb227d707bad8b1c7e85a52738e1a265b6ee4c30232478c0920c68389ea3e6578c8661c2e8bc8a57f09987ecfd1fa7ecab2bddcc6576d29a907df368dd0611a66ba8093ed7faf2b7f9d9f864c149ef441822f4eb939842ee1048672d3902dd07271ca290923776f603cb6337246bcd31f9cefd3d0b56983fe67695a5a3203027977b17a90916d9ae5cf7278e4bcf79c2d57d608569cbea725201278736f84e933f5d222e9789bb760059521bdff3c2a39fc3fd0ae47a9b8050fe80aa181f9c4fe3a74485ee52a87ecb0d6b4dbaa6efb23c5db23768d8f4a099b8a2104fafb7433f0e859d35af3438b2c039811c3024b751dd2509a4a30ddf355da8a2a2f5ce6e509ff20edc6ade2a7348e38f48312192e0940e1b7ee8c05778f89214853de6ad173a9d80c7da9b5afb45c55daf594556575b779804a465ae3b616bfa959d21b84fcffbb0d30a912340cd3f01cf8ff2b9279eb9c4de79f4332a23496443b9145eddb56012e44c866d1733956e99d7b466232482d4d8368490b75192483ae6f6ece1fd2ea3698b6f92de4da37039e1c3240af90e970db94f501f7d4e87ef27d5e1651690fe83114a3bd846b0e7a85b71e96ab61a078834645e1cd94d5a7f5a8a5a33bc0cf5d450f3fb61d3c533fb426d8a4c3bc023d0c636170c40751b3103f7ea0ea20e8230224fa8ef5883eb70175ba88bfea0103c39a0dd18325c2983ce3a53fc525fb17c23df13984043eb93f2192f6abce3ebce0f3c5bb316984f5c739d70422405a565cfb9824ad8763743fe5345f65ed18b24171f3b57f955719c2862ae781b38462eceb614d4828ad86f733aa7e174097e78bc9df9206b5fa377d0085af44ad54e0446290eb4d34e416bf6c2266bd3fb3ed4a7b02426c156fd09e55d0b52bef5c1dccc1be6a1f47444151d4d2f27918b5560994679d57837d6a0b0e5ea5e2f54f4cc0d8494f0b3cbc8e2bc01f2ecb227b0ca77d636b21a064194f31c00b8d1f173d4c13a7f8119ab6bc4a56021dd57591f85aeb663e8fe6e2550470ac6d15b5223989956a20bfed6d327859237236965b15fe3a7f042189c4dc3160ac30354d98cb5e216cab56e289eb2cc4ea0416a3b4de018889734fa1452a35b5fb05d43f97357094a643268f9860c93";
  const amount = "2000000000000000000";
  const cluster = { validatorCount: 0, networkFeeIndex: 0, index: 0, active: true, balance: 0 };

  const tx = await nodeDelegator
    .connect(signer)
    .registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

  await logTxDetails(tx, "registerSsvValidator");
};

const stakeEth = async ({ signer, nodeDelegator }) => {
  // hardcode values for testing
  const pubkey = "0x9969056e9899b1259375fe12ba724e1e38acf9cdb076b7970553847d05b40d16b6ca368bd2c54291753c04f26bb054f0";
  const signature =
    "0xaa1b3cd9fc849d6f3a915b2d899abcf631348498092efa1024b404ed56d57714fc4c2a4595dbbee0dac7abd92fc6f299170e1dc58a10ba2b32f78fee3dec94e86d308681ec078a988dd84a1cf9936a1da25b3f1096e42646245b184c944d3640";
  const depositDataRoot = "0x23263573a59b7d2128604196fb45878df06cf69ca08a89420fa8bc800f1efe71";

  const tx = await nodeDelegator.connect(signer).stakeEth([[pubkey, signature, depositDataRoot]]);

  await logTxDetails(tx, "stakeEth");
};

module.exports = {
  operateValidators,
  registerVal,
  stakeEth,
};
