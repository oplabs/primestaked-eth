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
  const { clear, eigenPodAddress, p2p_api_key, validatorSpawnOperationalPeriodInDays, p2p_base_url, stake } = config;

  let currentState = await getState(store);
  log("currentState", currentState);

  if (clear && currentState?.uuid) {
    await clearState(currentState.uuid, store);
    currentState = undefined;
  }

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
          currentState.metadata,
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

const broadcastRegisterValidator = async (signer, store, uuid, metadata, nodeDelegator) => {
  const registerTransactionParams = utils.defaultAbiCoder.decode(
    ["bytes", "uint64[]", "bytes", "uint256", "tuple(uint32, uint64, uint64, bool, uint256)"],
    utils.hexDataSlice(metadata.registerValidatorData, 4),
  );
  // the publicKey and sharesData params are not encoded correctly by P2P so we will ignore them
  const [_publicKey, operatorIds, _sharesData, amount, cluster] = registerTransactionParams;
  // get publicKey and sharesData state storage
  const publicKey = metadata.depositData.pubkey;
  if (!publicKey) {
    throw Error(`pubkey not found in metadata.depositData: ${metadata?.depositData}`);
  }
  const { sharesData } = metadata;
  if (!sharesData) {
    throw Error(`sharesData not found in metadata: ${metadata}`);
  }

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
      const registerValidatorData = response.result.validatorRegistrationTxs[0].data;
      const depositData = response.result.depositData[0];
      const sharesData = response.result.encryptedShares[0].sharesData;
      await updateState(uuid, "validator_creation_confirmed", store, {
        registerValidatorData,
        depositData,
        sharesData,
      });
      log(`Validator created using uuid: ${uuid} is ready`);
      log(`Primary key: ${depositData.pubkey}`);
      log(`signature: ${depositData.signature}`);
      log(`depositDataRoot: ${depositData.depositDataRoot}`);
      log(`sharesData: ${sharesData}`);
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
    "0xb61d41588d1c4552e1866ca7f8475007e23cebb74c533b4b9d0f89a3836c135604267446744e6d4faaf6db0dde641173";
  const operatorIds = [192, 195, 200, 201];
  const sharesData =
    "0x86a062e4c406806d931845c91156979fc8004d4989225c375ea2ea12bcefb25975e3db8f0b7c347d6dddd0b051e0013c1109cff961baf78a216f02e30165896d76cd38e03f547087c842b1788362fddbc977d553dc4a523b0f2341e12a811daab0797bcc58d0987f17601d06bffd2684e188e2f2d3c72d4cdab2cc33bb89108ac09140219f8615424e621b8b10a01b6d876954b3f14e6a5b0f5d48f605b51cbce8e44bb21b203eb8ea7d435a578b2a8cb2590021f513fafd4b6b90227c7383709663e0c18cdc5075d4c59a1ea94dda4e97a8393e31d13425122f25970c8dff77c35d359ee9b36dcf61597d0e6319993f84a8cfbc4db6dea726b6fdba37962a7b5c4bd71446faca59419ab055c74d984909c68c364d4a754842af9bd00f17fa4721282861b173001fa327cf9bbd0e993fd41de7fbe766fc7d651e26ac4f8742ce2f109c3ad3edd8800ec93a94c28e7f4299d3dd56b26f67dc1ec1ec1444d2f01450b46731c41345b39491e5427cbdf0285ed16804a456cc32de62ab89e86c44cb4a2aacd1ce43f90643180a0f70b03528288b56933f7c4ed6bc3bac30b969c8c81d9e7bc0e016c6c5770f16d3ba57713cea5bcd2bb446a8b7f4e714e809eca93e1a6e73aec1505d93ed8c292a29ca927e126a551b06e5329d7cbf914ca1b99c38c9ed18c487a77b0ee849608556aa918f9b95a8ea3dc56a757abbde244d9ec705b153cc2b071dc832ffba3643cb5a9141032c2bc098b0e6e876c0d2bf7e23fc498d3016deec21f983016b1f31c329fa48c590af51cc7a2fb4587c442c40ec2426ed68df24def08f527704f038292f83d1cac50510f4de6563aaf0b1e29ef4a6cb2372868e482d3996ddd62689a23b77aabc342e30394b73b0aa04b529d1bcc1f46fa3dc86db9c160ce71c07c7851ecda788d3b7f73cfdcaa25741117d0c4e1e6c4f32b9feee9089defa6e399e752e43523662fe646788f96d2cb78e8980a0c66c1318e37f45d8561fa37e47b2651253fdc02b315a3941c3ea2d4391067945e94c103fcd7d494d205bb1c0ef61589f5204620088cd020cfa0bb3eb4507a806370be71396da0c36be9c0450ab049e2be2fb2faad9ae40c15a43eced4fe9800502676a38a98416be089b3260533354eb225a44e2d3b2d47d2043d1252a39a758e4a7aeb7b866a5d668f98fac5797c53c52181322e296bfc80db678e995ed800ed13951b71c0b874137b313bb0550f26b8ae31b0c54b65312ae404b4012f790e6a9eddff9ab4cc51817d79b6963d429396ab57747df95909bb820e3df0d3481c963275d4026d46814e27dcd2125cc13a44ba82f9936be129bc9db18430595a721c2ee1485bd2ec7075b6953cc448ca91625d381968b0e27452bbe1d84be8ad9d9d86a72fba7b5a6a528b40e6aba956319dc4a9c33f8a41277a5f39b49c567bc34cf40aabc124d2d637a1e8f5f39c89de22c4d4d74dcf2eb734727243047324ff6cdd453ff6047c08062da4519ba26e938ee7cd43273bda57243ceacebdc7982d05666d34e3111ebd0da3e58e20037650b792f113513e892a51be796923d3bd2529ed460f7f7b7a30d8d7f6ac4bf8b75c58cf1ae7ccd9281790c5feeb2fd9490e4e776b3d555bb47f9adce00e922839c63474fb2cd48940945177194a5b8a5d21932e7d5251bb94109975f33e0034e735203b010a1c5d57cc085f25d507e3d78d4862882c9a521595a6d62a77ea3c9c9d548c0912ad2dd7e75f2fd8776303be72e1cbb9d37069b18e97256dca15d0db29a810d8781e2f8a9f248342f1c42a5795eecedf0253092e57876ae5723b392a49b60d1f2b79d8190463c052c738d10d05be22d";
  const amount = "2000000000000000000";
  const cluster = {
    validatorCount: 3,
    networkFeeIndex: 63383020962,
    index: 61133914500,
    active: true,
    balance: "5997482766900000000",
  };

  const tx = await nodeDelegator
    .connect(signer)
    .registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

  await logTxDetails(tx, "registerSsvValidator");
};

const stakeEth = async ({ signer, nodeDelegator }) => {
  // hardcode values for testing
  const pubkey = "0xb61d41588d1c4552e1866ca7f8475007e23cebb74c533b4b9d0f89a3836c135604267446744e6d4faaf6db0dde641173";
  const signature =
    "0xb36304981e7b416ee44ce3e279949690df68f00677265842ef8ea70e67d5ea625b42db4358fa1e1124e2da516cebae2207ac99c2d2bbce9edf7c25bab5c5918c1df62fb61d928a17bf84b79cdfa79f8377ac1b79086701fe090bc4b4110bb7fe";
  const depositDataRoot = "0x571c988682ab057d4d81fc914a3ae52179f731b821608e68305916b40ded2e3d";

  const tx = await nodeDelegator.connect(signer).stakeEth([[pubkey, signature, depositDataRoot]]);

  await logTxDetails(tx, "stakeEth");
};

module.exports = {
  operateValidators,
  registerVal,
  stakeEth,
};
