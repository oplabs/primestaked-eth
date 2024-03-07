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
        await depositEth(
          signer,
          store,
          currentState.uuid,
          contracts.nodeDelegator,
          currentState.metadata.depositData[0],
        );
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
      await updateState(uuid, "validator_creation_confirmed", store, {
        validatorRegistrationRawTx: response.result.validatorRegistrationTxs[0],
        depositData: response.result.depositData,
      });
      log(`Validator created using uuid: ${uuid} is ready`);
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
    "0x896b5102d5f600aa30687c5cd0088d2e43c3afa7f643600edb12e31cd4b0b2b23e556b33de0168ab94abd4730a18225f";
  const operatorIds = [60, 79, 220, 349];
  const sharesData =
    "0xaebf72c2bd0899798a4fe51235f669debe4bc59dd49df29394ae2adf1e585e45bdee7c0f462ec9c6d531ff36c98e2e9712149e5ecd20365848073e93ad8550fe178c8ebbee9b924351533d869e63a08707ee12309b499ff3452597aca0336e4c80f04654a67fccc2e3e349608819195829a44b21a836a75836f639babd14b6aa46a49e26f02632ed13678f730d4f2ed08612225c95aca932fd0813cd605b9a61c1e0504917c94eab588ba2d619e89f339e9b804f6fffc9ad4ead1fcaa4706dca97a56d2efeefab016832d143b160aed03307ad12f83d91fe50cd1a3e3b80f4cdd91a660657c0fea9259014331dfce1759330bc9a1aae91f3c64511f937a648595757b692895b6eeb7a886551c8b1990ee9a820a412e2d1ba79e2e6b200d990153ea459cc20c1ed030c9aa5635130b583f356e81fc48db7e76e99f7eeb646449e05524d3e6377f68c8a4e4c235cce3baf566ca94f46278d144ca6f0d8c0fb692dcb1e40cc5d1727c94948381df3f52b1b7a517322063000a964714cbfa4b0093533b00c041e0693e56bcce55d03908dd3419797477cbc7240964d8a7566c02739564f7f48fec29d19e7c00a63bdd49432230cb7bc1ef6075c43d9d081157c14554bcc7551999eba0fd0531af488601c21603fd285a89ef1478fb52ed6b8d3ab811602df305543a44cd698abb6ca6e067bf1573007f4e67ca8c3ecc35b56679d3ea8798efbe3d7074f7da1305596eb17c8c1adbfc408f1edab9985cacd9475ffee1cd64cec8a9f1b10fdc0ed2334fddf0b1f89c5781c9d8f38f6778f002d63bd325b7414d7a604dd3df8e1ddaf896d1de9ea9f803eef0557f186fef7cba29d2d6d85f4cd0ec62fb768f66b626a48198916b75e8f85e14c43e8ed8ef5870895cd68bbcafdcd3a4cce352088daf59180cd44352f490415d97636fb8a646cca38bf001d2d813d9a819f9d717bd44b52c0a2405f25a6dc56d508cc2a74db28189f428cf776f64421c55a30092cd4786d1ba30984e2571911f0b54c1f92f68a706c8a28607ff648b010b25df19a8ed69e5be864a8e0447a5771eaa17cb8abc250e83b728707f8a5ea113862c2d1c3cde561d9ff6250e163db18f02cc741aaabebba1de8053e30c248b81ae6148ed3866d29f4df06e86ef8cde1beb89631b1e67620895c29d48bb89cd81e05773c32d3d6ede945ae0f3e3d3eac5bcb08806aec9935caa118edb9aa7f3f7ef9cef3ce4e064b18492bd82224c10d56b1ffb1072751cffe8deb61a6dd06c0046ffc7392a6d76499b593182543251399dc59327934cd8013b02434cd586f75ccbacea3c36fc0d71318a1db057a7a47bda9eb9c38f6cfbe2ca172b5619dfb9118edc6bea2906802b18668e9bec8a3acf196df592fe4c000f516fd330645af1d06740d03aa309863d6d68fb8202c31bd8d8f7ddb80e541f573e9ba6a0e4965e15b9e9ea83e7bcc9cf9fd06ae99fe4aaae5820498393dd29f5b7ba57e6e39f7bd077279912653fbbf8f54d9d8401c79e2582f0f0fc0cd176ad5003a1d8fd20583f50efd51c11a902c83215ac5518f974d699c01febaee637bf9129a15fc4abaf983165f70c8ad584a41e0c04b2c15afafd04b69b3c188fae146567791e92a339bbfa6397202345ce0b8a34ca012dfbc0711699208bfa3c9e9377ed676e3a63088dfa61c8dced0dc26c485d1507a659e14ce3eb7ca620aa31289c2658f3b479f72598cb3310afbdd1b55022553fab4e45f4a7bee9ca232b862e092d77cac486fed8d4006aa68d7abd71381e0208aa6b5c1dfb335c3ad91cf05324e498a6fb519967e907da608faed80c71448e056b234bb95c851fe4dc15e25dae3";
  const amount = "2002546440000000000";
  const cluster = { validatorCount: 0, networkFeeIndex: 0, index: 0, active: true, balance: 0 };

  const tx = await nodeDelegator
    .connect(signer)
    .registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

  await logTxDetails(tx, "registerSsvValidator");
};

const stakeEth = async ({ signer, nodeDelegator }) => {
  // hardcode values for testing
  const pubkey = "0x896b5102d5f600aa30687c5cd0088d2e43c3afa7f643600edb12e31cd4b0b2b23e556b33de0168ab94abd4730a18225f";
  const signature =
    "0xb2f24a0115546169976cdd8784d6c896febefd58964158f81ab9427e577d5eb055b40f384f4a09b5ff8d2b834277fa861632758a3fcb564dae759922f466a8eaa2af9d2406906646adda22baa86967a4a90b616527c0c077794657da9076b198";
  const depositDataRoot = "0xc9d1dd6024731da7ab57d15c20a3b6f2b14e15337684f73f3e96ff5c962f369a";

  const tx = await nodeDelegator.connect(signer).stakeEth([[pubkey, signature, depositDataRoot]]);

  await logTxDetails(tx, "stakeEth");
};

module.exports = {
  operateValidators,
  registerVal,
  stakeEth,
};
